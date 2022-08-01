require './WorkflowBuilder.rb'

describe WorkflowBuilder do
  before(:all) do
    @operation = WorkflowBuilder::Operation.new({})
  end

  describe 'Operation class' do
    describe 'eql? method' do
      context 'given non-Operation' do
        it 'returns false' do
          result = @operation.eql?(nil)
          expect(result).to be(false)
        end
      end

      context 'given Operation' do
        it '' do
        end
      end
    end
  end
end