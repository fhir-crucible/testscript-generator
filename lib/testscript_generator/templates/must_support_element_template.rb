require_relative 'base_template'

class MustSupportElementTemplate < BaseTemplate

  @@template_path = "must_support_element_template.json"

  def instantiate 

    ig.structure_defs.keys.each do |resource_type|
      ig.structure_defs[resource_type].each do |structure_def|
        if (structure_def.kind == "resource" && !structure_def.abstract)
          FHIR.logger.info "  Generating Must Support Element Tests for Profile #{structure_def.name}"
          make_directory("#{output_path}/#{structure_def.name}")
          instantiate_profile(structure_def)
          FHIR.logger.info "  ... finished Generating Must Support Element Tests for Profile #{structure_def.name}"
        end
      end
    end
  end

def instantiate_profile(structure_def)
  structure_def.snapshot.element.each do |element|
    if (element.mustSupport && element.path.include?(".")) # must support and not the base Resource
      
      # basic
      instantiate_element(structure_def, element, "must_support_element")
      instantiate_element_choices(structure_def, element) if element.path.end_with?("[x]") && element.type.length() > 1
    end
  end
end

def instantiate_element(structure_def, element, the_case)
  FHIR.logger.info "    Generating test #{the_case} for element #{element.id}"
  
  replacement_list.clear
  replacement_list << ['[PROFILE_URL]', structure_def.url]
  replacement_list << ['[PROFILE_NAME]', structure_def.name]
  replacement_list << ['[BASE_RESOURCE]', structure_def.type]
  replacement_list << ['[ELEMENT_PATH]', element.path]

  # output details
  file_location = "#{output_path}/#{structure_def.name}"
  script_name = build_name(ig.name, structure_def.name, the_case, element.id.gsub(".", "_"))
  
  begin
    # load template
    script = load_template(@@template_path)

    # get the base path
    resolved_path = element.id.include?(":") ? resolve_slices_in_element_path(structure_def, element) : element.path
    # put at the start of the replacement_list so that any slices given names get replaced afterwards
    replacement_list.insert(0, ['[ELEMENT_EXISTENCE_FHIR_PATH]', get_existance_fhirPath(structure_def, element, resolved_path)])

    # add additional details, if needed
    # - nested elements: add logic to skip test if parent(s) are not populated
    if (element.path.count(".") > 1) # nested
      add_ancestor_checks(resolved_path, element, script)
    end
    # - reference type: fetch and validate the referenced resource, possibly against a profile
    if (element.type.length() == 1 && element.type[0].code == "Reference")
      add_reference_checks(resolved_path.gsub("[x]", 'Reference'), element, script)
    end
    
    # add metadata (name, id, etc.)
    assign_script_details(script, script_name)

    # export to JSON and replace string keys
    new_script = script_to_instantiated_json_string(script)
       
    # save to file
    output_script(file_location, new_script, script_name.gsub(" ", "_"))
  rescue Exception => e  
    FHIR.logger.info "      failed: #{e.message}"
    
    # generate stub
    generate_not_implmented(script_name, e.message, file_location)
  end
end

# create a test specifically targeting each type that is listed as must support
def instantiate_element_choices(structure_def, element)
  
  for type_index in 0..element.type.length()-1 do
    one_type = element.type[type_index]
    break if (one_type == nil)
    
    type_name = one_type.code
    must_support_type = one_type.extension.reduce(false) { |ms, ext| ms || (ext.url == "http://hl7.org/fhir/StructureDefinition/elementdefinition-type-must-support" ? ext.valueBoolean : false)}
    if (must_support_type)
      if (type_name == "Reference")
        FHIR.logger.info "    Generating test must_support_element_type_#{type_name} for element #{element.id}"
        FHIR.logger.info "      failed: Must Support Reference Choice Type"
      else
      
        element_mod = element.clone
        element_mod.type.clear
        element_mod.type << one_type
        
        instantiate_element(structure_def, element_mod, "must_support_element_type_#{type_name}")
      end
    end
  end
end

# Steps
# 1. determine the path (resolve slices)
# 2. build the check expression, handling
#   - choice types
#   - primitives
def get_existance_fhirPath(structure_def, element, check_path)

  # determine the check to make on that path
  if (check_path.end_with?("[x]"))
    # path is not a something to look for, [x] needs to be replaced with a specific type
    # if data found at any of the allowed type paths, this succeeds
    expression = ""
    element.type.each { |oneType| 
      typeSuffix = oneType.code[0].downcase == oneType.code[0] ? oneType.code[0].upcase + oneType.code[1..] : oneType.code
      
      # NOTE: if oneType is Reference, there might be additional checks that should be done
      #   that are not done by typical FHIR validators, such as making sure the reference resolves
      #   and that it conforms to one of the required profiles (if any)
      #   Not clear how to do this in a TestScript instance now, so defering until later
      
      stem = check_path.gsub("[x]", typeSuffix)
      expression += "#{stem}.#{get_existance_fhirPath_forType(oneType.code)} or "
    }
    return expression.chomp(" or ") # remove trailing ' or '

  elsif (element.type.size == 1) # single type
    typeCode = element.type[0].code
    return "#{check_path}.#{get_existance_fhirPath_forType(typeCode)}"

  else
    raise "MULTIPLE TYPES ON A NON-CHOICE ELEMENT?"

  end

end

# returns the FHIRPath function used to check if an element of this type is populated
# for non-primitive types, treats things with extensions only as populated
#   in the future, may want to tighten that up, but don't currently
#   know a FHIRPath expression that can do the check
def get_existance_fhirPath_forType(typeCode)
  if (typeCode[0].downcase == typeCode[0]) # only and all primitive types start with a lower case letter
    # use of hasValue() prevents a primitive element with only extensions from passing
    return "hasValue()"
  else
    # todo - more type-based differentiation needed?
    return "exists()"
  end
end

def resolve_slices_in_element_path(structure_def, element)

  prefix, sliceNameAndSuffix = element.id.split(":", 2) 
  sliceName, suffix = sliceNameAndSuffix.split(".", 2)
  
  if (prefix.end_with?(".extension"))
    
    # get the url to use
    target_element_id = "#{prefix}:#{sliceName}"
    if (element.id == target_element_id)
      profile = element.type[0].profile[0]
    else
      # find this 
      sliceElement = structure_def.snapshot.element.find { |searchElement| searchElement.id == target_element_id }
      raise "Could not find slice definition for #{prefix}:#{sliceName}" if sliceElement == nil
      profile = sliceElement.type[0].profile[0]
    end
    # use .where so that everything follows the same pattern of
    # adding an extra filter function to resolve slices
    replace_key = "[#{sliceName}_PROFILE]"
    filter = "#{prefix}.where(url='#{replace_key}')"
    replacement_list << [replace_key, profile]
  else
    raise "Non-extension slices"
  end

  if (suffix != nil && suffix.length > 0)
    if (suffix.include?(":"))
      raise "nested slices"
    else
      return "#{filter}.#{suffix}"
    end
    
  else
    
    return filter
  end
  
end

def add_reference_checks(resolved_path, element, script)
  
  # NOTE: not clear how to handle multiple response reference elements within testscript
  raise "Multiple Response Reference Elements" if element.max != "1"

  FHIR.logger.info "      Adding referenced instance checks"
  # add read of the referenced instance
  # - add variable for reference value
  script.variable << FHIR::TestScript::Variable.new(name: "referencedInstanceRef", "sourceId": "targetInstance", "expression": "#{resolved_path}.reference")
  # - check that location has data
  referencePopulatedAssert = 
    FHIR::TestScript::Setup::Action::Assert.new(
      description: "resolved path contains reference element",
      label: "resolved_path_contains_reference_element",
      warningOnly: false,
      expression: "#{resolved_path}.reference.hasValue()"
    )
  script.test[0].action << FHIR::TestScript::Setup::Action.new(assert: referencePopulatedAssert)
  # - read operation based on variable
  readReferenceOperation = 
    FHIR::TestScript::Setup::Action::Operation.new(
      description: "Read referenced instance",
      label: "Read_referenced_instance",
      type: FHIR::Coding.new(system: "http://terminology.hl7.org/CodeSystem/testscript-operation-codes", code: "read"),
      responseId: "referencedInstance",
      encodeRequestUrl: false,
      url: "/${referencedInstanceRef}",
    )
  script.test[0].action << FHIR::TestScript::Setup::Action.new(operation: readReferenceOperation)
  # check HTTP status
  responseOkAssert = 
    FHIR::TestScript::Setup::Action::Assert.new(
      description: "Assert Reference Read Response OK",
      label: "Assert_Reference_Read_Response_OK",
      warningOnly: false,
      response: "okay"
    )
  script.test[0].action << FHIR::TestScript::Setup::Action.new(assert: responseOkAssert)

  # if 1 target profile,
  # NOTE: not clear how to handle multiple profiles in TestScript now
  if (element.type[0].targetProfile.length() == 1)
    
    FHIR.logger.info "      Adding referenced instance validation"
    # - add profile
    script.profile << FHIR::Reference.new(id: "referencedProfile", reference:element.type[0].targetProfile[0] )
    # - validate returned resource against that profile
    validateReference = 
      FHIR::TestScript::Setup::Action::Assert.new(
        description: "Validate Reference",
        label: "Validate_Reference",
        warningOnly: false,
        validateProfileId: "referencedProfile"
      )
    script.test[0].action << FHIR::TestScript::Setup::Action.new(assert: validateReference)

  end

end

# adds an assertion checking whether the parent is present
# special handling needed for slices since in the resolved_path
# there will be an extra .[filter function]() present
def add_ancestor_checks(resolved_path, element, script)
  id_levels = element.id.split(".")
  resolved_path_levels = resolved_path.split(".")
  
  ancestor_path = resolved_path_levels[0]
  id_level = 0
  resolved_path_level = 0
  while id_level < id_levels.length() - 2
    id_level += 1
    resolved_path_level += 1
    ancestor_path += ".#{resolved_path_levels[resolved_path_level]}"
    if (id_levels[id_level].include?(":"))
      # add the filter function as well
      resolved_path_level += 1
      ancestor_path += ".#{resolved_path_levels[resolved_path_level]}"
    end
    skip_if_ancestor_doesnt_exist = 
      FHIR::TestScript::Setup::Action::Assert.new(
        description: "skip unless #{ancestor_path} exists",
        label: "skip_unless_#{ancestor_path}_exists",
        warningOnly: true,
        expression: "#{ancestor_path}.exists()"
      )
    add_after_test_placeholder("ancestor-checks", FHIR::TestScript::Setup::Action.new(assert: skip_if_ancestor_doesnt_exist), script)
    FHIR.logger.info "      Adding check for ancestor path #{ancestor_path}"
  end
end

def split_respect_quotes(the_string, separator)
  the_split = the_string.split(separator)
  index = 0
  while (index < the_split.length)
    if (the_split[index].includes("'"))
      
    end
  end
end

end