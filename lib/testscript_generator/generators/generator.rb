require_relative 'blueprint_builder'

class Generator
  def blueprinter
    @blueprinter ||= BlueprintBuilder.new
  end
end