# frozen_string_literal: true

namespace :openapi do
  desc "Import OpenAPI specification and add @openapi comments to Jbuilder files"
  task :import, [:openapi_file] => :environment do |_task, args|
    openapi_file = args[:openapi_file]

    # Set debug mode if verbose flag is passed
    ENV['DEBUG_OPENAPI_IMPORT'] = '1' if ENV['VERBOSE'] == 'true'

    RailsOpenapiGen.import(openapi_file)
  end

  desc "Diagnose import issues by comparing OpenAPI paths with Rails routes"
  task :diagnose_import, [:openapi_file] => :environment do |_task, args|
    openapi_file = args[:openapi_file] || File.join(RailsOpenapiGen.configuration.output_directory,
                                                    RailsOpenapiGen.configuration.output_filename)

    unless File.exist?(openapi_file)
      puts "❌ OpenAPI file not found: #{openapi_file}"
      exit 1
    end

    puts "🔍 Diagnosing OpenAPI import for: #{openapi_file}"
    puts ""

    # Load OpenAPI spec
    openapi_spec = YAML.load_file(openapi_file)
    openapi_paths = openapi_spec['paths'] || {}

    # Get Rails routes
    routes_parser = RailsOpenapiGen::Parsers::RoutesParser.new
    rails_routes = routes_parser.parse

    # NOTE: routes_by_path grouping removed as it's not used in current implementation

    puts "📊 Summary:"
    puts "   OpenAPI paths: #{openapi_paths.size}"
    puts "   Rails routes: #{rails_routes.size}"
    puts ""

    # Check each OpenAPI path
    unmatched_paths = []
    matched_paths = []

    openapi_paths.each do |path, methods|
      methods.each do |method, _operation|
        next if method == 'parameters'

        # Convert OpenAPI path to Rails format
        rails_path = path.gsub(/\{(\w+)\}/, ':\1')

        # Try to find matching route
        matching_routes = rails_routes.select do |route|
          route[:method] == method.upcase &&
            route[:path].gsub(%r{/$}, '') == rails_path.gsub(%r{/$}, '')
        end

        if matching_routes.empty?
          unmatched_paths << { path: path, method: method.upcase, rails_path: rails_path }
        else
          matched_paths << { path: path, method: method.upcase, route: matching_routes.first }
        end
      end
    end

    # Report results
    if matched_paths.any?
      puts "✅ Matched paths (#{matched_paths.size}):"
      matched_paths.each do |match|
        route = match[:route]
        controller_path = route[:controller].gsub('/', '::').camelize + "Controller"
        action = route[:action]
        puts "   #{match[:method]} #{match[:path]} → #{controller_path}##{action}"
      end
      puts ""
    end

    if unmatched_paths.any?
      puts "❌ Unmatched OpenAPI paths (#{unmatched_paths.size}):"
      unmatched_paths.each do |unmatched|
        puts "   #{unmatched[:method]} #{unmatched[:path]}"

        # Suggest similar routes
        similar_routes = rails_routes.select do |route|
          route[:method] == unmatched[:method] &&
            route[:path].include?(unmatched[:rails_path].split('/').reject(&:empty?).first.to_s)
        end

        next unless similar_routes.any?

        puts "     Did you mean one of these?"
        similar_routes.take(3).each do |route|
          puts "       - #{route[:path]}"
        end
      end
      puts ""
    end

    # Check for Jbuilder templates
    puts "📄 Checking Jbuilder templates:"
    matched_paths.each do |match|
      route = match[:route]
      controller_parser = RailsOpenapiGen::Parsers::ControllerParser.new(route)
      controller_info = controller_parser.parse

      if controller_info[:jbuilder_path]
        if File.exist?(controller_info[:jbuilder_path])
          puts "   ✅ #{match[:method]} #{match[:path]} → #{controller_info[:jbuilder_path]}"
        else
          puts "   ❌ #{match[:method]} #{match[:path]} → #{controller_info[:jbuilder_path]} (file not found)"
        end
      else
        puts "   ⚠️  #{match[:method]} #{match[:path]} → No Jbuilder template found"
      end
    end

    puts ""
    puts "💡 Tips:"
    puts "   - Ensure your OpenAPI paths match your Rails routes exactly"
    puts "   - Use {id} in OpenAPI for :id in Rails routes"
    puts "   - Create Jbuilder templates for API endpoints that need them"
    puts "   - Run 'DEBUG_OPENAPI_IMPORT=1 rake openapi:import[#{openapi_file}]' for detailed import logs"
  end
end
