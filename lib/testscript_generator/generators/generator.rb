require_relative 'blueprint_builder'
require_relative 'testscript_builder'

class Generator
  attr_accessor :ig, :ig_name, :output_path

  def blueprinter
    @blueprinter ||= BlueprintBuilder.new
  end

  def script_builder
    @script_builder ||= TestScriptBuilder.new
  end

  def blueprints
    @blueprints ||= {}
  end

  def scripts
    @scripts ||= {}
  end

  def initialize(output_path, ig_contents)
    self.ig = ig_contents
    self.output_path = "#{output_path}/search_params"
  end

  def make_directory(dir_name)
    FileUtils.mkdir_p(dir_name)
  end

  def output_script(path, script, name)
    File.write("#{path}/#{name}.json", script)
  end

  def output_example(path, resource)
    example_resource = "FHIR::#{resource}".constantize.new.to_json
    FileUtils.mkdir_p("#{path}/fixtures")
    File.write("#{path}/fixtures/example_#{resource.downcase}.json", example_resource)
  end

  def build_name(*input)
    input.map(&:downcase).join(" ").gsub("-", " ")
  end

  def assign_script_details(script, script_name)
    add_boilerplate(script)
    customize_script(script, script_name)
  end

  def add_boilerplate(script)
    script.url = 'https://github.com/fhir-crucible/testscript-generator'
    script.version = '0.0'
    script.experimental = true
    script.status = 'draft'
    script.publisher = 'The MITRE Corporation'
  end

  def customize_script(script, script_name)
    name = script_name.split(' ').map(&:capitalize)
    script.name = name.join('_')
    script.title = script_name
    script.id = name.join('-')
    script.date = DateTime.now.to_s
  end
end