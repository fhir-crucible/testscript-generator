require_relative 'generator'

class SearchParameterGenerator < Generator
  def base_searchparam_resources
    @base_searchparam_resources ||= begin
      path = "lib/testscript_generator/generators/base_searchparameters.json"
      searchparams_bundle = FHIR.from_contents(File.read(Dir[path].first))
      searchparams_bundle.entry.each_with_object({}) do |entry, store|
        store[entry.resource.name] = entry.resource
      end
    end
  end

  def generate_base_searchparams
    base_searchparam_resources.each do |key, value|
      blueprints[key] = blueprinter.build(test: "search-type", test_params: value)
    end

    FHIR.logger.info "	Generating basic search parameter tests\n"

    blueprints.each do |key, value|
      script = script_builder.build(value)
      make_directory("#{output_path}/#{key}")

      ig.structure_defs.keys.each do |resource|
        script_name = build_name(ig.name, 'search', key.gsub("_", ""), resource)
        assign_script_details(script, ig.name)
        new_script = script.to_json.gsub('${RESOURCE_TYPE_1}', resource).gsub('${EXAMPLE_RESOURCE_1}_reference', "example_#{resource.downcase}.json").gsub(
          '${EXAMPLE_RESOURCE_1}', "example_#{resource.downcase}"
        )
        output_script("#{output_path}/#{key}", new_script, script_name.gsub(" ", "_"))
        output_example("#{output_path}/#{key}", resource)

        FHIR.logger.info "		Generated test for #{resource} search by #{key}."
      end
    end
    puts
    FHIR.logger.info "	... finished generating basic search parameters tests\n"
  end

  def generate_supported_searchparams
  end

  def generate_all_searchparams
  end
end