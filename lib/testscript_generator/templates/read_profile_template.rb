require_relative 'base_template'

class ReadProfileTemplate < BaseTemplate

  @@template_path = "read_profile_template.json"
  

  def instantiate 

    make_directory(output_path)
    ig.structure_defs.keys.each do |resource_type|
      ig.structure_defs[resource_type].each do |structure_def|
        if (structure_def.kind == "resource" && !structure_def.abstract)
          FHIR.logger.info "  Generating Read Profile Test for Profile #{structure_def.name}"
          instantiate_profile(structure_def)
          FHIR.logger.info "  ... finished Generating Read Profile Test for Profile #{structure_def.name}"
        end
      end
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
end

end