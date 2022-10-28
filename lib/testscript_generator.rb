# frozen_string_literal: true

require 'fileutils'
require_relative 'testscript_generator/ig'
require_relative 'testscript_generator/workflow_builder'
require_relative 'testscript_generator/testscript_builder'

require 'pry-nav'

# The TestScriptGenerator class is responsible for guiding generation
# depending on intent. While right now the generator can only generate
# basic 'interaction' tests, in the future it will be responsible for
# giving the appropriate inputs to the builder, depending on the generation
# intent (interaction, basic search, operations etc.)
class TestScriptGenerator
  attr_accessor :igs_path, :output_path

  def workflows
    @workflows ||= {}
  end

  def scripts
    @scripts ||= {}
  end

  def workflow_builder
    @workflow_builder ||= WorkflowBuilder.new
  end

  def script_builder
    @script_builder ||= TestScriptBuilder.new
  end

  def igs
    @igs ||= Dir["#{igs_path}/**/*"].each_with_object({}) do |package, store|
      ig = IG.new(package)
      store[ig.name] = ig
    end
  end

  def initialize(igs_path, output_path)
    self.igs_path = igs_path
    self.output_path = output_path
  end

  def add_boilerplate(script)
    script.url = 'https://github.com/fhir-crucible/testscript-generator'
    script.version = '0.0'
    script.experimental = true
    script.status = 'draft'
    script.publisher = 'The MITRE Corporation'
  end

  def customize_script(script, script_name)
    name = script_name.split('_').map(&:capitalize)
    script.name = name.join('')
    script.title = name.join(' ')
    script.id = script_name.gsub('_', '-')
    script.date = DateTime.now.to_s
  end

  def assign_script_details(script, script_name)
    add_boilerplate(script)
    customize_script(script, script_name)
  end

  def build_name(*input)
    input.map(&:downcase).join(" ").gsub("-", " ")
  end

  def output_script(path, script, name)
    File.write("#{path}/#{name}.json", script)
  end

  def output_example(path, resource)
    example_resource = "FHIR::#{resource}".constantize.new.to_json
    FileUtils.mkdir_p("#{path}/fixtures")
    File.write("#{path}/fixtures/example_#{resource.downcase}.json", example_resource)
  end

  def make_directory(dir_name)
    FileUtils.mkdir_p(dir_name)
  end

  def generate_interaction_conformance
    igs.each do |ig_name, ig_contents|
      FHIR.logger.info "Generating TestScripts from #{ig_name} IG ...\n"
      ig_directory = "#{output_path}/#{ig_name}"
      make_directory(ig_directory)

      %w[SHALL SHOULD MAY].each do |conformance_level|
        FHIR.logger.info "	Generating #{conformance_level} support tests\n"
        conformance_directory = "#{ig_directory}/#{conformance_level}"
        make_directory(conformance_directory)

        ig_contents.interactions.each do |resource, verbs_map|
          target_verb_interactions = verbs_map.filter_map do |action, verb|
            action if verb == conformance_level
          end

          target_verb_interactions.each do |interaction|
            if %w[create read update delete search-type].include?(interaction)

              if workflows[interaction]
                script = scripts[workflows[interaction]]
              else
                workflow = workflow_builder.build(test: interaction)
                workflows[interaction] = workflow
                scripts[workflow] = script_builder.build(workflow)
                script = scripts[workflow]
              end

              script_name = build_name(ig_name, conformance_level, interaction, resource)
              assign_script_details(script, ig_name)
              script = script.to_json.gsub('${RESOURCE_TYPE_1}', resource).gsub('${EXAMPLE_RESOURCE_1}_reference', "example_#{resource.downcase}.json").gsub(
                '${EXAMPLE_RESOURCE_1}', "example_#{resource.downcase}"
              )
              output_script(conformance_directory, script, script_name)
              output_example(conformance_directory, resource)

              FHIR.logger.info "		Generated tests for #{resource} [#{interaction}]."
            else
              FHIR.logger.info "		Skipping test generation for #{resource} [#{interaction}]. Currently only CRUD + Search interactions supported."
              next
            end
          end
        end

        puts "\n"
      end

      FHIR.logger.info "... finished generating TestScripts from #{ig_name} IG.\n"
    end
  end
end
