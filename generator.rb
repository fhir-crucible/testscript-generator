# TODO: Naming and organization clean-up
require 'zlib'
require 'zip'
require 'rubygems/package'
require 'json'
require 'crack'
require 'fhir_models'
require 'pry-nav'
require 'SecureRandom'
require_relative './IGExtractor'
require_relative './TestScriptWorkflow'

class Generator
  include IGExtractor

  MAPPING = {
    'read' => 'read',
    'create' => 'create',
    'delete' => 'delete',
    'search-type' => 'search'
  }

  def igs 
    @igs ||= load_igs
  end 

  def interactions_map
    @interactions_map ||= map_interactions
  end 

  def root
    @root ||= "./testscripts/generated"
  end 

  def title *new_title
    @title = "#{new_title[0].split('-').each(&:upcase!).join(' ')} #{new_title[1].scan(/[A-Z][a-z]+/).join(' ')} #{new_title[2].capitalize} TestScript" unless new_title.empty?
    return @title
  end 

  def map_interactions
    igs.each_with_object({}) do |ig, igs_map|
      resources = ig.capability_statement&.resource
      return unless resources

      igs_map[ig.name] = resources.each_with_object({}) do |resource, resource_map|
        resource_map[resource.type] = resource.interaction.each_with_object({}) do |interaction, interaction_map|
          interaction_map[interaction.code] = interaction.extension[0]&.valueCode
        end
      end 
    end
  end 

  def generate_scripts interaction
    interactions_map.each do |ig_name, interactions|
      dirname = "#{root}/#{ig_name}/#{interaction}"
      FileUtils.mkdir_p dirname unless File.exists? dirname

      interactions.each do |resource_type, verbs_map|
        next unless verbs_map.has_key? interaction
        title(ig_name, resource_type, interaction)

        workflow = TestScriptWorkflow.build(interaction, verbs_map)
        tscript = initialize_tscript(workflow, interaction, resource_type)

        File.write("#{dirname}/#{resource_type}.json", tscript.to_json)
      end 
    end 
  end 

  def random_id
    unless @current_id
      return @current_id ||= SecureRandom.alphanumeric
    end 
    return @current_id = SecureRandom.alphanumeric
  end 

  def random_name
    unless @current_name
      return @current_name ||= SecureRandom.alphanumeric
    end 
    return @current_name = SecureRandom.alphanumeric
  end 

  def initialize_tscript(workflow, action, resource) 
    backbone = FHIR::TestScript.new(script_boilerplate(action))
    populate_setup(workflow[:setup], backbone, resource)
    populate_execution(workflow[:execution], backbone, resource)
    return backbone
  end 

  def script_boilerplate action
    return {
      url: 'https://gitlab.mitre.org/fhir-foundry/',
      version: '0.0',
      id: @title.split(' ').each(&:downcase!).join('-'),
      name: @title,
      status: 'draft',
      experimental: true,
      date: DateTime.now.to_s,
      publisher: 'The MITRE Corporation'
    } 
  end 

  def populate_setup(setup, tscript, resource)
    return unless setup  
    actions = setup.each_with_object([]) do |element, arr|
      arr << FHIR::TestScript::Setup::Action.new({
        operation: create_operation(element, resource, tscript, true),
      })
      create_assertions(element, tscript, resource)&.each do |el|
        arr << FHIR::TestScript::Test::Action.new({ assert: el })
      end 
    end 
    tscript.setup = FHIR::TestScript::Setup.new({action: actions})
  end 
  
  def populate_execution(execution, tscript, resource)
    return unless execution

    test_actions = execution.map do |element|
      tmp = []
      tmp << FHIR::TestScript::Test::Action.new({
        operation: create_operation(element, resource, tscript, false)
      }) 
      create_assertions(element, tscript, resource).each do |el|
        tmp << FHIR::TestScript::Test::Action.new({ assert: el })
      end 
      tmp
    end 
    test_actions.each do |action|
      tscript.test << FHIR::TestScript::Test.new({action: action})
    end 
    return tscript
  end 

  def create_operation(workflow, resource, tscript, setup = false)
    op_input = {
      type: FHIR::Coding.new(code: MAPPING[workflow[:method]], system: 'http://terminology.hl7.org/CodeSystem/testscript-operation-codes'),
      resource: resource,
      encodeRequestUrl: false
    }
    op_input[:params] = "?_type=#{resource}" if setup
    op_input[:responseId] = random_id if setup

    add_var(tscript, workflow) if setup

    op_input[:params] = "/${#{@current_name}}" unless setup
    FHIR::TestScript::Setup::Action::Operation.new(op_input)
  end 

  def add_var(tscript, workflow)
    tscript.variable << FHIR::TestScript::Variable.new({
      name: random_name,
      sourceId: @current_id,
      expression: 'Bundle.entry.first.resource.id'
    })
  end 

  def create_assertions(element, tscript, resource)
    if element[:method] == 'read' 
      return [FHIR::TestScript::Setup::Action::Assert.new({
        "description": "Confirm that the returned HTTP status is 200(OK).",
        "response": "okay",
        "warningOnly": false
        }),
        FHIR::TestScript::Setup::Action::Assert.new({
          "description": "Confirm that the returned resource type is #{resource}.",
          "resource": "#{resource}",
          "warningOnly": false
        })
      ] 
    elsif element[:method] == 'create'
      return [FHIR::TestScript::Setup::Action::Assert.new({
        "description": "Confirm that the returned HTTP status is 200(OK).",
        "response": "okay",
        "warningOnly": false
        }),
        FHIR::TestScript::Setup::Action::Assert.new({
          "description": "Confirm that the returned resource type is OperationOutcome.",
          "resource": "OperationOutcome",
          "warningOnly": false
        })
      ] 
    elsif element[:method] == 'update'
      return [FHIR::TestScript::Setup::Action::Assert.new({
        "description": "Confirm that the returned HTTP status is 200(OK).",
        "response": "okay",
        "warningOnly": false
        }),
        FHIR::TestScript::Setup::Action::Assert.new({
          "description": "Confirm that the returned resource type is OperationOutcome.",
          "resource": "OperationOutcome",
          "warningOnly": false
        })
      ] 
    elsif element[:method] == 'delete'
      return [FHIR::TestScript::Setup::Action::Assert.new({
        "description": "Confirm that the returned HTTP status is 200(OK).",
        "response": "okay",
        "warningOnly": false
        }),
        FHIR::TestScript::Setup::Action::Assert.new({
          "description": "Confirm that the returned resource type is OperationOutcome.",
          "resource": "OperationOutcome",
          "warningOnly": false
        })
      ] 
    end 
  end 
end 