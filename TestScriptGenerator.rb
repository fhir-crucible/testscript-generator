require 'SecureRandom'

class TestScriptGenerator
  attr_accessor :name, :interactions

  CONFORMANCE = ['SHALL', 'SHOULD', 'MAY']

  def scripts
    @script ||= {}
  end 

  def root
    "./testscripts/generated/#{name}"
  end 

  def initialize(name, interactions)
    self.name = name
    self.interactions = interactions
  end 

  def conformance_generation
    CONFORMANCE.each do |target_verb|
      FHIR.logger.info "  Generating #{target_verb} support tests\n"

      interactions.each do |resource, verbs_map|
        supported = verbs_map.filter_map do |action, verb|
          action if (verb == target_verb) || (verb == 'SHALL')
        end 

        supported.each do |interaction|
          unless IMPLEMENTED.include? interaction
            FHIR.logger.warn "    Support for '#{interaction}' not implemented, unable to create '#{resource} #{interaction}' TestScript"
            next 
          end 

          script = create_script(resource, interaction, (supported - [interaction]))

          unless script
            FHIR.logger.warn "    Supported interactions do not allow for auto-generation, unable to create '#{resource} #{interaction}' TestScript"
            next
          end 

          dirname = "#{root}/#{target_verb}/#{interaction}"
          FileUtils.mkdir_p dirname unless File.exists? dirname

          script.id = "#{resource}-#{interaction}-TestScript"
          
          File.write("#{dirname}/#{resource}-TestScript.json", script.to_json.gsub('$RESOURCETYPE', resource))
          FHIR.logger.info "    Created '#{resource} #{interaction}' TestScript"
        end
      end 
      puts "\n"
    end 
  end 
  
  def create_script(resource, interaction, supported)
    workflow = workflow(interaction, supported)
    return unless workflow

    script = scripts[workflow] || build_script(workflow)
    return script
  end 

  # <-- workflow: logical --> 
  FETCHER = ['read', 'search']
  MODIFIER = ['create', 'update', 'delete']
  REQ_ID = ['read', 'update', 'delete']

  IMPLEMENTED = ['create', 'read', 'update', 'delete', 'search-type']

  def workflow(target, options)
    id = options.find { |interaction| !REQ_ID.include? interaction } if REQ_ID.include? target
    id = nil unless IMPLEMENTED.include? id

    return nil if REQ_ID.include? target and id.nil?
    return { target: target, id: id }
  end 

  def build_script workflow
    script = boilerplate(FHIR::TestScript.new, workflow[:target])

    build_setup(script, workflow[:id]) if workflow[:id]
    build_test(script, workflow[:target])

    return script
  end 

  def boilerplate(script, target)
    script.name = "#{name}-$RESOURCETYPE-#{target}"
    script.url = 'https://gitlab.mitre.org/fhir-foundry/'
    script.status = 'draft'

    return script 
  end 

  def build_setup(script, id)
    script.setup = FHIR::TestScript::Setup.new 
    script.setup.action << setup_action(build_setup_operation(id))
    script.setup.action.concat build_asserts(id).map { |assert| setup_action(assert) }
    script.variable << build_var(id) if id == 'search-type'
  end 

  def setup_action(base_action) 
    type = base_action.class.to_s.end_with?('Operation') ? 'operation=' : 'assert='
    action = FHIR::TestScript::Setup::Action.new
    action.send(type, base_action)
    return action
  end 

  def build_setup_operation id 
    operation = FHIR::TestScript::Setup::Action::Operation.new({
      type: FHIR::Coding.new({ code: id, system: 'http://terminology.hl7.org/CodeSystem/testscript-operation-codes' }),
      encodeRequestUrl: false,
      responseId: set_identifier,
      resource: '$RESOURCETYPE' 
    })

    operation.sourceId = '$RESOURCETYPE-example' if id == 'create'
    operation.params = '' if id == 'search-type'
    return operation
  end 

  def build_test(script, id)
    script.test << FHIR::TestScript::Test.new
    script.test.first.action << action(build_operation(id, !script.variable.empty?))
    script.test.first.action.concat build_asserts(id).map { |assert| action(assert) }
  end 

  def action(base_action)
    type = base_action.class.to_s.end_with?('Operation') ? 'operation=' : 'assert='    
    action = FHIR::TestScript::Test::Action.new
    action.send(type, base_action)
    return action
  end 

  def build_operation(id, var)
    operation = FHIR::TestScript::Setup::Action::Operation.new({
      type: FHIR::Coding.new({ code: (id == 'search-type' ? 'search' : id), system: 'http://terminology.hl7.org/CodeSystem/testscript-operation-codes' }),
      encodeRequestUrl: 'false',
      resource: '$RESOURCETYPE'
    })

    operation.sourceId = '$RESOURCETYPE-example' if id == 'create'
    if id == 'search-type'
      operation.params = ' ' 
    else
      var ? operation.url = "/$RESOURCETYPE/${#{identifier}}" : operation.targetId = identifier
    end 

    return operation
  end 

  def build_asserts id 
    if id == 'read' 
      return [FHIR::TestScript::Setup::Action::Assert.new({
        "description": "Confirm that the returned HTTP status is 200(OK).",
        "response": "okay",
        "warningOnly": false
        }),
        FHIR::TestScript::Setup::Action::Assert.new({
          "description": "Confirm that the returned resource type is $RESOURCETYPE.",
          "resource": '$RESOURCETYPE',
          "warningOnly": false
        })
      ] 
    elsif id == 'create'
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
    elsif id == 'update'
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
    elsif id == 'delete'
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
    elsif id == 'search-type' 
      return [FHIR::TestScript::Setup::Action::Assert.new({
        "description": "Confirm that the returned HTTP status is 200(OK).",
        "response": "okay",
        "warningOnly": false
        }),
        FHIR::TestScript::Setup::Action::Assert.new({
          "description": "Confirm that the returned resource type is Bundle.",
          "resource": "Bundle",
          "warningOnly": false
        })
      ] 
    end 
  end 
  
  # Create --> reqs body, returns ID in header
  # Read --> reqs ID, returns ID in 
  # Update --> reqs ID, reqs body, 
  # Search --> returns body
  # Delete --> reqs ID, 

  def set_identifier
    @current_id = SecureRandom.alphanumeric
  end 

  def identifier
    @current_id
  end 

  def build_var(id)
    var = FHIR::TestScript::Variable.new({
      name: 'variable',
      expression: 'Bundle.entry.first.resource.id',
      sourceId: identifier
    })
  end 
end 