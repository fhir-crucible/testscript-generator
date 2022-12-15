require 'fhir_models'
require 'digest'

class BaseTemplate
  attr_accessor :ig, :output_path, :replacement_list

  @@template_path = nil
  
  def initialize(output_path, ig_contents)
    self.ig = ig_contents
    self.output_path = "#{output_path}/#{self.class.name}"
    # list to support ordering
    # each entry is itself a list with two entries, key and then value
    self.replacement_list = []
  end

  def make_directory(dir_name)
    FileUtils.mkdir_p(dir_name)
  end

  # Placeholders are action objects with an id element ONLY that starts with the string 'PLACEHOLDER_'
  # These are used to find where to stick optional logic in the test script
  # They should be removed prior to conversion to JSON
  def remove_placeholders(script)
    script.setup.action = script.setup.action.select { |action|
      action.id == nil || !action.id.start_with?("PLACEHOLDER-")
    } unless script.setup == nil
    script.test.each { |one_test|  
      one_test.action = one_test.action.select { |action|
        action.id == nil || !action.id.start_with?("PLACEHOLDER-")
      }
    } unless script.test == nil
    script.teardown = script.teardown.select { |action|
      action.id == nil || !action.id.start_with?("PLACEHOLDER-")
    } unless script.teardown == nil
  end

  # turn a modified template TestScript object into
  # a TestScript instance json string
  # includes
  # - removing placeholder actions
  # - exporting to json
  # - using the replacement_list to replace strings
  def script_to_instantiated_json_string(script)
    remove_placeholders(script)
    script_string = script.to_json
    replacement_list.each do |entry|
      script_string.gsub!(entry[0], entry[1])
    end
    return script_string
  end

  def output_script(path, script, name)
    File.write("#{path}/#{name}.json", script)
  end

  def build_name(*input)
    input.join(" ")
  end

  def assign_script_details(script, script_info_dict)
    add_boilerplate(script)
    customize_script(script, script_info_dict)
  end

  def add_boilerplate(script)
    script.version = '0.0'
    script.experimental = true
    script.status = 'draft'
    script.publisher = 'The MITRE Corporation'
  end

  # Key elements and how they are set
  # - title: built by the specific template, but typically IG + profile + case + specifier if needed (e.g., element)
  # - name: similar to the title, but without the keys and stripped of non-alphanumeric characters
  # - id: SHA-256 hash of the name to create a deterministic instance id
  # - url: root plus the id
  # - date: current timestamp
  def customize_script(script, script_info_dict)
    # put together the title and name from the 
    
    script.title = script_info_dict.reduce("") { |agg, (key, value)|
      "#{agg}#{", " unless agg == ""}#{key}: #{value}"
    }
    script.name = script_info_dict.values.map { |v| v.gsub(/[^0-9a-z]/i, ' ')}.join(' ').split(' ').map(&:capitalize).join('')
    script.id = Digest::SHA2.hexdigest script.name
    script.url = "https://github.com/fhir-crucible/testscript-generator/#{script.id}"
    script.date = DateTime.now.to_s
  end

  def load_template(template_path)
    target_file = File.expand_path("lib/testscript_generator/templates/#{template_path}")
    FHIR.from_contents File.read(target_file)
  end

  # Generates and outputs a TestScript instance that always fails
  #   and indicates that a generation feature isn't implemented
  # Used to indicate that a test is needed to check something, but that it
  #   can't yet be generated
  def generate_not_implmented(script_name_dict, missing_feature_description, output_path)
    script = load_template("not_implemented_template.json")
    assign_script_details(script, script_name_dict)
    script_json = script.to_json
    script_json.gsub!('[MISSING FEATURE]', missing_feature_description)

    output_script(output_path, script_json, script.name)
  end

  def add_after_placeholder(key, to_add, script)
    add_after_setup_placeholder(key, to_add, script)
    add_after_test_placeholder(key, to_add, script)
    add_after_teardown_placeholder(key, to_add, script)
  end

  def add_after_setup_placeholder(key, to_add, script)
    add_after_placeholder_target(key, to_add, script.setup.action) unless script.setup == nil
  end

  def add_after_test_placeholder(key, to_add, script)
    if (script.test != nil)
      script.test.each {|one_test| add_after_placeholder_target(key, to_add, one_test.action) unless one_test == nil}
    end
  end

  def add_after_teardown_placeholder(key, to_add, script)
    add_after_placeholder_target(key, to_add, script.teardown.action) unless script.teardown == nil
  end

  def add_after_placeholder_target(key, to_add, target)
    
    # find the placeholder key
    # action.id == PLACEHOLDER_[key]
    placeholder_index = target.index {|action| action.id != nil && action.id.start_with?("PLACEHOLDER-") }
    raise "no placeholder for key #{key}" if placeholder_index == nil
    if (to_add.is_a?(Array))
      to_add.each { |one_to_add| 
        target.insert(placeholder_index, one_to_add) 
        placeholder_index += 1
      }
    else
      target.insert(placeholder_index, to_add)
    end
  end


end