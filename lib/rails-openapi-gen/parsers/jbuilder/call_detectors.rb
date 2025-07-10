# frozen_string_literal: true

module RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
  autoload :BaseDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/base_detector"
  autoload :JsonCallDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/json_call_detector"
  autoload :ArrayCallDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/array_call_detector"
  autoload :PartialCallDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/partial_call_detector"
  autoload :CacheCallDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/cache_call_detector"
  autoload :KeyFormatDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/key_format_detector"
  autoload :NullHandlingDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/null_handling_detector"
  autoload :ObjectManipulationDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/object_manipulation_detector"

  # Registry for managing all call detectors
  class DetectorRegistry
    class << self
      # Get all available detectors sorted by priority
      # @return [Array<Class>] Detector classes sorted by priority (high to low)
      def all_detectors
        @all_detectors ||= [
          ArrayCallDetector,
          PartialCallDetector,
          JsonCallDetector,
          CacheCallDetector,
          KeyFormatDetector,
          NullHandlingDetector,
          ObjectManipulationDetector
        ].sort_by { |detector| -detector.priority }
      end

      # Find the appropriate detector for a method call
      # @param receiver [Parser::AST::Node, nil] Method receiver
      # @param method_name [Symbol] Method name
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Class, nil] Appropriate detector class or nil
      def find_detector(receiver, method_name, args = [])
        all_detectors.find do |detector|
          detector.handles?(receiver, method_name, args)
        end
      end

      # Get detectors by category
      # @param category [Symbol] Detector category
      # @return [Array<Class>] Detectors in the category
      def by_category(category)
        all_detectors.select { |detector| detector.category == category }
      end

      # Get all available categories
      # @return [Array<Symbol>] Available categories
      def categories
        all_detectors.map(&:category).uniq
      end

      # Add a custom detector to the registry
      # @param detector_class [Class] Detector class to add
      # @return [void]
      def register(detector_class)
        return unless detector_class < BaseDetector
        
        @all_detectors = nil # Reset cache
        all_detectors << detector_class unless all_detectors.include?(detector_class)
        @all_detectors = all_detectors.sort_by { |detector| -detector.priority }
      end

      # Remove a detector from the registry
      # @param detector_class [Class] Detector class to remove
      # @return [void]
      def unregister(detector_class)
        @all_detectors = nil # Reset cache
        all_detectors.delete(detector_class)
      end

      # Check if a method call is handled by any detector
      # @param receiver [Parser::AST::Node, nil] Method receiver
      # @param method_name [Symbol] Method name
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if any detector handles the call
      def handles?(receiver, method_name, args = [])
        !find_detector(receiver, method_name, args).nil?
      end
    end
  end
end
