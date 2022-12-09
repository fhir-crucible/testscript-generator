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
      instantiate_element(structure_def, element)
      instantiate_element_choices(structure_def, element) if element.path.end_with?("[x]")
    end
  end
end

def instantiate_element(structure_def, element)
  FHIR.logger.info "    Generating test for element #{element.id}"
  
  # output details
  file_location = "#{output_path}/#{structure_def.name}"
  # TODO: make this name unique if this method gets reused
  script_name = build_name(ig.name, structure_def.name, 'must_support_element', element.id.gsub(".", "_"))
  
  begin
    # load template
    script = load_template(@@template_path)

    # get the base path
    resolved_path = element.id.include?(":") ? resolve_slices_in_element_path(structure_def, element) : element.path
    
    # add additional details, if needed
    # - reference type: fetch and validate the referenced resource, possibly against a profile
    # - nested elements: add logic to skip test if parent(s) are not populated
    if (element.type.length() == 1 && element.type[0].code == "Reference")
      add_reference_checks(resolved_path, element, script)
    end
    element_level = element.path.count(".")
    if (element_level > 1) # nested
      levels = element.path.split(".")
      for level in 1..(element_level - 1) do
        ancestor_path = levels[0..level].reduce("") { |agg, oneLevel| "#{agg}.#{oneLevel}" }[1..]
        skip_if_ancestor_doesnt_exist = 
          FHIR::TestScript::Setup::Action::Assert.new(
            description: "skip unless #{ancestor_path} exists",
            label: "skip_unless_#{ancestor_path}_exists",
            warningOnly: true,
            expression: "#{ancestor_path}.exists()"
          )
        script.test[0].action << FHIR::TestScript::Setup::Action.new(assert: skip_if_ancestor_doesnt_exist)
        FHIR.logger.info "      Adding check for ancestor path #{ancestor_path}"
      end


    end

    # add metadata (name, id, etc.)
    script_name = build_name(ig.name, structure_def.name, 'must_support_element', element.path.gsub(".", "_"))
    assign_script_details(script, script_name)

    # export to JSON and replace string keys
    new_script = script.to_json
    new_script.gsub!('[PROFILE_URL]', structure_def.url)
    new_script.gsub!('[PROFILE_NAME]', structure_def.name)
    new_script.gsub!('[BASE_RESOURCE]', structure_def.type)
    new_script.gsub!('[ELEMENT_PATH]', element.path)
    new_script.gsub!('[ELEMENT_EXISTENCE_FHIR_PATH]', get_existance_fhirPath(structure_def, element, resolved_path))
        
    # save to file
    output_script(file_location, new_script, script_name.gsub(" ", "_"))
  rescue Exception => e  
    FHIR.logger.info "      failed: #{e.message}"
    
    # generate stub
    generate_not_implmented(script_name, e.message, file_location)
  end
end

def instantiate_element_choices(structure_def, element)
  # todo
  # possible idea = doctor the element once for each must support type and call instantiate_element

end

# Steps
# 1. determine the path (resolve slices)
# 2. build the check expression, handling
#   - choice types
#   - primitives
def get_existance_fhirPath(structure_def, element, checkPath)

  # determine the check to make on that path
  if (checkPath.end_with?("[x]"))
    # path is not a something to look for, [x] needs to be replaced with a specific type
    # if data found at any of the allowed type paths, this succeeds
    expression = ""
    element.type.each { |oneType| 
      typeSuffix = oneType.code[0].downcase == oneType.code[0] ? oneType.code[0].upcase + oneType.code[1..] : oneType.code
      
      # NOTE: if oneType is Reference, there might be additional checks that should be done
      #   that are not done by typical FHIR validators, such as making sure the reference resolves
      #   and that it conforms to one of the required profiles (if any)
      #   Not clear how to do this in a TestScript instance now, so defering until later
      
      stem = checkPath.gsub("[x]", typeSuffix)
      expression += "#{stem}.#{get_existance_fhirPath_forType(oneType.code)} or "
    }
    return expression.chomp(" or ") # remove trailing ' or '

  elsif (element.type.size == 1) # single type
    typeCode = element.type[0].code
    return "#{element.path}.#{get_existance_fhirPath_forType(typeCode)}"

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
    if (element.id == "#{prefix}:#{sliceName}")
      profile = element.type[0].profile[0]
    else
      raise "Elements Under Slices"
    end

    filter = "#{prefix[..-11]}.extension(#{profile})"
  else
    raise "Non-extension slices"
  end

  if (suffix != nil && suffix.length > 0)
    # discard the slice name and recurse
    # return filter + "." + "elementsUnderSlicesNotImplemented()"
    raise "Elements under slices"
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
      description: "#{element.path} contains reference element",
      label: "#{element.path}_contains_reference_element",
      warningOnly: false,
      expression: "#{element.path}.reference.hasValue()"
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

end