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
          controller = route.defaults[:controller]
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
    end
  end
end