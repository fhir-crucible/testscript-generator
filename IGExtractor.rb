require_relative './IGResource'
require 'pry-nav'
require 'rubygems/package'

module IGExtractor
  def load_igs 
    FHIR.logger = Logger.new('/dev/null')
    igs = Dir.glob("#{Dir.getwd}/igs/*").map do |package|
      case package.split('.').last
      when 'zip'
        load_zipped_ig package
      when 'tgz'
        load_tgzed_ig package
      end 
    end 
    FHIR.logger = Logger.new(STDOUT)
    return igs
  end 

  def load_zipped_ig package
    ig = IGResource.new clean_name(package)
    Zip::File.open(package) do |unzipped|
      unzipped.entries.each do |entry|
        next unless entry.file?
        next unless (entry.name.end_with? 'json') || (entry.name.end_with? 'xml')
        begin
          resource = FHIR.from_contents(entry.get_input_stream.read)
        rescue => e
          next
        end 
        ig.add(resource) unless resource.nil?
      end 
    end
    return ig
  end 

  def load_tgzed_ig package
    ig = IGResource.new clean_name(package)
    Zlib::GzipReader.wrap(File.open(package)) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each do |entry|
          next unless entry.file?
          next unless (entry.header.name.end_with? 'json') || (entry.header.name.end_with? 'xml')
          begin
            resource = FHIR.from_contents(entry.read)
          rescue
            next
          end 
          ig.add(resource) unless resource.nil?
        end 
      end 
    end 
    return ig
  end 

  def clean_name name
    name.split('/').last.split('.').first.gsub('-package', '')
  end 
end 