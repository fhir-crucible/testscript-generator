require './generator'

generator = Generator.new
generator.generate_scripts 'create'
generator.generate_scripts 'read'
generator.generate_scripts 'update'
generator.generate_scripts 'delete'