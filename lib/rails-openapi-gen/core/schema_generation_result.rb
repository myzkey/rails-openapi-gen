# frozen_string_literal: true

module RailsOpenapiGen::Core
  # Result type for handling schema generation success/failure without exceptions
  # Inspired by functional programming Result/Either types
  class SchemaGenerationResult
    attr_reader :value, :error, :warnings

    def self.success(value, warnings: [])
      new(success: true, value: value, warnings: warnings)
    end

    def self.failure(error, warnings: [])
      new(success: false, error: error, warnings: warnings)
    end

    def initialize(success:, value: nil, error: nil, warnings: [])
      @success = success
      @value = value
      @error = error
      @warnings = Array(warnings)
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    # Monadic bind - chain operations that return Results
    def then
      return self if failure?

      result = yield(value)
      # Accumulate warnings
      if result.is_a?(SchemaGenerationResult)
        SchemaGenerationResult.new(
          success: result.success?,
          value: result.value,
          error: result.error,
          warnings: warnings + result.warnings
        )
      else
        SchemaGenerationResult.success(result, warnings: warnings)
      end
    end

    # Map over the value if successful
    def map
      return self if failure?

      SchemaGenerationResult.success(yield(value), warnings: warnings)
    end

    # Add a warning to the result
    def add_warning(warning)
      @warnings << warning
      self
    end

    # Convert to hash for serialization
    def to_h
      {
        success: @success,
        value: @value,
        error: @error,
        warnings: @warnings
      }
    end
  end
end
