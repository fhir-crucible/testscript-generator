class IG
  attr_accessor :name

  def initialize(ig_package)
    load_from_package(ig_package)
  end 

  def capability_statements
    @capability_statements ||= []
  end 

  def capability_statement(statement = nil)
    @capability_statement = statement if statement
    @capability_statement ||= begin 
      capability_statements.find { |cs| cs.rest.first.mode == 'server' }
    end 
  end 

  def implementation_guide
    @implementation_guide
  end 

  def operation_defs
    @operation_defs ||= []
  end 

  def structure_defs 
    @structure_defs ||= Hash.new { |h, k| h[k] = [] } 
  end 

  def search_params
    @search_params ||= Hash.new { |h, k| h[k] = [] } 
  end 

  def code_systems
    @code_systems ||= []
  end 

  def value_sets
    @value_sets ||= []
  end 

  def examples 
    @examples ||= Hash.new { |h, k| h[k] = [] } 
  end 

  def name
    @name
  end 

  def extract_name(name)
    @name = name.split('/').last.split('.').first.gsub('-package', '')
  end 

  def load_from_package(package)
    FHIR.logger.info "Loading Implementation Guide from #{package} ..."
    FHIR.logger = Logger.new('/dev/null')

    extract_name(package)
    package.split('.').last == 'tgz' ? load_tgz(package) : load_zip(package)

    FHIR.logger = Logger.new(STDOUT)
    FHIR.logger.info "... finished loading IG.\n"
  end 

  def load_tgz(package)
    Zlib::GzipReader.wrap(File.open(package)) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each do |entry|
          next unless entry.file? and entry.header.name.end_with?('json', 'xml') 

          ( store_resource(FHIR.from_contents(entry.read)) ) rescue {}
        end 
      end 
    end 
  end 

  def load_zip(package)
    Zip::File.open(package) do |unzipped|
      unzipped.entries.each do |entry|
        next unless entry.file? and entry.name.end_with?('json', 'xml')

        ( store_resource(FHIR.from_contents(entry.get_input_stream.read)) ) rescue {}
      end 
    end
  end 

  def store_resource(resource)
    return unless resource

    case resource.resourceType
    when 'CapabilityStatement'
      capability_statements << resource
    when 'ImplementationGuide'
      @implementation_guide = resource
    when 'OperationDefinition'
      operation_defs << resource
    when 'StructureDefinition'
      structure_defs[resource.type] << resource
    when 'SearchParameter'
      resource.base.each { |type| search_params[type] << resource }
    when 'CodeSystem'
      code_systems << resource
    when 'ValueSet'
      value_sets << resource
    when 'Bundle'
      return
    else
      examples[resource.resourceType] << resource
    end 
  end 
end 