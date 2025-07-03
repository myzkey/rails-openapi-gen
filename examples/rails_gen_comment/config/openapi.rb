# Rails OpenAPI Gen Configuration
# This file configures the OpenAPI specification generation for your Rails application.

RailsOpenapiGen.configure do |config|
  # OpenAPI specification version
  config.openapi_version = "3.0.0"
  
  # API information
  config.info = {
    title: "User Management API",
    version: "1.2.0",
    description: "REST API for managing users and their profiles",
    contact: {
      name: "API Support Team",
      email: "api-support@myapp.com",
      url: "https://myapp.com/support"
    },
    license: {
      name: "MIT",
      url: "https://opensource.org/licenses/MIT"
    }
  }
  
  # Server configurations
  config.servers = [
    {
      url: "https://api.myapp.com",
      description: "Production server"
    },
    {
      url: "https://staging-api.myapp.com",
      description: "Staging server"
    },
    {
      url: "http://localhost:3000",
      description: "Development server"
    }
  ]
  
  # Route filtering
  config.route_patterns = {
    include: [
      /^\/users/,      # User routes
      /^\/posts/,      # Post routes
      /^\/comments/,   # Comment routes  
      /^\/auth/,       # Authentication routes
      /^\/admin/,      # Admin routes
      /^\/api\//       # API routes
    ],
    exclude: [
      /\/rails\//,     # Rails internal routes
      /\/up/           # Health check
    ]
  }
  
  # Output configuration
  config.output = {
    directory: "docs/api",
    filename: "openapi.yaml",
    split_files: true
  }
end