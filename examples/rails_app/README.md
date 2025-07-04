# Rails OpenAPI Gen Example App

This Rails application demonstrates various render patterns and OpenAPI generation capabilities with rails-openapi-gen.

## Features Demonstrated

### Standard Template Rendering
- Basic controller actions with conventional template paths
- Example: `UsersController#show` → `app/views/api/users/show.json.jbuilder`

### Explicit Template Rendering
The application includes examples of different render patterns that rails-openapi-gen can handle:

#### 1. Explicit Template with Format and Handler
```ruby
# PostsController#featured
render template: "api/v1/posts/featured_list",
       formats: :json,
       handlers: :jbuilder
```
- **Template**: `app/views/api/v1/posts/featured_list.json.jbuilder`
- **Endpoint**: `GET /api/posts/featured`
- **Use case**: Versioned API templates in different directory structure

#### 2. Shared Template Rendering
```ruby
# PostsController#archive  
render template: "shared/post_list"
```
- **Template**: `app/views/shared/post_list.json.jbuilder`
- **Endpoint**: `GET /api/posts/archive`
- **Use case**: Reusable templates across different controllers

### OpenAPI Integration

The app includes a complete OpenAPI specification that covers:
- Standard CRUD operations
- Custom actions with explicit templates
- Detailed request/response schemas
- Proper parameter definitions

## Running OpenAPI Generation

Generate OpenAPI spec from Jbuilder templates:
```bash
bin/rails openapi:generate
```

Import from existing OpenAPI spec to add comments:
```bash
bin/rails runner "RailsOpenapiGen.import('docs/api/openapi.yaml')"
```

Check for missing comments:
```bash
bin/rails openapi:check
```

## Template Patterns Supported

| Pattern | Example | Template Path |
|---------|---------|---------------|
| **Convention** | `render` (default) | `app/views/{controller}/{action}.json.jbuilder` |
| **Explicit Template** | `render template: "path/template"` | `app/views/path/template.json.jbuilder` |
| **With Format/Handler** | `render template: "path", formats: :json, handlers: :jbuilder` | `app/views/path.json.jbuilder` |
| **Shared Templates** | `render template: "shared/template"` | `app/views/shared/template.json.jbuilder` |

## Key Files

- `app/controllers/api/posts_controller.rb` - Examples of different render patterns
- `app/views/api/v1/posts/featured_list.json.jbuilder` - Explicit template example
- `app/views/shared/post_list.json.jbuilder` - Shared template example
- `docs/api/openapi.yaml` - Complete OpenAPI specification
- `config/routes.rb` - Route definitions matching OpenAPI paths
