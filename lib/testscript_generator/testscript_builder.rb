require_relative 'workflow_builder'

class TestScriptBuilder
	def scripts
		@scripts ||= {}
	end

	def build(workflow)
		script = scripts[workflow]
		return script if script

		script = build_from_workflow(workflow)
		scripts[workflow] = script

		script
	end

	def build_from_workflow(workflow)
		script = FHIR::TestScript.new
		script.variable = create_variables(workflow)

		script.setup = build_setup(workflow)
		script.test = build_test(workflow)
		script.teardown = build_teardown(workflow)

		script
	end

	def create_variables(workflow)
		workflow.variables.map do |var|
			input = { name: var[0], sourceId: var[2] }

			if !var[1].start_with?('$HEADER_')
				input.merge!({ path: var[1] })
			else
				var[1].slice!("$HEADER_")
				input.merge!({ headerField: var[1] })
			end

			FHIR::TestScript::Variable.new(input)
		end
	end

	def build_setup(workflow)
		return unless !workflow.setup.empty?

		actions = workflow.setup.map do |action|
			if action.class == WorkflowBuilder::Operation
				FHIR::TestScript::Setup::Action.new(operation: build_operation(action))
			else
				FHIR::TestScript::Setup::Action.new(assert: build_assert(action))
			end
		end

		FHIR::TestScript::Setup.new({action: actions})
	end

	def build_operation(operation)
		FHIR::TestScript::Setup::Action::Operation.new({
			params: operation.params,
			method: operation.method,
			sourceId: operation.sourceId,
			resource: operation.resource,
			responseId: operation.responseId,
			encodeRequestUrl: false
		})
	end

	def build_assert(assertion)
		FHIR::TestScript::Setup::Action::Assert.new()
	end

	def build_test(workflow)
		return unless workflow.test

		workflow.test.map do |test|
			actions = test.map do |action|
				if action.class == WorkflowBuilder::Operation
					FHIR::TestScript::Test::Action.new(operation: build_operation(action))
				else
					FHIR::TestScript::Test::Action.new(assert: build_assert(action))
				end
			end

			FHIR::TestScript::Test.new(action: actions)
		end
	end

	def build_teardown(workflow)
		return unless workflow.teardown

		actions = workflow.teardown.map do |action|
			FHIR::TestScript::Teardown::Action.new(operation: build_operation(action))
		end

		FHIR::TestScript::Teardown.new(action: actions)
	end
end