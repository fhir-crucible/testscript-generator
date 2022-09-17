#!/usr/bin/env ruby
require 'pry-nav'
require_relative '../lib/testscript_generator'

ig_directory = Dir.getwd + '/igs'
output_path = Dir.getwd + '/generated_testscripts'

parameters = ARGV
unless parameters.empty?
	ig_directory = parameters[0]
	output_path = paramsers[1] if parameters[1]
end

generator = TestScriptGenerator.new(ig_directory, output_path)
generator.generate_interaction_conformance