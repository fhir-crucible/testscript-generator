require './IG'

igs_directory = ARGV.first || "#{Dir.getwd}/igs"
generator = Generator.new(igs_directory)
generator.generate_scripts
