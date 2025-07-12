require 'spec_helper'

RSpec.describe "Array with Partial Processing" do
  # Skip tests that require actual file parsing due to Parser version compatibility issues
  before(:all) do
    if RUBY_VERSION < '3.1.7'
      skip "Skipping array partial tests due to Parser gem version compatibility issues"
    end
  end
  let(:main_jbuilder_content) do
    <<~JBUILDER
      # @openapi professional_experiences:array items:object
      json.array! @experiences do |experience|
        json.partial! partial: 'test/professional_experience',
                      locals: { professional_experience: experience }
      end
    JBUILDER
  end

  let(:partial_content) do
    <<~JBUILDER
      # @openapi id:integer description:"Experience ID"
      json.id professional_experience.id

      # @openapi company_name:string description:"Company name"
      json.company_name professional_experience.company_name

      # @openapi position:string description:"Position title"
      json.position professional_experience.position

      # @openapi end_date:string required:false description:"End date"
      json.end_date professional_experience.end_date
    JBUILDER
  end

  it "processes partials in json.array! blocks correctly" do
    main_file = 'test_array_partial.json.jbuilder'
    partial_file = 'test/_professional_experience.json.jbuilder'
    
    # Create directory and files
    Dir.mkdir('test') unless Dir.exist?('test')
    File.write(main_file, main_jbuilder_content)
    File.write(partial_file, partial_content)
    
    begin
      parser = RailsOpenapiGen::Parsers::Jbuilder::JbuilderParser.new(main_file)
      result = parser.parse
      
      # The result should be an ArrayNode for root arrays
      expect(result).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      expect(result.property_name).to eq('items')  # Root arrays get "items" as property name
      expect(result.is_root_array).to be true
      
      # Should have children (array items)
      expect(result.children).not_to be_empty
      array_item_object = result.children.first
      expect(array_item_object).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
      
      # Should have item properties from the partial
      item_properties = array_item_object.children
      property_names = item_properties.map { |p| p.property_name }
      expect(property_names).to include('id', 'company_name', 'position', 'end_date')
      
      # Generate schema using AST-to-schema processor
      processor = RailsOpenapiGen::Processors::AstToSchemaProcessor.new
      schema = processor.process_to_schema(result)
      
      # Root array should be represented directly
      expect(schema['type']).to eq('array')
      expect(schema['items']['type']).to eq('object')
      
      # Should have all the expected properties in the array items
      item_schema_properties = schema['items']['properties']
      expect(item_schema_properties).to have_key('id')
      expect(item_schema_properties).to have_key('company_name')
      expect(item_schema_properties).to have_key('position')
      expect(item_schema_properties).to have_key('end_date')
      
      # Check required fields (new default behavior)
      required_fields = schema['items']['required']
      expect(required_fields).to include('id', 'company_name', 'position')
      expect(required_fields).not_to include('end_date')  # marked as required:false
      
    ensure
      File.delete(main_file) if File.exist?(main_file)
      File.delete(partial_file) if File.exist?(partial_file)
      Dir.rmdir('test') if Dir.exist?('test') && Dir.empty?('test')
    end
  end
end