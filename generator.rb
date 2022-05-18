# TODO: Naming and organization clean-up
require 'zlib'
require 'zip'
require 'package'
require 'json'
require 'crack'
require 'fhir_models'
require 'pry-nav'
require 'SecureRandom'
require_relative './IGExtractor'
require_relative './TestScriptWorkflow'
require_relative './TestScriptGenerator'

class Generator
  include IGExtractor

  MAPPING = {
    'read' => 'read',
    'create' => 'create',
    'delete' => 'delete',
    'search-type' => 'search'
  }

  def igs 
    @igs ||= load_igs
  end 

  def interactions_map
    @interactions_map ||= map_interactions
  end 

  def root
    @root ||= "./testscripts/generated"
  end 

  def title *new_title
    @title = "#{new_title[0].split('-').each(&:upcase!).join(' ')} #{new_title[1].scan(/[A-Z][a-z]+/).join(' ')} #{new_title[2].capitalize} TestScript" unless new_title.empty?
    return @title
  end 

  def map_interactions
    igs.each_with_object({}) do |ig, igs_map|
      resources = ig.capability_statement&.resource
      return unless resources

      igs_map[ig.name] = resources.each_with_object({}) do |resource, resource_map|
        resource_map[resource.type] = resource.interaction.each_with_object({}) do |interaction, interaction_map|
          interaction_map[interaction.code] = interaction.extension[0]&.valueCode
        end
      end 
    end
  end 

  def generate_scripts
    interactions_map.each do |ig_name, interactions|
      FHIR.logger.info "Generating TestScripts from #{ig_name} IG ...\n"

      script_generator = TestScriptGenerator.new(ig_name, interactions)
      script_generator.conformance_generation

      FHIR.logger.info "... finished generating TestScripts from #{ig_name} IG.\n"
    end 
  end 

  def script_boilerplate action
    return {
      url: 'https://gitlab.mitre.org/fhir-foundry/',
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