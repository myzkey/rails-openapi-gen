# Changelog

All notable changes to this project will be documented in this file.

## [0.0.4] - 2025-01-13

### Fixed
- Fixed format field handling in OpenAPI schema generation
- Improved AST to schema processor to correctly use format_value method
- Enhanced date-time type conversion to properly generate format fields

### Changed
- Parser gem fallback system for better Ruby 3.1 compatibility
- Improved error handling for Parser gem version mismatches

## [0.0.3] - 2025-01-13

### Added
- Ruby 3.1 compatibility with intelligent fallback parsing system
- Robust error handling for Parser gem version mismatches
- Support for root array structures in Jbuilder templates
- Component reference system for partials
- Enhanced debug output with RAILS_OPENAPI_DEBUG environment variable

### Fixed
- Parser gem compatibility issues between Ruby 3.1.3 and 3.1.7
- RuboCop compliance with all Lint rules enabled
- Test failures related to boolean symbols and unused variables
- Proper handling of nested partials and array structures
- Component naming conflicts in test environments

### Changed
- Parser gem dependency updated to ~> 3.1.0 for better compatibility
- Improved AST parsing with multiple fallback strategies
- Enhanced error messages and debugging capabilities
- Removed project-specific naming patterns from tests

## [0.0.2] - Previous version

### Initial features
- Basic OpenAPI generation from Rails routes
- Jbuilder template parsing with @openapi comments
- Controller action detection
- YAML output generation

## [0.0.1] - Initial release

### Features
- Initial implementation of rails-openapi-gen
- Basic route parsing
- Simple Jbuilder template support