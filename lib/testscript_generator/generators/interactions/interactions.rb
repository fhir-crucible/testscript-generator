require 'yaml'

# I would focus more on confirming the logic that ought to go into the
# interactions_base file first and then build this out based on the info you
# find yourself constantly reaching for from the interactions objects.

# What is a dynamic requirement? It's something that needs to be known, specifically, in order
# to access a specific resource on the endpoint

module Interactions
  def interactions
    base_interactions
  end

  def base_interactions
    @base_interactions ||= begin
      path = "lib/testscript_generator/generators/interactions/interactions_base.yml"
      YAML.load(File.read(Dir[path].first))
    end
  end

  def method(interaction)
    interactions[interaction]
  end

  def requires_setup?(interaction)
    base_interactions[interaction]["dynamic_reqs"].present?
  end

  def dynamic_requirement?(interaction)
    interactions[interaction]
  end

  def requires_id?(interaction)
    interactions[interaction].dynamic_requirements
  end

  def requires_type?(interaction)
  end
end