require 'spec_helper'

RSpec.describe "Array with Partial Processing" do
  let(:main_jbuilder_content) do
    <<~JBUILDER
      json.professional_experiences do
        json.array! @experiences do |experience|
          json.partial! partial: 'test/professional_experience',
                        locals: { professional_experience: experience }
        end
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
      
      # Should have one property: professional_experiences
      expect(result[:properties].length).to eq(1)
      
      exp_property = result[:properties].first
      expect(exp_property.property).to eq('professional_experiences')
      expect(exp_property).to be_a(RailsOpenapiGen::AstNodes::ArrayPropertyNode)
      expect(exp_property.array_item_properties).not_to be_nil
      
      # Should have item properties from the partial
      item_properties = exp_property.array_item_properties
      property_names = item_properties.map { |p| p.property }
      expect(property_names).to include('id', 'company_name', 'position', 'end_date')
      
      # Generate schema to verify structure
      generator = RailsOpenapiGen::Generator.new
      schema = generator.send(:build_schema, result[:properties])
      
      # professional_experiences should be a direct array
      expect(schema['properties']['professional_experiences']['type']).to eq('array')
      expect(schema['properties']['professional_experiences']['items']['type']).to eq('object')
      
      # Should have all the expected properties in the array items
      item_properties = schema['properties']['professional_experiences']['items']['properties']
      expect(item_properties).to have_key('id')
      expect(item_properties).to have_key('company_name')
      expect(item_properties).to have_key('position')
      expect(item_properties).to have_key('end_date')
      
      # Check required fields (new default behavior)
      required_fields = schema['properties']['professional_experiences']['items']['required']
      expect(required_fields).to include('id', 'company_name', 'position')
      expect(required_fields).not_to include('end_date')  # marked as required:false
      
    ensure
      File.delete(main_file) if File.exist?(main_file)
      File.delete(partial_file) if File.exist?(partial_file)
      Dir.rmdir('test') if Dir.exist?('test') && Dir.empty?('test')
    end
  end
end