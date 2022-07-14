# frozen_string_literal: true

# TODO: Naming and organization clean-up
require 'zlib'
require 'zip'
require 'json'
require 'crack'
require 'fhir_models'
require 'pry-nav'
require 'SecureRandom'
require_relative './IG'
require_relative './TestScriptWorkflow'
require_relative './TestScriptGenerator'

class Generator
  attr_accessor :igs_directory

  MAPPING = {
    'read' => 'read',
    'create' => 'create',
    'delete' => 'delete',
    'search-type' => 'search'
  }.freeze

  def initialize(path)
    self.igs_directory = path
  end

  def igs
    @igs ||= Dir.glob("#{igs_directory}/*").each_with_object({}) do |package, store|
      ig = IG.new(package)
      store[ig.name] = ig
    end
  end

  def root
    @root ||= './testscripts/generated'
  end

  def title(*new_title)
    unless new_title.empty?
      @title = "#{new_title[0].split('-').each(&:upcase!).join(' ')} #{new_title[1].scan(/[A-Z][a-z]+/).join(' ')} #{new_title[2].capitalize} TestScript"
    end
    @title
  end

  def generate_scripts
    igs.each do |name, ig|
      FHIR.logger.info "Generating TestScripts from #{name} IG ...\n"

      script_generator = TestScriptGenerator.new(name, ig.interactions)
      script_generator.conformance_generation

      FHIR.logger.info "... finished generating TestScripts from #{name} IG.\n"
    end
  end

  def script_boilerplate(_action)
    {
      url: 'https://github.com/fhir-crucible/testscript-generator',
      version: '0.0',
      id: @title.split(' ').each(&:downcase!).join('-'),
      name: @title,
      status: 'draft',
      experimental: true,
      date: DateTime.now.to_s,
      publisher: 'The MITRE Corporation'
    }
  end
end
