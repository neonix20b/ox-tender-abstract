# frozen_string_literal: true

require_relative 'oxtenderabstract/version'
require_relative 'oxtenderabstract/logger'
require_relative 'oxtenderabstract/errors'
require_relative 'oxtenderabstract/result'
require_relative 'oxtenderabstract/document_types'
require_relative 'oxtenderabstract/configuration'
require_relative 'oxtenderabstract/xml_parser'
require_relative 'oxtenderabstract/archive_processor'
require_relative 'oxtenderabstract/client'

# Main module for OxTenderAbstract library
module OxTenderAbstract
  class Error < StandardError; end

  # Convenience method to create a new client
  def self.client(token: nil)
    Client.new(token: token)
  end

  # Search tenders by region and date (convenience method)
  def self.search_tenders(org_region:, exact_date:, token: nil, **options)
    client = Client.new(token: token)
    client.search_tenders(org_region: org_region, exact_date: exact_date, **options)
  end

  # Enhanced search tenders with detailed information (convenience method)
  def self.enhanced_search_tenders(org_region:, exact_date:, token: nil, **options)
    client = Client.new(token: token)
    client.enhanced_search_tenders(org_region: org_region, exact_date: exact_date, **options)
  end

  # Get documents by registry number (convenience method)
  def self.get_docs_by_reestr_number(reestr_number:, token: nil, **options)
    client = Client.new(token: token)
    client.get_docs_by_reestr_number(reestr_number: reestr_number, **options)
  end
end
