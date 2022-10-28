require 'SecureRandom'

class BlueprintBuilder
  # methods = { 'create' => :post,
  #             'read' => :get,
  #             'update' => :put,
  #             'delete' => :delete,
  #             'search-type' => :get }

 def methods(op_code_type)
  return 'search' if op_code_type == 'search-type'
  return op_code_type
 end

  class Workflow
    attr_accessor :variables, :setup, :test, :teardown, :fixtures

    def initialize
      self.test = []
      self.setup = []
      self.teardown = []
      self.variables = []
      self.fixtures = []
    end
  end

  class Operation
    attr_accessor :method, :sourceId, :params, :resource, :responseId

    def initialize(input)
      self.params = input[:params] || nil
      self.method = input[:method] || nil
      self.sourceId = input[:sourceId] || nil
      self.resource = input[:resource] || nil
      self.responseId = input[:responseId] || nil
    end

    def eql?(input)
      return false unless input.class == WorkflowBuilder::Operation
      return false unless self.params == input.params &&
                          self.method == input.method &&
                          self.sourceId == input.sourceId &&
                          self.resource == input.resource &&
                          self.responseId == input.responseId

      return true
    end
  end

  class Assertion
    def initialize(input)
    end
  end

  class InteractionMeta
    attr_accessor :send, :fetch, :modify, :getId, :dynamicReq, :staticReq, :getResource, :expression

    def initialize(input)
      self.send = input[:send] || nil
      self.fetch = input[:fetch] || nil
      self.getId = input[:getId] || nil
      self.modify = input[:modify] || nil
      self.expression = input[:expression] || nil
      self.getResource = input[:getResource] || nil
      self.staticReq = Array(input[:staticReq]) || []
      self.dynamicReq = Array(input[:dynamicReq]) || []
    end
  end

  def interactions_meta
    @interactions_meta ||= {
      'create' => InteractionMeta.new({
        send: true,
        getId: true,
        modify: true,
        staticReq: [:resource],
        expression: '${RESOURCE_TYPE_1}.id'
      }),
      'read' => InteractionMeta.new({
        fetch: true,
        dynamicReq: [:id],
        getResource: true
      }),
      'update' => InteractionMeta.new({
        send: true,
        modify: true,
        dynamicReq: [:id, :resource]
      }),
      'delete' => InteractionMeta.new({
        modify: true,
        dynamicReq: [:id]
      }),
      'search-type' => InteractionMeta.new({
        fetch: true,
        getId: true,
        dynamicReq: [:id],
        getResource: true,
        expression: 'Bundle.entry.resource.id'
      })
    }
  end

  def workflow
    @workflow ||= Workflow.new
  end

  def variables
    @variables ||= {}
  end

  def responseIds
    @responseIds ||= {}
  end

  def build(setup: nil, test:, test_params: nil)
    fresh_workflow

    if setup_required?(test)
      setup_methods = Array(setup || determine_setup_method(test))
      setup_methods.each { |method| build_setup(method) }
    end

    build_test(test, test_params)

    workflow
  end

  def build_setup(setup)
    workflow.setup << Operation.new({
      method: methods(setup),
      params: determine_parameters(setup),
      sourceId: determine_sourceId(setup),
      resource: determine_resource(setup),
      responseId: determine_responseId(setup)
    })

    build_variable(setup)
    build_teardown(setup)
  end

  def fresh_workflow
    @workflow = Workflow.new
    @static_fixture_counter = 0
  end

  def setup_required?(test)
    !interactions_meta[test].dynamicReq.empty?
  end

  def determine_setup_method(test)
    interactions_meta[test].dynamicReq.each_with_object([]) do |req, array|
      method = self.send("get_#{req.to_s}_method")
      array.concat(determine_setup_method(method).concat([method])).uniq!
    end
  end

  def get_id_method
    @get_id_method ||= interactions_meta.find { |_, v| v.getId }.first
  end

  def get_resource_method
    @get_resource_method ||= interactions_meta.find { |_, v| v.getResource }.first
  end

  def determine_parameters(method)
    "/${#{variables[:id]}}" if interactions_meta[method].dynamicReq.include?(:id)
  end

  def determine_sourceId(method)
    if interactions_meta[method].staticReq.include? :resource
      @static_fixture_counter += 1
      workflow.fixtures << "${EXAMPLE_RESOURCE_#{@static_fixture_counter}}"
      workflow.fixtures.last
    elsif interactions_meta[method].dynamicReq.include? :resource
      responseIds[:resource]
    end
  end

  def determine_resource(method)
    return unless interactions_meta[method].dynamicReq.include? :id

    "${RESOURCE_TYPE_#{@static_fixture_counter}}"
  end

  def determine_responseId(method)
    meta = interactions_meta[method]
    return unless meta.getResource || meta.getId

    responseId = fresh_responseId
    responseIds[:id] = responseId if meta.getId
    responseIds[:resource] = responseId if meta.getResource

    responseId
  end

  def fresh_responseId
    SecureRandom.alphanumeric
  end

  def variable_required?(method)
    !!interactions_meta[method].getId
  end

  def build_variable(method)
    return unless variable_required?(method)

    variable = fresh_variable
    workflow.variables << [variable, interactions_meta[method].expression, responseIds[:id]]
    variables[:id] = variable
  end

  def fresh_variable
    SecureRandom.alphanumeric
  end

  def build_teardown(method)
    return unless teardown_required?(method)
    teardown = determine_teardown_method(method)

    workflow_teardown = Operation.new({
      method: methods(teardown),
      params: determine_parameters(teardown),
      sourceId: determine_sourceId(teardown),
      resource: determine_resource(teardown)
    })

    workflow.teardown << workflow_teardown unless workflow.teardown.any? do |teardown|
      teardown.eql? workflow_teardown
    end
  end

  def teardown_required?(method)
    !!interactions_meta[method].modify unless method == 'delete'
  end

  def determine_teardown_method(method)
    'delete' if interactions_meta[method].send
  end

  def build_test(test, params)
    params = params || determine_parameters(test)
    responseId = determine_responseId(test) if interactions_meta[test].modify

    workflow.test << [Operation.new({
      method: methods(test),
      resource: determine_resource(test),
      sourceId: determine_sourceId(test),
      responseId: responseId,
      params: params
    })]

    build_variable(test) if teardown_required?(test)
    build_teardown(test)
  end
end