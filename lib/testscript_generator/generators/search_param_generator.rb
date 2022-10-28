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
    # Expected type ? But more we need to know the path so that we can snag it from the
    # setup
    binding.pry
  end

  def generate_supported_searchparams
    # Check which params apply to all, and which params apply only to specific resources
    # Expected type of value

    # Filter for a given resource, all the params that may or not be applied to that given resource type

  end

  def generate_all_searchparams

  end
end