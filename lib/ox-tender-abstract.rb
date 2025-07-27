# frozen_string_literal: true

require_relative 'oxtenderabstract/version'
require_relative 'oxtenderabstract/configuration'
require_relative 'oxtenderabstract/errors'
require_relative 'oxtenderabstract/logger'
require_relative 'oxtenderabstract/result'
require_relative 'oxtenderabstract/document_types'
require_relative 'oxtenderabstract/archive_processor'
require_relative 'oxtenderabstract/xml_parser'
require_relative 'oxtenderabstract/client'

# Main module for OxTenderAbstract library
module OxTenderAbstract
  class Error < StandardError; end

  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = nil
    end

    # Convenience method for searching tenders in specific subsystem
    def search_tenders(org_region:, exact_date:, subsystem_type: DocumentTypes::DEFAULT_SUBSYSTEM,
                       document_type: DocumentTypes::DEFAULT_DOCUMENT_TYPE)
      client = Client.new
      client.search_tenders(
        org_region: org_region,
        exact_date: exact_date,
        subsystem_type: subsystem_type,
        document_type: document_type
      )
    end

    # Enhanced method for searching tenders across multiple subsystems
    def search_all_tenders(org_region:, exact_date:, subsystems: nil, document_types: nil)
      # Default subsystems to search
      subsystems ||= %w[PRIZ RPEC RPGZ BTK UR RGK OD223 RD223]

      client = Client.new
      all_results = {}
      total_tenders = []
      total_archives = 0

      subsystems.each do |subsystem_type|
        # Get appropriate document types for this subsystem
        available_types = DocumentTypes.document_types_for_subsystem(subsystem_type)
        test_types = document_types || [available_types.first] # Test first type by default

        subsystem_results = {
          subsystem: subsystem_type,
          description: DocumentTypes.description_for_subsystem(subsystem_type),
          tenders: [],
          archives: 0,
          errors: []
        }

        test_types.each do |doc_type|
          result = client.search_tenders(
            org_region: org_region,
            exact_date: exact_date,
            subsystem_type: subsystem_type,
            document_type: doc_type
          )

          if result.success?
            tenders = result.data[:tenders] || []
            archives = result.data[:total_archives] || 0

            subsystem_results[:tenders].concat(tenders)
            subsystem_results[:archives] += archives
            total_archives += archives

            # Add subsystem info to each tender
            tenders.each do |tender|
              tender[:subsystem_type] = subsystem_type
              tender[:subsystem_description] = DocumentTypes.description_for_subsystem(subsystem_type)
              tender[:document_type_used] = doc_type
            end

            total_tenders.concat(tenders)
          else
            subsystem_results[:errors] << "#{doc_type}: #{result.error}"
          end
        rescue StandardError => e
          subsystem_results[:errors] << "#{doc_type}: #{e.message}"
        end

        all_results[subsystem_type] = subsystem_results
      end

      Result.success({
                       tenders: total_tenders,
                       total_archives: total_archives,
                       subsystem_results: all_results,
                       search_params: {
                         org_region: org_region,
                         exact_date: exact_date,
                         subsystems_searched: subsystems.size
                       },
                       processed_at: Time.now
                     })
    end

    # Get documents by registry number across subsystems
    def get_docs_by_reestr_number(reestr_number:, subsystem_type: DocumentTypes::DEFAULT_SUBSYSTEM)
      client = Client.new
      client.get_docs_by_reestr_number(
        reestr_number: reestr_number,
        subsystem_type: subsystem_type
      )
    end

    # Enhanced search with detailed information extraction
    def enhanced_search_tenders(org_region:, exact_date:, subsystem_type: DocumentTypes::DEFAULT_SUBSYSTEM,
                                document_type: DocumentTypes::DEFAULT_DOCUMENT_TYPE,
                                include_attachments: true)
      client = Client.new
      client.enhanced_search_tenders(
        org_region: org_region,
        exact_date: exact_date,
        subsystem_type: subsystem_type,
        document_type: document_type,
        include_attachments: include_attachments
      )
    end

    # Search tenders with automatic wait on API blocks and resume capability
    def search_tenders_with_auto_wait(org_region:, exact_date:, subsystem_type: DocumentTypes::DEFAULT_SUBSYSTEM,
                                      document_type: DocumentTypes::DEFAULT_DOCUMENT_TYPE, resume_state: nil)
      client = Client.new
      
      # Если есть состояние для продолжения
      if resume_state
        start_from = resume_state[:next_archive_index] || 0
        client.search_tenders_with_resume(
          org_region: org_region,
          exact_date: exact_date,
          subsystem_type: subsystem_type,
          document_type: document_type,
          start_from_archive: start_from,
          resume_state: resume_state
        )
      else
        # Используем обычный метод если авто-ожидание включено
        if configuration.auto_wait_on_block
          client.search_tenders(
            org_region: org_region,
            exact_date: exact_date,
            subsystem_type: subsystem_type,
            document_type: document_type
          )
        else
          # Используем метод с возможностью продолжения
          client.search_tenders_with_resume(
            org_region: org_region,
            exact_date: exact_date,
            subsystem_type: subsystem_type,
            document_type: document_type
          )
        end
      end
    end
  end
end
