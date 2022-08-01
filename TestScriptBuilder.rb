require './WorkflowBuilder'

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

		script.setup = create_setup(workflow)
		script.test = create_test(workflow)
		script.teardown = create_teardown(workflow)
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

	def create_setup(workflow)
		return unless workflow.setup

		workflow.setup.each_with_object([]) do |setup, actions|
			actions << create_setup_action(setup)
		end

		FHIR::TestScript::Setup.new(action: actions)
	end

	def create_setup_action(operation)
		create_operation(operation)

		FHIR::TestScript::Setup::Action.new({
			workflow_setup
		})
		[create_operation]
	end

	def create_operation(operation)
		FHIR::TestScript::Setup::Action::Operation.new()
	end

	def create_test(workflow)

	end

	def create_teardown(workflow)

	end
end