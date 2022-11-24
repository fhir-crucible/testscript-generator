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
    if (element.mustSupport && element.path.include?("."))
      instantiate_element(structure_def, element)
    end
  end
end

def instantiate_element(structure_def, element)
  FHIR.logger.info "    Generating test for element #{element.path}"
  
  script = load_template(@@template_path)
  
  # add metadata (name, id, etc.)
  script_name = build_name(ig.name, structure_def.name, 'must_support_element', element.path.gsub(".", "_"))
  assign_script_details(script, script_name)

  # export to JSON and replace string keys
  new_script = script.to_json
  new_script.gsub!('[PROFILE_URL]', structure_def.url)
  new_script.gsub!('[PROFILE_NAME]', structure_def.name)
  new_script.gsub!('[BASE_RESOURCE]', structure_def.type)
  new_script.gsub!('[ELEMENT_PATH]', element.path)
  new_script.gsub!('[ELEMENT_EXISTENCE_FHIR_PATH]', "#{element.path}.exists() and #{element.path}.length() > 0")
      
  # save to file
  output_script("#{output_path}/#{structure_def.name}", new_script, script_name.gsub(" ", "_"))
end


end