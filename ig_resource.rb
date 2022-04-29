class IGResource
  attr_accessor :name

  def initialize name
    self.name = name
  end 

  def add resource
    resources[resource.resourceType] = resource
  end 

  def get resource_name
    return resources[resource_name]
  end 

  # Only care about server implementations
  def capability_statement 
    return @capabality_statement ||= resources['CapabilityStatement']&.rest&.first { |r| r.mode == 'server' }
  end

  private 

  def resources
    @resources ||= Hash.new { |h, k| h[k] = nil }
  end
end 