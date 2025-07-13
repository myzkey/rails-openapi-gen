# frozen_string_literal: true

require 'active_support/inflector'

module RailsOpenapiGen
  module Parsers
    class RoutesParser
      # Initialize with optional file existence checker for testability
      # @param file_checker [#call] Callable that checks if file exists (defaults to File.exist?)
      def initialize(file_checker: File.method(:exist?))
        @file_checker = file_checker
      end

      # Parses Rails application routes to extract route information
      # @return [Array<Hash>] Array of route hashes with method, path, controller, action, and name
      def parse
        routes = []

        Rails.application.routes.routes.each do |route|
          next unless route.defaults[:controller] && route.defaults[:action]
          next if route.respond_to?(:internal?) ? route.internal? : route.instance_variable_get(:@internal)

          # Skip Rails internal and asset routes
          controller_name = route.defaults[:controller]
          next if controller_name.to_s.start_with?('rails/')
          next if controller_name.to_s == 'assets'

          # Extract HTTP method from route.verb (which can be a Regexp like /^GET$/)
          raw_method = route.verb.is_a?(Array) ? route.verb.first : route.verb
          method = if raw_method.is_a?(Regexp)
                     raw_method.source.gsub(/[\^$()?\-:mix]/, '')
                   else
                     raw_method.to_s
                   end
          # Remove format suffix patterns more robustly
          path = route.path.spec.to_s
                      .gsub(/\(\.:format\)$/, "")              # Standard format pattern
                      .gsub(/\(\.\*format\)$/, "")             # Wildcard format pattern
                      .gsub(/\(\.[\w|*]*\)$/, "") # Complex format patterns like (.json|.xml|.csv)
                      .gsub(/\(\.[^)]*\)$/, "")
          controller = infer_controller_from_route(route)
          action = route.defaults[:action]

          routes << {
            verb: method,           # Test expects 'verb'
            method: method,         # Keep for backward compatibility
            path: path,
            controller: controller,
            action: action,
            name: route.name
          }
        end

        routes
      end

      private

      # Infers the correct controller name from route information
      # Uses route name pattern to identify nested resources
      # @param route [ActionDispatch::Journey::Route] Rails route object
      # @return [String] Controller name
      def infer_controller_from_route(route)
        default_controller = route.defaults[:controller]
        route_name = route.name

        # If route name indicates a nested resource, use it to infer the controller
        if route_name && route_name.include?('_')
          # Parse route name to extract controller path
          # Example: "api_user_orders" -> "api/users/orders"
          parts = route_name.split('_')

          # Remove action suffix if present (index, show, create, etc.)
          action = route.defaults[:action]
          if action && parts.last == action
            parts.pop
          end

          # Convert route name parts to controller path
          if parts.length > 1
            # Check if this looks like a nested resource
            # api_user_orders -> api/users/orders
            # api_post_comments -> api/posts/comments
            potential_nested = parts.map.with_index do |part, index|
              if index == 0 || index == parts.length - 1
                part # Keep namespace and final resource as-is (e.g., "api", "orders")
              else
                # Skip pluralization for version numbers (v1, v2, etc.)
                part.match?(/^v\d+$/) ? part : part.pluralize
              end
            end.join('/')

            # Check if the nested controller file exists
            nested_controller_path = Rails.root.join("app", "controllers", "#{potential_nested}_controller.rb")

            if @file_checker.call(nested_controller_path.to_s)
              return potential_nested
            end
          end
        end

        # Fall back to default controller name
        default_controller
      end
    end
  end
end
