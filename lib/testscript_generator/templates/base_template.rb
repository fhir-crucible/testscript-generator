require 'fhir_models'

class BaseTemplate
  attr_accessor :ig, :output_path

  @@template_path = nil
  
  def initialize(output_path, ig_contents)
    self.ig = ig_contents
    self.output_path = "#{output_path}/#{self.class.name}"
  end

  def make_directory(dir_name)
    FileUtils.mkdir_p(dir_name)
  end

  def output_script(path, script, name)
    File.write("#{path}/#{name}.json", script)
  end

  def build_name(*input)
    input.map(&:downcase).join(" ").gsub("-", " ")
  end

  def assign_script_details(script, script_name)
    add_boilerplate(script)
    customize_script(script, script_name)
  end

  def add_boilerplate(script)
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
    script.url = "https://github.com/fhir-crucible/testscript-generator/#{script.id}"
  end

  def load_template(template_path)
    target_file = File.expand_path("lib/testscript_generator/templates/#{template_path}")
    FHIR.from_contents File.read(target_file)
  end

  # Generates and outputs a TestScript instance that always fails
  #   and indicates that a generation feature isn't implemented
  # Used to indicate that a test is needed to check something, but that it
  #   can't yet be generated
  def generate_not_implmented(script_name, missing_feature_description, output_path)
    script = load_template("not_implemented_template.json")
    assign_script_details(script, script_name)
    script_json = script.to_json
    script_json.gsub!('[MISSING FEATURE]', missing_feature_description)

    output_script(output_path, script_json, script_name.gsub(" ", "_"))
  end

end