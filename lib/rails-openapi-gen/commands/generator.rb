# frozen_string_literal: true

require_relative '../core/endpoint_processor'
require_relative '../core/component_aggregator'

module RailsOpenapiGen::Commands
  # Command for generating OpenAPI specifications
  # Orchestrates the generation pipeline without containing business logic
  class Generator
    include RailsOpenapiGen::Logging

    def initialize(
      endpoint_processor: nil,
      routes_parser: nil,
      controller_parser: nil,
      yaml_generator: nil
    )
      @endpoint_processor = endpoint_processor
      @routes_parser = routes_parser
      @controller_parser = controller_parser || Parsers::ControllerParser
      @yaml_generator = yaml_generator || Generators::YamlGenerator
    end

    # Runs the OpenAPI generation process
    # @return [void]
    def run
      # Initialize components
      setup_dependencies

      # Load configuration
      RailsOpenapiGen.configuration.load_from_file

      # Step 1: Parse and filter routes
      routes = @routes_parser.parse

      # Step 2: Get all controller information (including those without templates)
      all_endpoints = @controller_parser.parse_all(routes, filter_missing: false)

      # Step 3: Process each endpoint
      results = process_endpoints(all_endpoints)

      # Step 4: Separate successful and failed results
      successful_results = results.select(&:success?)
      failed_results = results.select(&:failure?)

      # Step 5: Aggregate components from successful results
      all_components = aggregate_components(successful_results)

      # Step 6: Build schemas hash for YAML generation
      schemas = build_schemas_hash(successful_results)

      # Step 7: Generate YAML files
      logger.info("Generating YAML files...", emoji: :file)
      @yaml_generator.new(schemas, components: all_components).generate

      # Step 8: Report summary
      report_summary(successful_results, failed_results, schemas)
    end

    private

    def setup_dependencies
      config = RailsOpenapiGen.configuration

      @endpoint_processor ||= Core::EndpointProcessor.new(
        jbuilder_parser_factory: method(:create_jbuilder_parser),
        ast_to_schema_processor: Processors::AstToSchemaProcessor.new
      )

      @routes_parser ||= Parsers::RoutesParser.new(filter_config: config)
    end

    def process_endpoints(endpoints)
      valid_endpoints = endpoints.select { |ep| ep[:jbuilder_path] }
      skipped_count = endpoints.size - valid_endpoints.size

      if skipped_count > 0
        logger.info("Skipping #{skipped_count} endpoints without Jbuilder templates")
      end

      valid_endpoints.map.with_index do |endpoint_info, index|
        route = endpoint_info[:route]
        progress = "[#{index + 1}/#{valid_endpoints.size}]"
        endpoint_name = "#{route[:method]} #{route[:path]}"

        logger.info("#{progress} Processing endpoint: #{endpoint_name}", emoji: :process)

        # Use the pure functional processor
        result = @endpoint_processor.call(endpoint_info)

        # Log based on result
        if result.success?
          log_success(progress, endpoint_name, result)
        else
          logger.error("#{progress} ❌ ERROR: #{result.error}")
          # Continue processing other endpoints instead of raising
        end

        result
      end
    end

    def log_success(progress, endpoint_name, result)
      schema = result.value[:schema]
      warnings = result.warnings

      # Log warnings if any
      warnings.each { |w| logger.warn("#{progress} ⚠ #{w}") }

      # Log success based on schema content
      if schema && schema["properties"] && !schema["properties"].empty?
        logger.success("#{progress} ✓ Generated schema with #{schema["properties"].size} properties")
      elsif schema && schema["type"]
        logger.success("#{progress} ✓ Generated #{schema["type"]} schema")
      else
        logger.warn("#{progress} Generated empty or invalid schema")
      end
    end

    def aggregate_components(results)
      components_by_result = results.map { |r| r.value[:components] || {} }

      # Simple merge for now, could use ComponentAggregator for more sophisticated handling
      all_components = {}
      components_by_result.each do |components|
        all_components.merge!(components)
      end

      if all_components.any?
        logger.debug("Collected #{all_components.size} component(s)", emoji: :component)
      end

      all_components
    end

    def build_schemas_hash(results)
      schemas = {}

      results.each do |result|
        value = result.value
        route = value[:route]

        schemas[route] = {
          schema: value[:schema],
          parameters: value[:parameters],
          operation: value[:operation]
        }
      end

      schemas
    end

    def report_summary(successful_results, failed_results, schemas)
      total = successful_results.size + failed_results.size
      successful_schemas = schemas.count { |_, data| data[:schema] && !data[:schema].empty? }

      logger.success("OpenAPI specification generated successfully!")
      logger.info("📊 Summary:")
      logger.info("  Processed: #{total} endpoints")
      logger.info("  Successful: #{successful_results.size}")

      if failed_results.any?
        logger.info("  Failed: #{failed_results.size}")
      end

      logger.info("  Valid schemas: #{successful_schemas}")

      # Report total warnings
      total_warnings = successful_results.sum { |r| r.warnings.size }
      if total_warnings > 0
        logger.info("  Total warnings: #{total_warnings}")
      end
    end

    def create_jbuilder_parser(path)
      Parsers::Jbuilder::JbuilderParser.new(path)
    end
  end
end
