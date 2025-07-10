# frozen_string_literal: true

require "nokogiri"

module OxTenderAbstract
  # XML parser for tender documents
  class XmlParser
    include ContextualLogger

    def initialize
      # XML parser initialization
    end

    # Parse XML document and return structured data
    def parse(xml_content)
      return Result.failure("Empty XML content") if xml_content.nil? || xml_content.empty?

      begin
        doc = Nokogiri::XML(xml_content)

        # Check XML validity
        return Result.failure("Invalid XML") if doc.errors.any?

        # Detect document type
        document_type = detect_document_type(doc)

        # Extract data based on type
        parsed_data = case document_type
        when :tender
          parse_tender_document(doc)
        when :contract
          parse_contract_document(doc)
        when :organization
          parse_organization_document(doc)
        else
          parse_generic_document(doc)
        end

        Result.success({
          document_type: document_type,
          root_element: doc.root.name,
          namespace: doc.root.namespace&.href,
          content: parsed_data
        })
      rescue => e
        Result.failure("XML parsing error: #{e.message}")
      end
    end

    # Extract attachments information from XML
    def extract_attachments(xml_content)
      return Result.failure("Empty XML content") if xml_content.nil? || xml_content.empty?

      begin
        doc = Nokogiri::XML(xml_content)
        namespaces = extract_namespaces(doc)

        # Find various attachment node patterns
        attachment_nodes = []

        # Common attachment paths
        attachment_paths = [
          "//ns4:attachmentInfo",
          "//attachmentInfo", 
          "//ns5:attachmentsInfo//ns4:attachmentInfo",
          "//attachmentsInfo//attachmentInfo"
        ]

        attachment_paths.each do |path|
          nodes = doc.xpath(path, namespaces)
          attachment_nodes.concat(nodes) if nodes.any?
        end

        attachments = attachment_nodes.map { |node| extract_attachment_info(node) }.compact

        Result.success({
          attachments: attachments,
          total_count: attachments.size
        })
      rescue => e
        Result.failure("Attachment extraction error: #{e.message}")
      end
    end

    private

    def detect_document_type(doc)
      root_name = doc.root.name.downcase

      case root_name
      when /notification/, /tender/, /auction/
        :tender
      when /contract/
        :contract  
      when /organization/, /org/
        :organization
      else
        # Additional detection based on content (without namespaces for simple detection)
        if doc.xpath("//purchaseNumber").any? || doc.xpath("//*[local-name()='purchaseNumber']").any?
          :tender
        elsif doc.xpath("//contractNumber").any? || doc.xpath("//*[local-name()='contractNumber']").any?
          :contract
        else
          :unknown
        end
      end
    end

    def parse_tender_document(doc)
      namespaces = extract_namespaces(doc)
      
      log_debug "Parsing tender document with namespaces: #{namespaces.keys}"

      # Basic tender information
      tender_data = {
        reestr_number: find_text_with_namespaces(doc, [
          "//ns5:purchaseNumber",
          "//purchaseNumber",
          "//ns5:commonInfo/ns5:purchaseNumber",
          "//commonInfo/purchaseNumber"
        ], namespaces),
        
        doc_number: find_text_with_namespaces(doc, [
          "//ns5:docNumber", 
          "//docNumber",
          "//ns5:commonInfo/ns5:docNumber"
        ], namespaces),

        title: find_text_with_namespaces(doc, [
          "//ns5:purchaseObjectInfo",
          "//purchaseObjectInfo", 
          "//ns5:commonInfo/ns5:purchaseObjectInfo"
        ], namespaces),

        placement_type: find_text_with_namespaces(doc, [
          "//ns5:placingWay/ns2:name",
          "//placingWay/name",
          "//ns2:name"
        ], namespaces),

        publish_date: extract_date_from_text(find_text_with_namespaces(doc, [
          "//ns5:publishDTInEIS",
          "//publishDTInEIS",
          "//ns5:commonInfo/ns5:publishDTInEIS"
        ], namespaces)),

        planned_publish_date: extract_date_from_text(find_text_with_namespaces(doc, [
          "//ns5:plannedPublishDate",
          "//plannedPublishDate"
        ], namespaces)),

        # Contract information
        max_price: extract_price_from_text(find_text_with_namespaces(doc, [
          "//ns5:maxPrice",
          "//maxPrice",
          "//ns5:contractConditionsInfo/ns5:maxPriceInfo/ns5:maxPrice",
          "//ns5:notificationInfo/ns5:contractConditionsInfo/ns5:maxPriceInfo/ns5:maxPrice"
        ], namespaces)),

        currency: find_text_with_namespaces(doc, [
          "//ns5:currency/ns2:name",
          "//currency/name",
          "//ns2:name[parent::currency]"
        ], namespaces),

        # Dates
        start_date: extract_date_from_text(find_text_with_namespaces(doc, [
          "//ns5:startDT",
          "//startDT", 
          "//ns5:collectingInfo/ns5:startDT"
        ], namespaces)),

        end_date: extract_date_from_text(find_text_with_namespaces(doc, [
          "//ns5:endDT",
          "//endDT",
          "//ns5:collectingInfo/ns5:endDT"
        ], namespaces)),

        bidding_date: extract_date_from_text(find_text_with_namespaces(doc, [
          "//ns5:biddingDate",
          "//biddingDate"
        ], namespaces)),

        summarizing_date: extract_date_from_text(find_text_with_namespaces(doc, [
          "//ns5:summarizingDate", 
          "//summarizingDate"
        ], namespaces)),

        # Organization info
        organization_name: find_text_with_namespaces(doc, [
          "//ns5:responsibleOrgInfo/ns5:fullName",
          "//responsibleOrgInfo/fullName",
          "//ns5:fullName",
          "//fullName"
        ], namespaces),

        organization_short_name: find_text_with_namespaces(doc, [
          "//ns5:responsibleOrgInfo/ns5:shortName",
          "//responsibleOrgInfo/shortName",
          "//ns5:shortName",
          "//shortName"
        ], namespaces),

        organization_inn: find_text_with_namespaces(doc, [
          "//ns5:responsibleOrgInfo/ns5:INN",
          "//responsibleOrgInfo/INN",
          "//ns5:INN",
          "//INN"
        ], namespaces),

        organization_kpp: find_text_with_namespaces(doc, [
          "//ns5:responsibleOrgInfo/ns5:KPP",
          "//responsibleOrgInfo/KPP", 
          "//ns5:KPP",
          "//KPP"
        ], namespaces),

        # Contact information
        contact_email: find_text_with_namespaces(doc, [
          "//ns5:contactEMail",
          "//contactEMail"
        ], namespaces),

        contact_phone: find_text_with_namespaces(doc, [
          "//ns5:contactPhone", 
          "//contactPhone"
        ], namespaces),

        # Electronic trading platform
        etp_name: find_text_with_namespaces(doc, [
          "//ns5:ETP/ns2:name",
          "//ETP/name"
        ], namespaces),

        etp_url: find_text_with_namespaces(doc, [
          "//ns5:ETP/ns2:url",
          "//ETP/url"
        ], namespaces),

        # URLs
        href: find_text_with_namespaces(doc, [
          "//ns5:href",
          "//href"
        ], namespaces),

        print_form_url: find_text_with_namespaces(doc, [
          "//ns5:printFormInfo/ns4:url",
          "//printFormInfo/url"
        ], namespaces)
      }

      # Additional processing
      tender_data[:procedure_info] = extract_procedure_info(doc, namespaces)
      tender_data[:lot_info] = extract_lot_information(doc, namespaces)
      tender_data[:guarantee_info] = extract_guarantee_info(doc, namespaces)

      # Clean up empty values
      tender_data.compact
    end

    def parse_contract_document(doc)
      namespaces = extract_namespaces(doc)

      {
        contract_number: find_text_with_namespaces(doc, [
          "//contractNumber",
          "//ns5:contractNumber"
        ], namespaces),
        
        # Add contract-specific parsing logic here
        document_parsed_at: Time.now
      }
    end

    def parse_organization_document(doc)
      namespaces = extract_namespaces(doc)

      {
        organization_name: find_text_with_namespaces(doc, [
          "//fullName",
          "//ns5:fullName"
        ], namespaces),
        
        # Add organization-specific parsing logic here
        document_parsed_at: Time.now
      }
    end

    def parse_generic_document(doc)
      {
        root_element: doc.root.name,
        namespace: doc.root.namespace&.href,
        element_count: doc.xpath("//*").count,
        document_parsed_at: Time.now
      }
    end

    def extract_attachment_info(node)
      {
        published_content_id: extract_text_from_node(node, ".//ns4:publishedContentId | .//publishedContentId"),
        file_name: extract_text_from_node(node, ".//ns4:fileName | .//fileName"),
        file_size: extract_text_from_node(node, ".//ns4:fileSize | .//fileSize")&.to_i,
        description: extract_text_from_node(node, ".//ns4:docDescription | .//docDescription"),
        url: extract_text_from_node(node, ".//ns4:url | .//url"),
        doc_kind: extract_text_from_node(node, ".//ns4:docKindInfo/ns2:name | .//docKindInfo/name | .//ns2:name"),
        doc_date: extract_date_from_text(extract_text_from_node(node, ".//ns4:docDate | .//docDate"))
      }.compact
    end

    def extract_namespaces(doc)
      doc.collect_namespaces
    end

    def find_text_with_namespaces(doc, xpaths, namespaces)
      xpaths.each do |xpath|
        begin
          node = doc.at_xpath(xpath, namespaces)
          text = node&.text&.strip
          return text if text && !text.empty?
        rescue => e
          log_debug "XPath error for '#{xpath}': #{e.message}"
          next
        end
      end
      nil
    end

    def extract_text_from_node(node, xpath)
      node.at_xpath(xpath)&.text&.strip
    end

    def extract_price_from_text(text)
      return nil if text.nil? || text.empty?
      
      # Remove any non-digit characters except decimal separator
      cleaned = text.gsub(/[^\d.,]/, "")
      return nil if cleaned.empty?
      
      # Convert to string with proper decimal separator
      result = cleaned.tr(",", ".")
      return result if result =~ /^\d+(\.\d+)?$/
      nil
    rescue
      nil
    end

    def extract_date_from_text(text)
      return nil if text.nil? || text.empty?
      
      # Try to parse various date formats
      [
        "%Y-%m-%dT%H:%M:%S%z",     # ISO 8601 with timezone
        "%Y-%m-%dT%H:%M:%S",       # ISO 8601 without timezone  
        "%Y-%m-%d%z",              # Date with timezone
        "%Y-%m-%d",                # Simple date
        "%d.%m.%Y",                # Russian format
        "%d/%m/%Y"                 # Alternative format
      ].each do |format|
        begin
          return Time.strptime(text, format)
        rescue ArgumentError
          next
        end
      end
      
      # Try natural parsing as fallback
      begin
        Time.parse(text)
      rescue
        nil
      end
    end

    def extract_procedure_info(doc, namespaces)
      {
        collecting_start: extract_date_from_text(find_text_with_namespaces(doc, [
          "//ns5:collectingInfo/ns5:startDT",
          "//collectingInfo/startDT"
        ], namespaces)),
        
        collecting_end: extract_date_from_text(find_text_with_namespaces(doc, [
          "//ns5:collectingInfo/ns5:endDT", 
          "//collectingInfo/endDT"
        ], namespaces))
      }.compact
    end

    def extract_lot_information(doc, namespaces)
      lot_nodes = doc.xpath("//ns5:lotInfo | //lotInfo", namespaces)
      return {} if lot_nodes.empty?

      lots = lot_nodes.map do |lot_node|
        {
          lot_number: extract_text_from_node(lot_node, ".//ns5:lotNumber | .//lotNumber"),
          lot_name: extract_text_from_node(lot_node, ".//ns5:lotName | .//lotName"),
          max_price: extract_price_from_text(extract_text_from_node(lot_node, ".//ns5:maxPrice | .//maxPrice"))
        }.compact
      end

      { lots: lots, lots_count: lots.size }
    end

    def extract_guarantee_info(doc, namespaces)
      {
        contract_guarantee_part: find_text_with_namespaces(doc, [
          "//ns5:contractGuarantee/ns5:part",
          "//contractGuarantee/part"
        ], namespaces)&.to_f,
        
        application_guarantee_part: find_text_with_namespaces(doc, [
          "//ns5:applicationGuarantee/ns5:part",
          "//applicationGuarantee/part"
        ], namespaces)&.to_f
      }.compact
    end
  end
end 