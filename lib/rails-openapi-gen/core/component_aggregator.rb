# frozen_string_literal: true

module RailsOpenapiGen
  module Core
    # Pure functional aggregator for collecting and normalizing components
    class ComponentAggregator
      # Aggregate components from multiple results
      # @param results [Array<SchemaGenerationResult>] Array of endpoint processing results
      # @return [Hash] Merged and normalized components
      def self.aggregate(results)
        new.aggregate(results)
      end

      def aggregate(results)
        all_components = {}
        duplicates = {}

        results.each do |result|
          next if result.failure?

          components = result.value[:components] || {}
          components.each do |name, schema|
            normalized_name = normalize_component_name(name)

            if all_components.key?(normalized_name)
              # Track duplicates for reporting
              duplicates[normalized_name] ||= []
              duplicates[normalized_name] << name unless duplicates[normalized_name].include?(name)
            else
              all_components[normalized_name] = schema
            end
          end
        end

        report_duplicates(duplicates) if duplicates.any?

        all_components
      end

      private

      def normalize_component_name(name)
        # Convert to PascalCase and ensure consistency
        name.to_s
            .split(/[_\-\s]/)
            .map { |part| part.capitalize }
            .join
      end

      def report_duplicates(duplicates)
        # In a pure functional approach, we return this info
        # The caller can decide whether to log it
        {
          duplicates: duplicates.map do |normalized, originals|
            {
              normalized_name: normalized,
              original_names: originals
            }
          end
        }
      end
    end
  end
end