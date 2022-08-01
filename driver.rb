require './generator'
require './TestScriptBuilder'

scriptBuilder = TestScriptBuilder.new
builder = WorkflowBuilder.new

flow = builder.build(test: 'create')
script = scriptBuilder.build(flow)

# generator = Generator.new
# generator.generate_scripts