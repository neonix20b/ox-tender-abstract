# frozen_string_literal: true

module OxTenderAbstract
  # Document types and constants for Zakupki API
  module DocumentTypes
    # Supported subsystem types
    SUBSYSTEM_TYPES = %w[
      PRIZ RPEC RPGZ RJ RDI BTK RPKLKP RPNZ RGK EA UR REC RPP RVP RRK RRA
      RNP RKPO PPRF615 RD615 LKOK OZ OD223 RD223 MSP223 IPVP223 TRU223
      RJ223 RPP223 RPZ223 RI223 RZ223 OV223 TPOZ223 POZ223 RNP223 POM223 ZC
    ].freeze

    # Document types for 44-FZ (federal law)
    DOCUMENT_TYPES_44FZ = %w[
      TENDER_PLAN TENDER_TERMS CONTRACT_PLAN TENDER_PROTOCOL
      CONTRACT_EXECUTION_REPORT TENDER_NOTICE TENDER_DOCUMENTATION
    ].freeze

    # Electronic notification types for 44-FZ
    ELECTRONIC_NOTIFICATION_TYPES_44FZ = %w[
      epNotificationEF2020 epNotificationEF epNotificationOK2020
      epNotificationEP2020 epNotificationZK2020 epNotificationZP2020
      epNotificationISM2020 fcsNotificationEF fcsNotificationOK
      fcsNotificationEP fcsNotificationZK fcsNotificationZP
      fcsNotificationISM fcsPlacement fcsPlacementResult
    ].freeze

    # Electronic notification types for 223-FZ
    ELECTRONIC_NOTIFICATION_TYPES_223FZ = %w[
      epNotification223 notification223 purchaseNotice223
      purchaseNoticeEA223 purchaseNoticeZK223 purchaseNoticeZP223
      purchaseNoticeOK223 purchaseNoticeIS223 contractNotice223
      contractExecutionNotice223 purchasePlan223
    ].freeze

    # Electronic notification types for regional and municipal
    ELECTRONIC_NOTIFICATION_TYPES_REGIONAL = %w[
      epNotificationRP epNotificationRPGZ notificationRP
      notificationRPGZ purchaseNoticeRP purchaseNoticeRPGZ
      contractNoticeRP contractNoticeRPGZ
    ].freeze

    # All supported electronic notification types
    ELECTRONIC_NOTIFICATION_TYPES = (
      ELECTRONIC_NOTIFICATION_TYPES_44FZ +
      ELECTRONIC_NOTIFICATION_TYPES_223FZ +
      ELECTRONIC_NOTIFICATION_TYPES_REGIONAL
    ).freeze

    # Default settings
    DEFAULT_SUBSYSTEM = 'PRIZ'
    DEFAULT_DOCUMENT_TYPE = 'epNotificationEF2020'

    # Subsystem descriptions
    SUBSYSTEM_DESCRIPTIONS = {
      'PRIZ' => '44-ФЗ - Основные закупки федеральных органов',
      'OD223' => '223-ФЗ - Закупки отдельных видов юридических лиц',
      'RD223' => '223-ФЗ - Реестр договоров',
      'RPEC' => 'Закупки субъектов РФ',
      'RPGZ' => 'Муниципальные закупки',
      'RGK' => 'Закупки государственных корпораций',
      'BTK' => 'Закупки бюджетных, автономных учреждений',
      'UR' => 'Закупки субъектов естественных монополий',
      'RJ' => 'Закупки для нужд судебной системы',
      'RDI' => 'Закупки для нужд дошкольных образовательных учреждений',
      'RPKLKP' => 'Закупки для нужд подведомственных Калининградской области',
      'RPNZ' => 'Закупки для нужд образовательных учреждений НЗО',
      'EA' => 'Электронные аукционы',
      'REC' => 'Реестр недобросовестных поставщиков',
      'RPP' => 'Реестр поставщиков',
      'RVP' => 'Реестр внутренних поставщиков',
      'RRK' => 'Реестр результатов контроля',
      'RRA' => 'Реестр результатов аудита',
      'RNP' => 'Реестр нарушений при проведении закупок',
      'RKPO' => 'Реестр контрольно-проверочных организаций'
    }.freeze

    # Get appropriate document types for subsystem
    def self.document_types_for_subsystem(subsystem_type)
      case subsystem_type
      when 'PRIZ', 'RPEC', 'RPGZ', 'RGK', 'BTK', 'UR', 'RJ', 'RDI'
        ELECTRONIC_NOTIFICATION_TYPES_44FZ
      when 'OD223', 'RD223'
        ELECTRONIC_NOTIFICATION_TYPES_223FZ + ELECTRONIC_NOTIFICATION_TYPES_44FZ
      when /RP/
        ELECTRONIC_NOTIFICATION_TYPES_REGIONAL + ELECTRONIC_NOTIFICATION_TYPES_44FZ
      else
        ELECTRONIC_NOTIFICATION_TYPES_44FZ
      end
    end

    # Check if subsystem supports document type
    def self.subsystem_supports_document_type?(subsystem_type, document_type)
      document_types_for_subsystem(subsystem_type).include?(document_type)
    end

    # Get description for subsystem
    def self.description_for_subsystem(subsystem_type)
      SUBSYSTEM_DESCRIPTIONS[subsystem_type] || "Подсистема #{subsystem_type}"
    end

    # API configuration
    API_CONFIG = {
      wsdl: 'https://int44.zakupki.gov.ru/eis-integration/services/getDocsIP?wsdl',
      timeout: {
        open: 30,
        read: 120
      },
      ssl_verify: false
    }.freeze
  end
end
