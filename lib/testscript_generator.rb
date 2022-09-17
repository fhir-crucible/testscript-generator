
require 'rails'
require 'pry-nav'
require 'fileutils'
require_relative 'testscript_generator/ig'
require_relative 'testscript_generator/workflow_builder'
require_relative 'testscript_generator/testscript_builder'

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
		@igs ||= Dir.glob(igs_path).each_with_object({}) do |package, store|
			ig = IG.new(package)
			store[ig.name] = ig
		end
	end

	def initialize(igs_path, output_path)
		@igs_path = igs_path
		@output_path = output_path

		igs_path.concat('/*') if File.directory?(igs_path)
	end

	def add_boilerplate(script, script_name)
		script.url = 'https://github.com/fhir-crucible/testscript-generator'
		script.version = '0.0'
		script.name = script_name.split('_').map(&:capitalize).join('')
		script.title = script_name.split('_').map(&:capitalize).join(' ')
		script.id = script_name.gsub('_', '-')
		script.status = 'draft'
		script.experimental = true
		script.date = DateTime.now.to_s
		script.publisher = 'The MITRE Corporation'
	end

	def get_name(ig, resource, verb, interaction)
		"#{ig}_#{resource}_#{verb}_#{interaction}".gsub("-", "_").downcase!
	end

	def output_script(script, name)
		FileUtils.mkdir_p(output_path)
		File.write("#{output_path}/#{name}.json", script)
	end

	def output_example(resource)
		example_resource = "FHIR::#{resource}".constantize.new.to_json
		FileUtils.mkdir_p("#{output_path}/fixtures")
		File.write("#{output_path}/fixtures/example_#{resource.downcase}.json", example_resource)
	end

	def generate_interaction_conformance
		igs.each do |name, ig|
			FHIR.logger.info "Generating TestScripts from #{name} IG ...\n"

			['SHALL', 'SHOULD', 'MAY'].each do |target_verb|
				FHIR.logger.info "	Generating #{target_verb} support tests\n"

				ig.interactions.each do |resource, verbs_map|
					target_verb_interactions = verbs_map.filter_map do |action, verb|
						action if verb == target_verb
					end

					target_verb_interactions.each do |interaction|
						if ['create', 'read', 'update', 'delete', 'search-type'].include?(interaction)

							if workflows[interaction]
								script = scripts[workflows[interaction]]
								script_name = get_name(name, resource, target_verb, interaction)
								add_boilerplate(script, script_name)
								script = script.to_json.gsub("${RESOURCE_TYPE_1}", resource).gsub("${EXAMPLE_RESOURCE_1}_reference", "example_#{resource.downcase}.json").gsub("${EXAMPLE_RESOURCE_1}", "example_#{resource.downcase}")
								output_script(script, script_name)
								output_example(resource)
							else
								workflow = workflow_builder.build(test: interaction)
								workflows[interaction] = workflow
								scripts[workflow] = script_builder.build(workflow)
							end

							FHIR.logger.info "		Generated tests for #{resource} [#{interaction}]."
						else
							FHIR.logger.info "		Skipping test generation for #{resource} [#{interaction}]. Currently only CRUD + Search interactions supported."
							next
						end
					end
				end

				puts "\n"
			end

			FHIR.logger.info "... finished generating TestScripts from #{name} IG.\n"
		end
	end
end