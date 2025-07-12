# Rails OpenAPI Gen

Rails comment-driven OpenAPI specification generator.

## Requirements

- **Ruby 3.0 or higher**
- **Rails 6.0 or higher**

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails-openapi-gen'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install rails-openapi-gen
```

## Overview

rails-openapi-gen analyzes your Rails application's routes.rb, controllers, and jbuilder templates to automatically generate OpenAPI documentation. It uses AST parsing to extract JSON structure and relies on `# @openapi` comments for accurate type information.

## Note

AST analysis alone cannot accurately infer all conditional branches and partial patterns. Type, required status, enum values, and descriptions should be explicitly defined using `# @openapi` comments as the source of truth.

### Limitations

The following Jbuilder patterns are not currently supported:

- **Shorthand array syntax**: `json.array! @items, :id, :name` - This shorthand notation cannot be annotated with `@openapi` comments. Use the block form instead:
  ```ruby
  json.array! @items do |item|
    # @openapi id:integer required:true description:"Item ID"
    json.id item.id
    
    # @openapi name:string required:true description:"Item name"
    json.name item.name
  end
  ```

- **Extract shorthand**: `json.extract! @item, :id, :name` - This shorthand notation cannot be annotated with `@openapi` comments. Use explicit property assignments instead:
  ```ruby
  # @openapi id:integer required:true description:"Item ID"
  json.id @item.id
  
  # @openapi name:string required:true description:"Item name"
  json.name @item.name
  ```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails-openapi-gen'
```

And then execute:

```bash
$ bundle install
```

## Usage

### Comment Format

Add `# @openapi` comments to your jbuilder templates:

```ruby
# @openapi id:integer required:true description:"User ID"
json.id @user.id

# @openapi status:string enum:[active,inactive] description:"User status"
json.status @user.status

# @openapi email:string required:true description:"User email address"
json.email @user.email

# @openapi created_at:string description:"ISO 8601 timestamp"
json.created_at @user.created_at.iso8601
```

### Generate OpenAPI Specification

```bash
bin/rails openapi:generate
```

This creates the following structure:

```
openapi/
  openapi.yaml       # Main OpenAPI file
  paths/
    users.yaml      # Path definitions
    posts.yaml
  components/
    schemas/
      user.yaml     # Schema definitions
      post.yaml
```

### Check for Missing Comments

```bash
bin/rails openapi:check
```

This command will:
- Generate the OpenAPI specification
- Check for missing `@openapi` comments (marked as "TODO: MISSING COMMENT")
- Verify no uncommitted changes in the openapi/ directory
- Exit with code 1 if issues are found

## CI Integration

Add to your CI pipeline:

```yaml
name: OpenAPI Spec Check
on: [push, pull_request]

jobs:
  openapi-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      
      - name: Generate OpenAPI Spec
        run: bin/rails openapi:generate
      
      - name: Check for missing comments
        run: |
          if grep -r "TODO: MISSING COMMENT" openapi/; then
            echo "❌ Missing @openapi comments!"
            exit 1
          fi
      
      - name: Check for unexpected diffs
        run: git diff --exit-code openapi/
```

## Comment Attributes

- `type`: Data type (string, integer, boolean, number, array, object)
- `required`: Whether the field is required (true/false)
- `enum`: Allowed values for the field
- `description`: Human-readable description

## Features

- ✅ Routes.rb parsing for endpoint discovery
- ✅ Controller analysis to locate jbuilder templates
- ✅ AST-based jbuilder parsing with partial support
- ✅ Comment-driven type annotations
- ✅ Split YAML generation with $ref support
- ✅ CI-friendly validation commands
- 🚧 ActiveRecord model inference (optional, future)
- 🚧 Serializer support (future)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rails-openapi-gen/rails-openapi-gen.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).