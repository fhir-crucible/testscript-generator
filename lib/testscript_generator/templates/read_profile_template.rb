require_relative 'base_template'
require "csv"

class ReadProfileTemplate < BaseTemplate

  @@template_path = "read_profile_template.json"
  @@profile_scope_search_spec_path = "extra_input"
  @@profile_scope_search_spec_file = "profile_scope_search_spec.csv"
  @@search_and_read_template_path = "search_and_read_profile_template.json"

  def instantiate 

    scope_search_spec = nil
    scope_search_spec_target_filepath = File.join(@@profile_scope_search_spec_path, ig.name, @@profile_scope_search_spec_file)
    if (File.file? scope_search_spec_target_filepath)
      
      # pull in details
      scope_search_spec_csv = CSV.parse(File.read(scope_search_spec_target_filepath), headers: true)
      scope_search_spec = {}
      scope_search_spec_csv.each { |one_row| scope_search_spec[one_row["profile"]] = [one_row["search"], one_row["passCriteria"]]}
   
      # get template setup
      search_and_read_script = load_template(@@search_and_read_template_path)
      search_and_read_script_name_dict = {
        "IG" => ig.name,
        "Case" => "Search and Read Profiles from Root Patient"
      }
      assign_script_details(search_and_read_script, search_and_read_script_name_dict)

    end 

    make_directory(output_path)
    ig.structure_defs.keys.each do |resource_type|
      ig.structure_defs[resource_type].each do |structure_def|
        if (structure_def.kind == "resource" && !structure_def.abstract)
          FHIR.logger.info "  Generating Read Profile Test for Profile #{structure_def.name}"
          script_name = instantiate_profile(structure_def)
          FHIR.logger.info "  ... finished Generating Read Profile Test for Profile #{structure_def.name}"
          
          if (scope_search_spec && scope_search_spec[structure_def.name] != nil)
            if scope_search_spec[structure_def.name][0] == "ROOT"
              # add the patient test first
              patient_root_test = build_root_patient_test(structure_def.name, script_name)
              search_and_read_script.test.insert(0, patient_root_test)
            elsif scope_search_spec[structure_def.name][0] == "SPECIFY"
              # don't search, take id as input for this subtest
              profile_test = build_specified_instance_test(structure_def.name, script_name)
              search_and_read_script.test << profile_test
              search_and_read_script.variable << FHIR::TestScript::Variable.new(name: "targetResourceId#{structure_def.name}", "defaultValue": "example", "description": "Enter a known instance id on the destination system. Will be checked for conformance against profile #{structure_def.name}.", "hint": "[resource.id]")
            else
              # search and use in subtesteach
              search_and_read_test = build_search_and_read_test(structure_def, script_name, scope_search_spec[structure_def.name][0], scope_search_spec[structure_def.name][1])
              search_and_read_script.test << search_and_read_test
            end
          end  
        end
      end
    end

    if scope_search_spec
      FHIR.logger.info "  Generating combined search and read from root patient test"
      replacement_list.clear
      replacement_list << ['[IG]', ig.name]
      
      # generate and output
      search_and_read_script_json = script_to_instantiated_json_string(search_and_read_script)
      output_script(output_path, search_and_read_script_json, search_and_read_script.name)
      FHIR.logger.info "  ... finished Generating combined search and read from root patient test"
    end

  end

    def instantiate_profile(structure_def)
      replacement_list.clear
      replacement_list << ['[PROFILE_URL]', structure_def.url]
      replacement_list << ['[PROFILE_NAME]', structure_def.name]
      replacement_list << ['[BASE_RESOURCE]', structure_def.type]

      # output details
      file_location = "#{output_path}"
      script_name_dict = {
        "IG" => ig.name,
        "Profile" => structure_def.name,
        "Case" => "Read Profile"
      }

    script = load_template(@@template_path)
    assign_script_details(script, script_name_dict)
    script_json = script_to_instantiated_json_string(script)
    output_script(file_location, script_json, script.name)

    return script.name
  end

  def build_root_patient_test(profile_name, subtest_name)
    root_patient_test = FHIR::TestScript::Test.new(
      name: "Check root patient is conformant"
    )
    patient_subtest_assert = FHIR::TestScript::Setup::Action::Assert.new(
      description: "Execute Patient Read Subtest",
      label: "Execute_Patient_Read_Subtest",
      warningOnly: false
    )
    patient_subtest_assert.extension << build_subtest_extension(subtest_name, {"root#{ig.name}IGPatientId" => "targetResourceId#{profile_name}"})
    root_patient_test.action << FHIR::TestScript::Setup::Action.new(assert: patient_subtest_assert)

    return root_patient_test

  end

  def build_specified_instance_test(profile_name, subtest_name)
    specified_instance_test = FHIR::TestScript::Test.new(
      name: "Check a specified instance of #{profile_name}"
    )
    specified_instance_subtest_assert = FHIR::TestScript::Setup::Action::Assert.new(
      description: "Execute #{profile_name} Read Subtest",
      label: "Execute_#{profile_name}_Read_Subtest",
      warningOnly: false
    )
    specified_instance_subtest_assert.extension << build_subtest_extension(subtest_name, {"targetResourceId#{profile_name}" => "targetResourceId#{profile_name}"})
    specified_instance_test.action << FHIR::TestScript::Setup::Action.new(assert: specified_instance_subtest_assert)

    return specified_instance_test

  end

  def build_search_and_read_test(profile_def, subtest_name, scope_search_criteria, pass_criteria)
    profile_name = profile_def.name
    search_and_read_test = FHIR::TestScript::Test.new(
      name: "Search for #{profile_name} instances and read each"
    )
    # actions
    # - search
    search_params = "?patient=${root#{ig.name}IGPatientId}"
    if (scope_search_criteria)
      search_params += "&#{scope_search_criteria}"
    end
    search_and_read_test.action << build_search_profile_scope_operation_action(profile_name, profile_def.type, search_params)
    # - response ok
    search_and_read_test.action << build_response_ok_assert_action()
    # - bundle returned
    search_and_read_test.action << build_resource_type_returned_assert_action("Bundle")
    # - self link ok
    self_link_check_description = "Assert Self Link URL Includes Search Parameters"
    self_link_check_expression = "link.where(relation = 'self').url.contains('patient=')"
    if (scope_search_criteria)
      criteria_split = scope_search_criteria.split("=",2)
      if (criteria_split[1].include?("="))
        raise "implement support for multiple criteria"
      else
        self_link_check_expression += " and link.where(relation = 'self').url.contains('#{criteria_split.first}=')"
      end
    end
    search_and_read_test.action << build_expression_assert_action(self_link_check_description, self_link_check_expression, "true")
    # - at least one entry
    at_least_one_entry_description = "Assert At Least One Entry Returned"
    at_least_one_entry_expression = "entry.count() > 0"
    search_and_read_test.action << build_expression_assert_action(at_least_one_entry_description, at_least_one_entry_expression, "true")
    # - subtest each
    instances_subtesteach_assert = FHIR::TestScript::Setup::Action::Assert.new(
      description: "Execute Read Subtest on #{profile_name} instances",
      label: "Execute_Read_Subtest_on_#{profile_name}_instances",
      warningOnly: false,
      expression: "entry.where(fullUrl.contains('#{profile_def.type}')).fullUrl.replaceMatches('.*/', '')"
    )
    instances_subtesteach_assert.extension << build_subtest_each_extension(subtest_name, "targetResourceId#{profile_name}", pass_criteria)
    search_and_read_test.action << FHIR::TestScript::Setup::Action.new(assert: instances_subtesteach_assert)

    return search_and_read_test
  end


  def build_subtest_extension(subtest_name, variable_name_map)
    root_extension = FHIR::Extension.new(
      url: "urn:mitre:fhirfoundry:subtest"
    )
    subtest_name_extension = FHIR::Extension.new(
      url: "testName",
      valueString: subtest_name
    )
    root_extension.extension << subtest_name_extension
    variable_name_map.each { |source_var_name, target_var_name| root_extension.extension << build_subtest_variable_binding_extension(source_var_name, target_var_name)}
    
    return root_extension

  end

  def build_subtest_each_extension(subtest_name, bind_each_target, pass_criteria, variable_name_map = {})
    root_extension = FHIR::Extension.new(
      url: "urn:mitre:fhirfoundry:subtestEach"
    )
    root_extension.extension << FHIR::Extension.new(
      url: "testName",
      valueString: subtest_name
    )
    root_extension.extension << FHIR::Extension.new(
      url: "passCriteria",
      valueCode: pass_criteria
    )
    root_extension.extension << FHIR::Extension.new(
      url: "bindEachTarget",
      valueString: bind_each_target
    )
    variable_name_map.each { |source_var_name, target_var_name| root_extension.extension << build_subtest_variable_binding_extension(source_var_name, target_var_name)}
    
    return root_extension

  end

  def build_subtest_variable_binding_extension(source_var_name, target_var_name)
    binding_extension = FHIR::Extension.new(
      url: "bindVariable"
    )
    binding_extension.extension << FHIR::Extension.new(
      url: "bindSource",
      valueString: source_var_name
    )
    binding_extension.extension << FHIR::Extension.new(
      url: "bindTarget",
      valueString: target_var_name
    )

    return binding_extension
  end

  def build_search_profile_scope_operation_action(profile_name, resource_type, criteria)
    search_operation = FHIR::TestScript::Setup::Action::Operation.new(
      "description": "#{profile_name} Search",
      "label": "#{profile_name}_Search",
      "type": {
        "code": "search",
        "system": "http://terminology.hl7.org/CodeSystem/testscript-operation-codes"
      },
      "resource": resource_type,
      "encodeRequestUrl": true,
      "params": criteria
    )
    
    return FHIR::TestScript::Setup::Action.new(operation: search_operation)
  end

  def build_response_ok_assert_action()
    the_assert = FHIR::TestScript::Setup::Action::Assert.new(
      "description": "Assert response OK",
      "label": "Assert_response_OK",
      "response": "okay"
    )
    return FHIR::TestScript::Setup::Action.new(assert: the_assert)
  end

  def build_resource_type_returned_assert_action(resource_type)
    the_assert = FHIR::TestScript::Setup::Action::Assert.new(
      "description": "Assert #{resource_type} Returned",
      "label": "Assert_#{resource_type}_Returned",
      "resource": resource_type
    )

    return FHIR::TestScript::Setup::Action.new(assert: the_assert)
  end
  
  def build_expression_assert_action(description, expression, expected = "true")
    the_assert = FHIR::TestScript::Setup::Action::Assert.new(
      "description": description,
      "label": description.gsub(" ", "_"),
      "expression": expression,
      "value": expected
    )

    return FHIR::TestScript::Setup::Action.new(assert: the_assert)
  end


end