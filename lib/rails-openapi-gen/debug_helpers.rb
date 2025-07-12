# frozen_string_literal: true

# Debug helpers for Rails OpenAPI Gen development
module RailsOpenapiGen
  module DebugHelpers
    # Quick debug a Jbuilder file
    # @param file_path [String] Path to Jbuilder file
    # @param mode [Symbol] Debug mode (:compact, :full, :export)
    # @return [void]
    def self.debug_jbuilder(file_path, mode: :compact)
      parser = RailsOpenapiGen::Parsers::Jbuilder::JbuilderParser.new(file_path)
      
      case mode
      when :compact
        parser.debug_print_compact
      when :full
        parser.debug_print_result
      when :export
        parser.debug_export_ast
      else
        puts "Unknown mode: #{mode}. Use :compact, :full, or :export"
      end
    end

    # Debug multiple Jbuilder files at once
    # @param pattern [String] Glob pattern for files
    # @param mode [Symbol] Debug mode
    # @return [void]
    def self.debug_multiple(pattern = "**/*.jbuilder", mode: :compact)
      files = Dir.glob(pattern)
      
      if files.empty?
        puts "No files found with pattern: #{pattern}"
        return
      end
      
      puts "🔍 Debugging #{files.size} files with pattern: #{pattern}"
      puts "=" * 60
      
      files.each_with_index do |file, index|
        puts "\n[#{index + 1}/#{files.size}] #{file}"
        debug_jbuilder(file, mode: mode)
      end
    end

    # Create a sample AST tree for testing
    # @return [RailsOpenapiGen::AstNodes::ObjectNode] Sample AST tree
    def self.create_sample_ast
      root = RailsOpenapiGen::AstNodes::ObjectNode.new(
        property_name: "user",
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: "object",
          description: "User information"
        )
      )
      
      # Add name property
      name_prop = RailsOpenapiGen::AstNodes::PropertyNode.new(
        property_name: "name",
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: "string",
          description: "User's full name",
          required: true
        )
      )
      root.add_child(name_prop)
      
      # Add email property
      email_prop = RailsOpenapiGen::AstNodes::PropertyNode.new(
        property_name: "email",
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: "string",
          description: "User's email address",
          required: true
        )
      )
      root.add_child(email_prop)
      
      # Add posts array
      posts_array = RailsOpenapiGen::AstNodes::ArrayNode.new(
        property_name: "posts",
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: "array",
          description: "User's posts"
        )
      )
      
      # Add post title to array items
      title_prop = RailsOpenapiGen::AstNodes::PropertyNode.new(
        property_name: "title",
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: "string",
          description: "Post title"
        )
      )
      posts_array.add_child(title_prop)
      
      root.add_child(posts_array)
      
      root
    end

    # Demo the pretty print functionality
    # @return [void]
    def self.demo_pretty_print
      puts "🎨 Pretty Print Demo"
      puts "=" * 50
      
      ast = create_sample_ast
      
      puts "\n📋 Sample AST Structure:"
      ast.pretty_print
      
      puts "\n📄 Debug Line Format:"
      puts "Root: #{ast.debug_line}"
      ast.children.each { |child| puts "  Child: #{child.debug_line}" }
      
      puts "\n💾 Export to File:"
      File.open("sample_ast_debug.txt", 'w') do |f|
        original_stdout = $stdout
        $stdout = f
        ast.pretty_print
        $stdout = original_stdout
      end
      puts "Exported to: sample_ast_debug.txt"
    end

    # Show all available example files
    # @return [void]
    def self.list_examples
      patterns = [
        "examples/**/*.jbuilder",
        "spec/**/*.jbuilder",
        "**/*.jbuilder"
      ]
      
      puts "📁 Available Example Files:"
      puts "=" * 40
      
      patterns.each do |pattern|
        files = Dir.glob(pattern)
        next if files.empty?
        
        puts "\n#{pattern}:"
        files.each { |file| puts "  #{file}" }
      end
    end

    # Quick analysis of a Jbuilder file
    # @param file_path [String] Path to file
    # @return [void]
    def self.analyze_file(file_path)
      unless File.exist?(file_path)
        puts "❌ File not found: #{file_path}"
        return
      end
      
      content = File.read(file_path)
      lines = content.lines
      
      puts "📊 Quick Analysis: #{File.basename(file_path)}"
      puts "=" * 40
      puts "Lines: #{lines.size}"
      puts "Size: #{content.size} bytes"
      
      # Count different elements
      openapi_comments = lines.count { |line| line.include?('@openapi') }
      json_calls = lines.count { |line| line.include?('json.') }
      partials = lines.count { |line| line.include?('partial!') }
      arrays = lines.count { |line| line.include?('array!') }
      
      puts "OpenAPI comments: #{openapi_comments}"
      puts "JSON calls: #{json_calls}"
      puts "Partials: #{partials}"
      puts "Arrays: #{arrays}"
      
      puts "\n🔍 Preview (first 10 lines):"
      lines.first(10).each_with_index do |line, i|
        puts "#{(i+1).to_s.rjust(2)}: #{line.chomp}"
      end
      
      puts "\n🚀 Parse with: RailsOpenapiGen::DebugHelpers.debug_jbuilder('#{file_path}')"
    end
  end
end