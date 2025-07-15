# frozen_string_literal: true

RSpec.describe OxTenderAbstract::XmlParser do
  let(:parser) { described_class.new }

  before do
    OxTenderAbstract.configure do |config|
      config.logger = Logger.new(StringIO.new)
    end
  end

  after { OxTenderAbstract.reset_configuration! }

  describe '#parse' do
    context 'with invalid XML' do
      it 'returns failure for malformed XML' do
        result = parser.parse('<invalid><xml>')

        expect(result).to be_failure
        expect(result.error).to include('Invalid XML')
      end
    end

    context 'with empty XML' do
      it 'returns failure for empty content' do
        result = parser.parse('')

        expect(result).to be_failure
        expect(result.error).to include('Empty XML content')
      end
    end

    context 'with tender document' do
      let(:tender_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <ns3:export xmlns:ns3="http://zakupki.gov.ru/oos/export/1" xmlns:ns5="http://zakupki.gov.ru/oos/EPtypes/1" xmlns:ns4="http://zakupki.gov.ru/oos/common/1">
            <ns3:epNotificationEF2020>
              <ns5:commonInfo>
                <ns5:purchaseNumber>0123456789012345678</ns5:purchaseNumber>
                <ns5:purchaseObjectInfo>Test Tender Name</ns5:purchaseObjectInfo>
              </ns5:commonInfo>
              <ns5:notificationInfo>
                <ns5:contractConditionsInfo>
                  <ns5:maxPriceInfo>
                    <ns5:maxPrice>1000000.50</ns5:maxPrice>
                  </ns5:maxPriceInfo>
                </ns5:contractConditionsInfo>
              </ns5:notificationInfo>
              <ns5:purchaseResponsibleInfo>
                <ns5:responsibleOrgInfo>
                  <ns5:fullName>Test Organization</ns5:fullName>
                </ns5:responsibleOrgInfo>
                <ns5:responsibleInfo>
                  <ns5:contactPersonInfo>
                    <ns4:firstName>John</ns4:firstName>
                    <ns4:lastName>Doe</ns4:lastName>
                  </ns5:contactPersonInfo>
                  <ns5:contactEMail>john@example.com</ns5:contactEMail>
                  <ns5:contactPhone>+7-123-456-7890</ns5:contactPhone>
                </ns5:responsibleInfo>
              </ns5:purchaseResponsibleInfo>
              <ns5:attachmentsInfo>
                <ns4:attachmentInfo>
                  <ns4:fileName>document1.pdf</ns4:fileName>
                  <ns4:url>http://example.com/doc1.pdf</ns4:url>
                </ns4:attachmentInfo>
              </ns5:attachmentsInfo>
            </ns3:epNotificationEF2020>
          </ns3:export>
        XML
      end

      it 'successfully parses tender document' do
        result = parser.parse(tender_xml)

        expect(result).to be_success
        expect(result.data[:document_type]).to eq(:tender)
        expect(result.data[:content][:reestr_number]).to eq('0123456789012345678')
        expect(result.data[:content][:name]).to eq('Test Tender Name')
        expect(result.data[:content][:max_price]).to eq('1000000.50')
      end

      it 'extracts organization information' do
        result = parser.parse(tender_xml)

        content = result.data[:content]
        expect(content[:organization_name]).to eq('Test Organization')
      end

      it 'extracts contact information' do
        result = parser.parse(tender_xml)

        content = result.data[:content]
        expect(content[:contact_name]).to eq('John Doe')
        expect(content[:contact_phone]).to eq('+7-123-456-7890')
        expect(content[:contact_email]).to eq('john@example.com')
      end
    end

    context 'with tender document containing purchase objects' do
      let(:tender_with_objects_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <ns3:export xmlns:ns3="http://zakupki.gov.ru/oos/export/1" xmlns:ns5="http://zakupki.gov.ru/oos/EPtypes/1" xmlns:ns4="http://zakupki.gov.ru/oos/common/1" xmlns:ns2="http://zakupki.gov.ru/oos/base/1">
            <ns3:epNotificationEF2020>
              <ns5:commonInfo>
                <ns5:purchaseNumber>0373200592025000025</ns5:purchaseNumber>
                <ns5:purchaseObjectInfo>Электронный аукцион на поставку тумбы с ванной моечной</ns5:purchaseObjectInfo>
              </ns5:commonInfo>
              <ns5:notificationInfo>
                <ns5:purchaseObjectsInfo>
                  <ns5:notDrugPurchaseObjectsInfo>
                    <ns4:purchaseObject>
                      <ns4:sid>186548938</ns4:sid>
                      <ns4:externalSid>217455879-1616303245</ns4:externalSid>
                      <ns4:KTRU>
                        <ns2:code>25.99.11.132-00000001</ns2:code>
                        <ns2:name>Ванна моечная для пищеблока</ns2:name>
                        <ns2:versionId>108402</ns2:versionId>
                        <ns2:versionNumber>1</ns2:versionNumber>
                      </ns4:KTRU>
                      <ns4:name>Ванна моечная для пищеблока</ns4:name>
                      <ns4:OKEI>
                        <ns2:code>796</ns2:code>
                        <ns2:nationalCode>шт</ns2:nationalCode>
                        <ns2:name>Штука</ns2:name>
                      </ns4:OKEI>
                      <ns4:price>66500</ns4:price>
                      <ns4:quantity>
                        <ns4:value>10</ns4:value>
                      </ns4:quantity>
                      <ns4:sum>665000</ns4:sum>
                      <ns4:type>PRODUCT</ns4:type>
                      <ns4:hierarchyType>ND</ns4:hierarchyType>
                      <ns4:OKPD2>
                        <ns2:OKPDCode>25.99.11.132</ns2:OKPDCode>
                        <ns2:OKPDName>Ванны из нержавеющей стали</ns2:OKPDName>
                      </ns4:OKPD2>
                      <ns4:restrictionsInfo>
                        <ns4:isPreferenseRFPurchaseObjects>true</ns4:isPreferenseRFPurchaseObjects>
                      </ns4:restrictionsInfo>
                    </ns4:purchaseObject>
                    <ns4:totalSum>665000</ns4:totalSum>
                    <ns5:quantityUndefined>false</ns5:quantityUndefined>
                  </ns5:notDrugPurchaseObjectsInfo>
                </ns5:purchaseObjectsInfo>
              </ns5:notificationInfo>
            </ns3:epNotificationEF2020>
          </ns3:export>
        XML
      end

      it 'parses purchase objects successfully' do
        result = parser.parse(tender_with_objects_xml)

        expect(result).to be_success
        expect(result.data[:document_type]).to eq(:tender)

        content = result.data[:content]
        expect(content[:reestr_number]).to eq('0373200592025000025')
        expect(content[:title]).to eq('Электронный аукцион на поставку тумбы с ванной моечной')

        # Check purchase objects
        purchase_objects = content[:purchase_objects]
        expect(purchase_objects).to be_a(Hash)
        expect(purchase_objects[:objects_count]).to eq(1)
        expect(purchase_objects[:total_sum]).to eq('665000')
        expect(purchase_objects[:quantity_undefined]).to be false

        # Check first object details
        first_object = purchase_objects[:objects].first
        expect(first_object[:sid]).to eq('186548938')
        expect(first_object[:name]).to eq('Ванна моечная для пищеблока')
        expect(first_object[:product_name]).to eq('Ванна моечная для пищеблока')
        expect(first_object[:name_type]).to eq('product_name')
        expect(first_object[:price]).to eq('66500')
        expect(first_object[:quantity]).to eq(10)
        expect(first_object[:sum]).to eq('665000')
        expect(first_object[:type]).to eq('PRODUCT')

        # Check KTRU information
        expect(first_object[:ktru][:code]).to eq('25.99.11.132-00000001')
        expect(first_object[:ktru][:name]).to eq('Ванна моечная для пищеблока')

        # Check OKEI information
        expect(first_object[:okei][:code]).to eq('796')
        expect(first_object[:okei][:name]).to eq('Штука')

        # Check OKPD2 information
        expect(first_object[:okpd2][:code]).to eq('25.99.11.132')
        expect(first_object[:okpd2][:name]).to eq('Ванны из нержавеющей стали')

        # Check restrictions
        expect(first_object[:restrictions][:is_preference_rf]).to be true
      end

      it 'correctly identifies product names vs characteristics' do
        characteristic_xml = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <ns3:export xmlns:ns3="http://zakupki.gov.ru/oos/export/1" xmlns:ns5="http://zakupki.gov.ru/oos/EPtypes/1" xmlns:ns4="http://zakupki.gov.ru/oos/common/1" xmlns:ns2="http://zakupki.gov.ru/oos/base/1">
            <ns3:epNotificationEF2020>
              <ns5:commonInfo>
                <ns5:purchaseNumber>0373200593425000054</ns5:purchaseNumber>
              </ns5:commonInfo>
              <ns5:notificationInfo>
                <ns5:purchaseObjectsInfo>
                  <ns5:notDrugPurchaseObjectsInfo>
                    <ns4:purchaseObject>
                      <ns4:name>Реагенты сложные диагностические</ns4:name>
                      <ns4:OKPD2>
                        <ns2:OKPDCode>20.59.52.199</ns2:OKPDCode>
                        <ns2:OKPDName>Реагенты сложные диагностические</ns2:OKPDName>
                        <ns4:characteristics>
                          <ns4:characteristicsUsingTextForm>
                            <ns4:name>Соответствие требованиям ТЗ</ns4:name>
                            <ns4:type>1</ns4:type>
                          </ns4:characteristicsUsingTextForm>
                        </ns4:characteristics>
                      </ns4:OKPD2>
                      <ns4:price>1000</ns4:price>
                      <ns4:type>PRODUCT</ns4:type>
                    </ns4:purchaseObject>
                    <ns4:purchaseObject>
                      <ns4:KTRU>
                        <ns2:code>21.20.23.110-00005860</ns2:code>
                        <ns2:name>Скрытая кровь в кале ИВД, набор</ns2:name>
                      </ns4:KTRU>
                      <ns4:name>Скрытая кровь в кале ИВД, набор</ns4:name>
                      <ns4:characteristics>
                        <ns4:characteristicsUsingTextForm>
                          <ns4:name>Количество выполняемых тестов</ns4:name>
                          <ns4:type>2</ns4:type>
                        </ns4:characteristicsUsingTextForm>
                      </ns4:characteristics>
                      <ns4:price>2000</ns4:price>
                      <ns4:type>PRODUCT</ns4:type>
                    </ns4:purchaseObject>
                  </ns5:notDrugPurchaseObjectsInfo>
                </ns5:purchaseObjectsInfo>
              </ns5:notificationInfo>
            </ns3:epNotificationEF2020>
          </ns3:export>
        XML

        result = parser.parse(characteristic_xml)
        expect(result).to be_success

        objects = result.data[:content][:purchase_objects][:objects]
        expect(objects.size).to eq(2)

        # First object: name now contains actual product name (fixed!)
        first_object = objects.first
        expect(first_object[:name]).to eq('Реагенты сложные диагностические')
        expect(first_object[:name_type]).to eq('product_name')
        expect(first_object[:product_name]).to eq('Реагенты сложные диагностические')

        # Second object: name contains actual product name from KTRU
        second_object = objects.last
        expect(second_object[:name]).to eq('Скрытая кровь в кале ИВД, набор')
        expect(second_object[:name_type]).to eq('product_name')
        expect(second_object[:product_name]).to eq('Скрытая кровь в кале ИВД, набор')
      end

      it 'handles tender without purchase objects' do
        simple_xml = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <ns3:export xmlns:ns3="http://zakupki.gov.ru/oos/export/1" xmlns:ns5="http://zakupki.gov.ru/oos/EPtypes/1">
            <ns3:epNotificationEF2020>
              <ns5:commonInfo>
                <ns5:purchaseNumber>0123456789012345678</ns5:purchaseNumber>
                <ns5:purchaseObjectInfo>Simple Tender</ns5:purchaseObjectInfo>
              </ns5:commonInfo>
            </ns3:epNotificationEF2020>
          </ns3:export>
        XML

        result = parser.parse(simple_xml)

        expect(result).to be_success
        content = result.data[:content]
        expect(content[:purchase_objects]).to eq({})
      end
    end

    context 'with contract document' do
      let(:contract_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <contract>
            <reestr-number>987654</reestr-number>
            <name>Test Contract</name>
          </contract>
        XML
      end

      it 'detects contract document type' do
        result = parser.parse(contract_xml)

        expect(result).to be_success
        expect(result.data[:document_type]).to eq(:contract)
      end
    end

    context 'with organization document' do
      let(:organization_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <organization>
            <name>Test Org</name>
          </organization>
        XML
      end

      it 'detects organization document type' do
        result = parser.parse(organization_xml)

        expect(result).to be_success
        expect(result.data[:document_type]).to eq(:organization)
      end
    end

    context 'with unknown document' do
      let(:unknown_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <unknown-document>
            <data>Some data</data>
          </unknown-document>
        XML
      end

      it 'detects unknown document type' do
        result = parser.parse(unknown_xml)

        expect(result).to be_success
        expect(result.data[:document_type]).to eq(:unknown)
      end
    end
  end

  describe '#extract_attachments' do
    context 'with attachments in XML' do
      let(:xml_with_attachments) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <document>
            <attachments>
              <attachment>
                <name>document1.pdf</name>
                <url>http://example.com/doc1.pdf</url>
                <type>specification</type>
              </attachment>
              <attachment>
                <name>document2.doc</name>
                <url>http://example.com/doc2.doc</url>
                <type>protocol</type>
              </attachment>
            </attachments>
          </document>
        XML
      end

      it 'extracts all attachments' do
        result = parser.extract_attachments(xml_with_attachments)

        expect(result).to be_success
        attachments = result.data[:attachments]
        expect(attachments.size).to eq(2)

        expect(attachments[0][:name]).to eq('document1.pdf')
        expect(attachments[0][:url]).to eq('http://example.com/doc1.pdf')
        expect(attachments[0][:type]).to eq('specification')

        expect(attachments[1][:name]).to eq('document2.doc')
        expect(attachments[1][:url]).to eq('http://example.com/doc2.doc')
        expect(attachments[1][:type]).to eq('protocol')
      end
    end

    context 'without attachments' do
      let(:xml_without_attachments) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <document>
            <name>Test Document</name>
          </document>
        XML
      end

      it 'returns empty attachments array' do
        result = parser.extract_attachments(xml_without_attachments)

        expect(result).to be_success
        expect(result.data[:attachments]).to eq([])
      end
    end

    context 'with malformed XML' do
      it 'returns failure' do
        result = parser.extract_attachments('<invalid><xml>')

        expect(result).to be_failure
        expect(result.error).to include('XML parsing error')
      end
    end
  end

  describe '#detect_document_type' do
    it 'detects tender documents' do
      doc = Nokogiri::XML('<tender></tender>')
      expect(parser.send(:detect_document_type, doc)).to eq(:tender)
    end

    it 'detects contract documents' do
      doc = Nokogiri::XML('<contract></contract>')
      expect(parser.send(:detect_document_type, doc)).to eq(:contract)
    end

    it 'detects organization documents' do
      doc = Nokogiri::XML('<organization></organization>')
      expect(parser.send(:detect_document_type, doc)).to eq(:organization)
    end

    it 'returns unknown for unrecognized documents' do
      doc = Nokogiri::XML('<unknown></unknown>')
      expect(parser.send(:detect_document_type, doc)).to eq(:unknown)
    end
  end

  describe 'helper methods' do
    describe '#extract_date_from_text' do
      it 'extracts dates in various formats' do
        expect(parser.send(:extract_date_from_text, '2024-01-15')).to eq('2024-01-15')
        expect(parser.send(:extract_date_from_text, '15.01.2024')).to eq('15.01.2024')
        expect(parser.send(:extract_date_from_text, 'До 15.01.2024 включительно')).to eq('15.01.2024')
        expect(parser.send(:extract_date_from_text, 'no date here')).to be_nil
      end
    end

    describe '#extract_price_from_text' do
      it 'extracts numeric prices' do
        expect(parser.send(:extract_price_from_text, '1000000.50')).to eq('1000000.50')
        expect(parser.send(:extract_price_from_text, '1 000 000,50 руб.')).to eq('1000000.50')
        expect(parser.send(:extract_price_from_text, 'no price')).to be_nil
      end
    end
  end
end
