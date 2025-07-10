# frozen_string_literal: true

module OxTenderAbstract
  # Base error class for the library
  class Error < StandardError; end

  # Configuration related errors
  class ConfigurationError < Error; end

  # Network related errors
  class NetworkError < Error; end

  # SOAP API related errors
  class SoapError < Error; end

  # XML parsing related errors
  class ParseError < Error; end

  # Archive processing related errors
  class ArchiveError < Error; end

  # Authentication related errors
  class AuthenticationError < Error; end
end
