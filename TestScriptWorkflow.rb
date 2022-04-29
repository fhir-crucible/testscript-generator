# TODO: Is DEPENDENCIES necessary? Is it really giving any information
#       that a computer couldn't determine? I.e. if you're either fetching 
#       or sending. 
#           --> If you're fetching, you need to know something exists to 
#               fetch. This can be done by sending the thing or fetching 
#               randomly and cherry-picking.
#           --> If you're sending, you need to fetch to confirm that the
#               the sending worked properly.  
class TestScriptWorkflow
  Workflow = Struct.new(:setup, :execution, :teardown)

  SENDER = []
  FETCHER = ['read']
  CONFORMANCE = ['SHALL', 'SHOULD', 'MAY']
  DEPENDENCIES = {
    "read" => [['search-type']],
    "create" => [['delete']],
    "update" => [['create']],
    "delete" => [['read']]
  }

  attr_accessor :expectations

  def self.build(interaction, expectations)
    new(expectations).build interaction
  end

  def initialize(expectations)
    self.expectations = expectations
  end 

  # Checks conformance in descending order. Maintains array of supported actions,
  # meaning if no SHALL workflow exists, those SHALL actions can be used to string
  # together a SHOULD workflow
  def build interaction
    supported = []
    CONFORMANCE.each do |verb|
      supported |= expectations.filter_map { |key, value| key if value == verb }
      dependence = DEPENDENCIES[interaction].find { |dependence| (dependence - supported).empty? } 

      next unless dependence
      return design_workflow(dependence)
    end 
  end

  # TODO: Create this. 
  # Notes: I don't want to write this out. I want the STRUCTURE of the DEPENDENCIES constant to basically inform this
  # anyways. 
  # PROBLEM: Hashing by dependency type, which is a problem because you can have multiple 'methods' that use the same
  #           dependency type 
  def design_workflow dependence
    case dependence
    when ['search-type']
      return { 
        setup: [{
          method: 'search-type', 
          expected: 'bundle',
          need: 'id'
        }],
        execution: [{
          method: 'read',
        }], 
        teardown: nil 
      }
    when ['delete']
      return {
        setup: [{
          method: 'delete',
          expected: '',
          need: 'id'
        }],
        execution: [{
          method: 'create'
        }],
        teardown: nil
      }
    when ['read']
      return {
        setup: [{
          method: 'read',
          exepected: '',
          need: 'id'
        }],
        execution: [{
          method: 'delete'
        }],
        teardown: nil
      }
    when ['create']
      return {
        setup: [{
          method: 'create',
          exepected: '',
          need: ['id', 'resource']
        }],
        execution: [{
          method: 'update'
        }],
        teardown: nil
      }
    end     
  end 
end 