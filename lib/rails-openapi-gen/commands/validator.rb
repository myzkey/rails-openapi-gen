# frozen_string_literal: true

module RailsOpenapiGen
  module Commands
    # Command for validating missing comments and uncommitted changes
    class Validator
      include RailsOpenapiGen::Logging

      # Validates OpenAPI comments and uncommitted changes
      # @return [void]
      def run
        logger.info("Validating OpenAPI comments and uncommitted changes...", emoji: :debug)

        # Run OpenAPI generation to check for missing comments
        system('bin/rails openapi:generate') || system('bundle exec rails openapi:generate')

        # Check for uncommitted changes in openapi directory
        if system('git diff --quiet docs/api/ 2>/dev/null')
          logger.success("All checks passed!")
        else
          logger.error("Found uncommitted changes in OpenAPI files")
          logger.error(`git diff docs/api/`)
          exit 1
        end
      end
    end
  end
end