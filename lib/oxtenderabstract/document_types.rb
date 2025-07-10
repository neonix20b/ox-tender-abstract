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

    # Electronic notification types
    ELECTRONIC_NOTIFICATION_TYPES = %w[
      epNotificationEF2020 epNotificationEF epNotificationOK2020
      epNotificationEP2020 epNotificationZK2020 epNotificationZP2020
      epNotificationISM2020 fcsNotificationEF fcsNotificationOK
      fcsNotificationEP fcsNotificationZK fcsNotificationZP
      fcsNotificationISM fcsPlacement fcsPlacementResult
    ].freeze

    # Default settings
    DEFAULT_SUBSYSTEM = 'PRIZ'
    DEFAULT_DOCUMENT_TYPE = 'epNotificationEF2020'

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
