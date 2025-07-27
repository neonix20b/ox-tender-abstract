# frozen_string_literal: true

module OxTenderAbstract
  # Base error class for the library
  class Error < StandardError; end

  # Configuration related errors
  class ConfigurationError < Error; end

  # API related errors
  class ApiError < Error; end

  # Archive processing errors
  class ArchiveError < Error; end

  # XML parsing errors
  class ParseError < Error; end

  # Network related errors
  class NetworkError < Error; end

  # Archive download blocked error (10 minute block)
  class ArchiveBlockedError < ArchiveError
    attr_reader :blocked_until, :retry_after_seconds

    def initialize(message = 'Archive download blocked', retry_after_seconds = 600)
      super(message)
      @retry_after_seconds = retry_after_seconds
      @blocked_until = Time.now + retry_after_seconds
    end

    def can_retry_at
      @blocked_until
    end
  end
end
