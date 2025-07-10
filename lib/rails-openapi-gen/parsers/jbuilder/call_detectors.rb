module RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
  autoload :JsonCallDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/json_call_detector"
  autoload :CacheCallDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/cache_call_detector"
  autoload :KeyFormatDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/key_format_detector"
  autoload :NullHandlingDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/null_handling_detector"
  autoload :ObjectManipulationDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/object_manipulation_detector"
  autoload :ArrayCallDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/array_call_detector"
  autoload :PartialCallDetector, "rails-openapi-gen/parsers/jbuilder/call_detectors/partial_call_detector"
end
