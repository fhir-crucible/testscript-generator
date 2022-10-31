require_relative 'blueprint_builder'

class TestScriptBuilder
	def scripts
		@scripts ||= {}
	end

	def operation_counter
		@operation_counter ||= 0
		@operation_counter += 1
	end

	def assert_counter
		@assert_counter ||= 0
		@assert_counter += 1
	end

	def test_counter
		@test_counter ||= 0
		@test_counter += 1
	end

	def build(blueprint)
		script = scripts[blueprint]
		return script if script

		script = build_from_blueprint(blueprint)
		scripts[blueprint] = script

		script
	end

	def build_from_blueprint(blueprint)
		@test_counter = nil
		@assert_counter = nil
		@operation_counter = nil

		script = FHIR::TestScript.new
		script.variable = create_variables(blueprint)
		script.fixture = create_fixtures(blueprint)

		script.setup = build_setup(blueprint)
		script.test = build_test(blueprint)
		script.teardown = build_teardown(blueprint)

		script
	end

	def create_variables(blueprint)
		blueprint.variables.map do |var|
			input = { name: var[0], sourceId: var[2] }

			if !var[1].start_with?('$HEADER_')
				input.merge!({ expression: var[1] })
			else
				var[1].slice!("$HEADER_")
				input.merge!({ headerField: var[1] })
			end

			FHIR::TestScript::Variable.new(input)
		end
	end

	def create_fixtures(blueprint)
		blueprint.fixtures.map do |fixture|
			reference = FHIR::Reference.new(reference: "fixtures/#{fixture}_reference")
			FHIR::TestScript::Fixture.new(id: fixture, resource: reference, autocreate: false, autodelete: false)
		end
	end

	def build_setup(blueprint)
		return unless !blueprint.setup.empty?

		actions = blueprint.setup.map do |action|
			if action.class == BlueprintBuilder::Operation
				FHIR::TestScript::Setup::Action.new(operation: build_operation(action))
			else
				FHIR::TestScript::Setup::Action.new(assert: build_assert(action))
			end
		end

		FHIR::TestScript::Setup.new({action: actions})
	end

	def build_operation(operation)
		FHIR::TestScript::Setup::Action::Operation.new({
			label: "Operation_#{operation_counter}",
			params: operation.params,
			#method: operation.method,
			type: FHIR::Coding.new(system: "http://terminology.hl7.org/CodeSystem/testscript-operation-codes", code: operation.method),
			sourceId: operation.sourceId,
			resource: operation.resource,
			responseId: operation.responseId,
			encodeRequestUrl: false
		})
	end

	def build_assert(assertion)
		FHIR::TestScript::Setup::Action::Assert.new(label: "Assert_#{assert_counter}")
	end

	def build_test(blueprint)
		return unless blueprint.test

		blueprint.test.map do |test|
			actions = test.map do |action|
				if action.class == BlueprintBuilder::Operation
					FHIR::TestScript::Test::Action.new(operation: build_operation(action))
				else
					FHIR::TestScript::Test::Action.new(assert: build_assert(action))
				end
			end

			FHIR::TestScript::Test.new(name: "Test_#{test_counter}", action: actions)
		end
	end

	def build_teardown(blueprint)
		return unless blueprint.teardown

		actions = blueprint.teardown.map do |action|
			FHIR::TestScript::Teardown::Action.new(operation: build_operation(action))
		end

		FHIR::TestScript::Teardown.new(action: actions)
	end
end