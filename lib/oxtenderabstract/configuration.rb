# frozen_string_literal: true

require 'logger'

module OxTenderAbstract
  # Configuration for the library
  class Configuration
    attr_accessor :token, :timeout_open, :timeout_read, :ssl_verify,
                  :auto_wait_on_block, :block_wait_time, :max_wait_time
    attr_writer :wsdl_url, :logger

    def initialize
      @token = nil
      @timeout_open = 30
      @timeout_read = 120
      @ssl_verify = false
      @wsdl_url = nil  # Will be set later
      @logger = nil    # Will be set later
      @auto_wait_on_block = true  # Автоматически ждать при блокировке
      @block_wait_time = 610      # Время ожидания при блокировке (10 мин + 10 сек)
      @max_wait_time = 900        # Максимальное время ожидания (15 мин)
    end

    def wsdl_url
      @wsdl_url ||= DocumentTypes::API_CONFIG[:wsdl]
    end

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.level = Logger::INFO
        log.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
        end
      end
    end

    def valid?
      !token.nil? && !token.empty?
    end

    def token_from_file(file_path)
      return nil unless File.exist?(file_path)

      content = File.read(file_path).strip
      content.empty? ? nil : content
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
