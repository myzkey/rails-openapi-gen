# frozen_string_literal: true

require 'logger'
require 'singleton'

module RailsOpenapiGen
  class Logger
    include Singleton

    LOG_LEVELS = {
      debug: ::Logger::DEBUG,
      info: ::Logger::INFO,
      warn: ::Logger::WARN,
      error: ::Logger::ERROR,
      fatal: ::Logger::FATAL
    }.freeze

    EMOJI_MAP = {
      debug: '🔍',
      info: 'ℹ️',
      warn: '⚠️',
      error: '❌',
      fatal: '💀',
      success: '✅',
      file: '📝',
      folder: '📁',
      component: '📦',
      reference: '🔗',
      process: '🔄',
      delete: '🗑️',
      unknown: '❓'
    }.freeze

    attr_reader :logger

    def initialize
      @logger = create_logger
      configure_from_env
    end

    def self.instance
      @instance ||= new
    end

    def debug(message, emoji: :debug)
      return unless debug?

      log(:debug, message, emoji)
    end

    def info(message, emoji: :info)
      log(:info, message, emoji)
    end

    def warn(message, emoji: :warn)
      log(:warn, message, emoji)
    end

    def error(message, emoji: :error)
      log(:error, message, emoji)
    end

    def fatal(message, emoji: :fatal)
      log(:fatal, message, emoji)
    end

    def success(message)
      info(message, emoji: :success)
    end

    def file_operation(message)
      info(message, emoji: :file)
    end

    def component_operation(message)
      info(message, emoji: :component)
    end

    def configure(level: nil, output: nil, colorize: true, format: :default)
      @logger = create_logger(output: output)
      @logger.level = LOG_LEVELS[level] || @logger.level if level
      @colorize = colorize
      @format = format
      configure_formatter
    end

    def silence_during
      original_level = @logger.level
      @logger.level = ::Logger::FATAL
      yield
    ensure
      @logger.level = original_level
    end

    private

    def create_logger(output: nil)
      output ||= ENV['RAILS_OPENAPI_LOG_FILE'] || $stdout
      ::Logger.new(output)
    end

    def configure_from_env
      if ENV['RAILS_OPENAPI_DEBUG']
        @logger.level = ::Logger::DEBUG
      elsif ENV['RAILS_OPENAPI_LOG_LEVEL']
        level = ENV['RAILS_OPENAPI_LOG_LEVEL'].to_sym
        @logger.level = LOG_LEVELS[level] || ::Logger::INFO
      else
        @logger.level = ::Logger::INFO
      end

      @colorize = ENV['RAILS_OPENAPI_NO_COLOR'].nil?
      @format = (ENV['RAILS_OPENAPI_LOG_FORMAT'] || 'default').to_sym

      configure_formatter
    end

    def configure_formatter
      @logger.formatter = case @format
                          when :json
                            json_formatter
                          when :plain
                            plain_formatter
                          else
                            default_formatter
                          end
    end

    def default_formatter
      proc do |severity, _datetime, _progname, msg|
        emoji = msg[:emoji] || severity_to_emoji(severity)
        message = msg.is_a?(Hash) ? msg[:message] : msg

        if @colorize && $stdout.tty?
          color = severity_color(severity)
          "#{colorize(emoji, color)} #{colorize(message, color)}\n"
        else
          "#{emoji} #{message}\n"
        end
      end
    end

    def plain_formatter
      proc do |severity, _datetime, _progname, msg|
        message = msg.is_a?(Hash) ? msg[:message] : msg
        "[#{severity}] #{message}\n"
      end
    end

    def json_formatter
      proc do |severity, datetime, _progname, msg|
        require 'json'

        data = {
          timestamp: datetime.strftime('%Y-%m-%dT%H:%M:%S.%3N%z'),
          level: severity,
          message: msg.is_a?(Hash) ? msg[:message] : msg
        }

        if msg.is_a?(Hash) && msg[:context]
          data[:context] = msg[:context]
        end

        "#{data.to_json}\n"
      end
    end

    def log(level, message, emoji)
      formatted_message = {
        message: message,
        emoji: EMOJI_MAP[emoji] || EMOJI_MAP[level]
      }

      @logger.send(level, formatted_message)
    end

    def debug?
      @logger.level <= ::Logger::DEBUG
    end

    def severity_to_emoji(severity)
      severity_key = case severity
                     when 'DEBUG' then :debug
                     when 'INFO' then :info
                     when 'WARN' then :warn
                     when 'ERROR' then :error
                     when 'FATAL' then :fatal
                     else :unknown
                     end
      EMOJI_MAP[severity_key]
    end

    def severity_color(severity)
      case severity
      when 'DEBUG' then :cyan
      when 'INFO' then :green
      when 'WARN' then :yellow
      when 'ERROR' then :red
      when 'FATAL' then :magenta
      else :default
      end
    end

    def colorize(text, color)
      colors = {
        cyan: "\e[36m",
        green: "\e[32m",
        yellow: "\e[33m",
        red: "\e[31m",
        magenta: "\e[35m",
        default: "\e[0m"
      }

      "#{colors[color]}#{text}\e[0m"
    end
  end

  # Convenience module for easy access to logger methods
  module Logging
    def logger
      Logger.instance
    end
  end
end
