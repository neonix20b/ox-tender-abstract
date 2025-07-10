# frozen_string_literal: true

require_relative 'document_types'
require_relative 'result'
require_relative 'errors'
require_relative 'archive_processor'
require_relative 'xml_parser'
require_relative 'logger'
require 'savon'
require 'securerandom'
require 'net/http'
require 'uri'
require 'openssl'

module OxTenderAbstract
  # Main client for working with Zakupki SOAP API
  class Client
    include ContextualLogger

    def initialize(token: nil)
      @token = token || OxTenderAbstract.configuration.token
      @xml_parser = XmlParser.new
      @archive_processor = ArchiveProcessor.new
      validate_token!
    end

    # Get documents by region and date
    def get_docs_by_region(org_region:, exact_date:, subsystem_type: DocumentTypes::DEFAULT_SUBSYSTEM,
                           document_type: DocumentTypes::DEFAULT_DOCUMENT_TYPE)
      validate_params!({
                         org_region: org_region,
                         subsystem_type: subsystem_type,
                         document_type: document_type,
                         exact_date: exact_date
                       })

      request_data = build_region_request(org_region, subsystem_type, document_type, exact_date)
      execute_soap_request(:get_docs_by_org_region, request_data)
    end

    # Get documents by registry number
    def get_docs_by_reestr_number(reestr_number:, subsystem_type: DocumentTypes::DEFAULT_SUBSYSTEM)
      validate_params!({
                         reestr_number: reestr_number,
                         subsystem_type: subsystem_type
                       })

      request_data = build_reestr_request(reestr_number, subsystem_type)
      log_info "Requesting documents for registry number: #{reestr_number}, type: #{subsystem_type}"

      result = execute_soap_request(:get_docs_by_reestr_number, request_data)

      if result.success?
        log_info "Success response for #{reestr_number}. Found archives: #{result.data[:archive_urls]&.size || 0}"
      else
        log_error "Error for #{reestr_number}: #{result.error}"
      end

      result
    end

    # Download and parse archive data
    def download_archive_data(archive_url)
      @archive_processor.download_and_extract(archive_url)
    end

    # Parse XML document
    def parse_xml_document(xml_content)
      @xml_parser.parse(xml_content)
    end

    # Extract attachments info from XML
    def extract_attachments_from_xml(xml_content)
      @xml_parser.extract_attachments(xml_content)
    end

    # Search tenders with full workflow: API -> Archive -> Parse
    def search_tenders(org_region:, exact_date:, subsystem_type: DocumentTypes::DEFAULT_SUBSYSTEM,
                       document_type: DocumentTypes::DEFAULT_DOCUMENT_TYPE)
      log_info "Starting tender search for region #{org_region}, date #{exact_date}"

      # Step 1: Get archive URLs from API
      api_result = get_docs_by_region(
        org_region: org_region,
        subsystem_type: subsystem_type,
        document_type: document_type,
        exact_date: exact_date
      )

      return api_result if api_result.failure?

      archive_urls = api_result.data[:archive_urls]
      return Result.success({ tenders: [], total_archives: 0, total_files: 0 }) if archive_urls.empty?

      log_info "Found #{archive_urls.size} archives to process"

      # Step 2: Process each archive
      all_tenders = []
      total_files = 0

      archive_urls.each_with_index do |archive_url, index|
        log_info "Processing archive #{index + 1}/#{archive_urls.size}"

        archive_result = download_archive_data(archive_url)
        next if archive_result.failure?

        files = archive_result.data[:files]
        total_files += files.size

        # Step 3: Parse XML files from archive
        xml_files = files.select { |name, _| name.downcase.end_with?('.xml') }

        xml_files.each do |file_name, file_data|
          parse_result = parse_xml_document(file_data[:content])
          next if parse_result.failure?
          next unless parse_result.data[:document_type] == :tender

          tender_data = parse_result.data[:content]
          next if tender_data[:reestr_number].nil? || tender_data[:reestr_number].empty?

          # Add metadata
          tender_data[:source_file] = file_name
          tender_data[:archive_url] = archive_url
          tender_data[:processed_at] = Time.now

          all_tenders << tender_data
        end
      end

      log_info "Search completed. Found #{all_tenders.size} tenders in #{total_files} files"

      Result.success({
                       tenders: all_tenders,
                       total_archives: archive_urls.size,
                       total_files: total_files,
                       processed_at: Time.now
                     })
    end

    private

    def validate_token!
      return if @token&.strip&.length&.positive?

      raise AuthenticationError, 'Token cannot be empty. Set it via OxTenderAbstract.configure or pass as parameter'
    end

    def validate_params!(params)
      params.each do |key, value|
        raise ConfigurationError, "Parameter #{key} cannot be blank" if value.nil? || value.to_s.strip.empty?
      end
    end

    def build_region_request(org_region, subsystem_type, document_type, exact_date)
      {
        'index' => {
          'id' => SecureRandom.uuid,
          'createDateTime' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
          'mode' => 'PROD'
        },
        'selectionParams' => {
          'orgRegion' => org_region,
          'subsystemType' => subsystem_type,
          'documentType44' => document_type,
          'periodInfo' => {
            'exactDate' => exact_date
          }
        }
      }
    end

    def build_reestr_request(reestr_number, subsystem_type)
      {
        'index' => {
          'id' => SecureRandom.uuid,
          'createDateTime' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
          'mode' => 'PROD'
        },
        'selectionParams' => {
          'subsystemType' => subsystem_type,
          'registryNumber' => reestr_number
        }
      }
    end

    def execute_soap_request(operation, message)
      client = create_soap_client
      log_debug "Executing SOAP request: #{operation}"
      log_debug "SOAP header: #{client.globals[:soap_header]}"
      log_debug "Request message: #{message.inspect}"

      response = client.call(operation, message: message)
      log_debug "SOAP response code: #{response.http.code}"
      log_debug "SOAP response body keys: #{response.body.keys}"

      process_soap_response(response, operation)
    rescue Savon::SOAPFault => e
      log_error "SOAP Fault: #{e.message}"
      log_error "SOAP Fault details: #{e.to_hash}"
      Result.failure("SOAP Fault: #{e.message}")
    rescue Savon::HTTPError => e
      log_error "HTTP Error: #{e.message}"
      Result.failure("HTTP Error: #{e.message}")
    rescue StandardError => e
      log_error "General request error: #{e.message}"
      log_error "#{e.backtrace.first(5).join("\n")}"
      Result.failure("Request error: #{e.message}")
    end

    def create_soap_client
      token_status = !@token.nil? && !@token.empty? ? "present (#{@token[0..5]}...)" : 'missing'
      log_debug "Creating SOAP client with token: #{token_status}"

      Savon.client(
        wsdl: OxTenderAbstract.configuration.wsdl_url,
        soap_header: { 'individualPerson_token' => @token },
        open_timeout: OxTenderAbstract.configuration.timeout_open,
        read_timeout: OxTenderAbstract.configuration.timeout_read,
        ssl_verify_mode: OxTenderAbstract.configuration.ssl_verify ? :peer : :none,
        log: false
      )
    end

    def process_soap_response(response, operation)
      return Result.failure('Empty response') unless response&.body

      case operation
      when :get_docs_by_org_region
        process_region_response(response.body)
      when :get_docs_by_reestr_number
        process_reestr_response(response.body)
      else
        Result.failure("Unknown operation: #{operation}")
      end
    end

    def process_region_response(body)
      data_info = body.dig(:get_docs_by_org_region_response, :data_info)
      return Result.failure('No data info in response') unless data_info

      archive_urls = extract_archive_urls(data_info)

      Result.success({
                       archive_urls: archive_urls,
                       response_metadata: {
                         operation: :get_docs_by_org_region,
                         timestamp: Time.now
                       }
                     })
    end

    def process_reestr_response(body)
      data_info = body.dig(:get_docs_by_reestr_number_response, :data_info)
      return Result.failure('No data info in response') unless data_info

      archive_urls = extract_archive_urls(data_info)

      Result.success({
                       archive_urls: archive_urls,
                       response_metadata: {
                         operation: :get_docs_by_reestr_number,
                         timestamp: Time.now
                       }
                     })
    end

    def extract_archive_urls(data_info)
      return [] unless data_info&.dig(:archive_url)

      Array(data_info[:archive_url]).compact
    end
  end
end
