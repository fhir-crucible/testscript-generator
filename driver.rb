require './generator'
# <<<<<<< HEAD
# require './TestScriptBuilder'

# scriptBuilder = TestScriptBuilder.new
# builder = WorkflowBuilder.new

# flow = builder.build(test: 'create')
# script = scriptBuilder.build(flow)

# # generator = Generator.new
# # generator.generate_scripts
# =======
require './IG'

igs_directory = ARGV.first || "#{Dir.getwd}/igs"
generator = Generator.new(igs_directory)
generator.generate_scripts
