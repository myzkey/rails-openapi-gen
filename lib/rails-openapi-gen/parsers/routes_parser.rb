# frozen_string_literal: true

module RailsOpenapiGen
  module Parsers
    class RoutesParser
      # Parses Rails application routes to extract route information
      # @return [Array<Hash>] Array of route hashes with method, path, controller, action, and name
      def parse
        routes = []
        
        Rails.application.routes.routes.each do |route|
          next unless route.defaults[:controller] && route.defaults[:action]
          next if route.respond_to?(:internal?) ? route.internal? : route.instance_variable_get(:@internal)
          
          method = route.verb.is_a?(Array) ? route.verb.first : route.verb
          path = route.path.spec.to_s.gsub(/\(\.:format\)$/, "")
          controller = infer_controller_from_route(route)
          action = route.defaults[:action]
          
          routes << {
            method: method,
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
              if index == 0
                part  # Keep namespace as-is (e.g., "api")
              elsif index < parts.length - 1
                # Simple pluralization for common cases
                part.end_with?('y') ? part[0..-2] + 'ies' : part + 's'
              else
                part  # Keep final resource as-is (e.g., "orders")
              end
            end.join('/')
            
            # Check if the nested controller file exists
            nested_controller_path = Rails.root.join("app", "controllers", "#{potential_nested}_controller.rb")
            
            if File.exist?(nested_controller_path.to_s)
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