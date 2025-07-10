# frozen_string_literal: true

RSpec.describe OxTenderAbstract::Client do
  let(:token) { 'test_token' }
  subject(:client) { described_class.new(token:) }

  before do
    OxTenderAbstract.configure do |config|
      config.logger = Logger.new(StringIO.new)
    end
  end

  after { OxTenderAbstract.reset_configuration! }

  describe '#initialize' do
    context 'with valid token' do
      it 'creates client instance' do
        expect(client).to be_an_instance_of(described_class)
      end
    end

    context 'without token' do
      it 'raises AuthenticationError' do
        expect { described_class.new(token: nil) }
          .to raise_error(OxTenderAbstract::AuthenticationError, /Token cannot be empty/)
      end
    end

    context 'with empty token' do
      it 'raises AuthenticationError' do
        expect { described_class.new(token: '') }
          .to raise_error(OxTenderAbstract::AuthenticationError, /Token cannot be empty/)
      end
    end

    context 'using global configuration token' do
      before do
        OxTenderAbstract.configure { |config| config.token = 'global_token' }
      end

      it 'uses token from configuration' do
        client_without_token = described_class.new
        expect(client_without_token.instance_variable_get(:@token)).to eq('global_token')
      end
    end
  end

  describe '#get_docs_by_region' do
    let(:params) do
      {
        org_region: '77',
        subsystem_type: 'PRIZ',
        document_type: 'tender',
        exact_date: '2024-01-01'
      }
    end

    context 'with valid parameters' do
      before do
        allow(client).to receive(:execute_soap_request)
          .and_return(OxTenderAbstract::Result.success(archive_urls: ['http://example.com/archive.zip']))
      end

      it 'calls execute_soap_request with correct parameters' do
        expected_message = {
          'get-docs-by-org-region-request' => {
            'org-region' => '77',
            'subsystem-type' => 'PRIZ',
            'document-type' => 'tender',
            'date-from' => '2024-01-01',
            'date-to' => '2024-01-01'
          }
        }

        expect(client).to receive(:execute_soap_request)
          .with(:get_docs_by_org_region, expected_message)

        client.get_docs_by_region(**params)
      end
    end

    context 'with invalid parameters' do
      it 'raises ConfigurationError for nil org_region' do
        expect { client.get_docs_by_region(**params.merge(org_region: nil)) }
          .to raise_error(OxTenderAbstract::ConfigurationError, /Parameter org_region cannot be blank/)
      end

      it 'raises ConfigurationError for empty exact_date' do
        expect { client.get_docs_by_region(**params.merge(exact_date: '')) }
          .to raise_error(OxTenderAbstract::ConfigurationError, /Parameter exact_date cannot be blank/)
      end
    end
  end

  describe '#get_docs_by_reestr_number' do
    let(:params) do
      {
        reestr_number: '123456',
        subsystem_type: 'PRIZ'
      }
    end

    context 'with valid parameters' do
      before do
        allow(client).to receive(:execute_soap_request)
          .and_return(OxTenderAbstract::Result.success(archive_urls: []))
      end

      it 'calls execute_soap_request with correct parameters' do
        expected_message = {
          'get-docs-by-reestr-number-request' => {
            'reestr-number' => '123456',
            'subsystem-type' => 'PRIZ'
          }
        }

        expect(client).to receive(:execute_soap_request)
          .with(:get_docs_by_reestr_number, expected_message)

        client.get_docs_by_reestr_number(**params)
      end
    end

    context 'with invalid parameters' do
      it 'raises ConfigurationError for nil reestr_number' do
        expect { client.get_docs_by_reestr_number(**params.merge(reestr_number: nil)) }
          .to raise_error(OxTenderAbstract::ConfigurationError, /Parameter reestr_number cannot be blank/)
      end
    end
  end

  describe '#download_archive_data' do
    let(:archive_url) { 'http://example.com/archive.zip' }
    let(:archive_processor) { instance_double(OxTenderAbstract::ArchiveProcessor) }
    let(:result) { OxTenderAbstract::Result.success(files: {}) }

    before do
      allow(OxTenderAbstract::ArchiveProcessor).to receive(:new).and_return(archive_processor)
      allow(archive_processor).to receive(:download_and_extract).and_return(result)
    end

    it 'delegates to archive processor' do
      expect(archive_processor).to receive(:download_and_extract).with(archive_url)
      client.download_archive_data(archive_url)
    end
  end

  describe '#parse_xml_document' do
    let(:xml_content) { '<xml>content</xml>' }
    let(:xml_parser) { instance_double(OxTenderAbstract::XmlParser) }
    let(:result) { OxTenderAbstract::Result.success(content: {}) }

    before do
      allow(OxTenderAbstract::XmlParser).to receive(:new).and_return(xml_parser)
      allow(xml_parser).to receive(:parse).and_return(result)
    end

    it 'delegates to xml parser' do
      expect(xml_parser).to receive(:parse).with(xml_content)
      client.parse_xml_document(xml_content)
    end
  end

  describe '#search_tenders' do
    let(:params) do
      {
        org_region: '77',
        exact_date: '2024-01-01'
      }
    end

    context 'when API returns no archives' do
      before do
        allow(client).to receive(:get_docs_by_region)
          .and_return(OxTenderAbstract::Result.success(archive_urls: []))
      end

      it 'returns success with empty tenders' do
        result = client.search_tenders(**params)

        expect(result).to be_success
        expect(result.data[:tenders]).to eq([])
        expect(result.data[:total_archives]).to eq(0)
        expect(result.data[:total_files]).to eq(0)
      end
    end

    context 'when API call fails' do
      before do
        allow(client).to receive(:get_docs_by_region)
          .and_return(OxTenderAbstract::Result.failure('API Error'))
      end

      it 'returns the failure result' do
        result = client.search_tenders(**params)

        expect(result).to be_failure
        expect(result.error).to eq('API Error')
      end
    end

    context 'with successful workflow' do
      let(:archive_url) { 'http://example.com/archive.zip' }
      let(:xml_content) { '<tender><reestr-number>123</reestr-number></tender>' }

      before do
        allow(client).to receive(:get_docs_by_region)
          .and_return(OxTenderAbstract::Result.success(archive_urls: [archive_url]))

        allow(client).to receive(:download_archive_data)
          .and_return(OxTenderAbstract::Result.success(
                        files: { 'tender.xml' => { content: xml_content } }
                      ))

        allow(client).to receive(:parse_xml_document)
          .and_return(OxTenderAbstract::Result.success(
                        document_type: :tender,
                        content: { reestr_number: '123', name: 'Test Tender' }
                      ))
      end

      it 'processes complete workflow successfully' do
        result = client.search_tenders(**params)

        expect(result).to be_success
        expect(result.data[:tenders].size).to eq(1)
        expect(result.data[:tenders].first[:reestr_number]).to eq('123')
        expect(result.data[:total_archives]).to eq(1)
        expect(result.data[:total_files]).to eq(1)
      end

      it 'adds metadata to tender data' do
        result = client.search_tenders(**params)

        tender = result.data[:tenders].first
        expect(tender[:source_file]).to eq('tender.xml')
        expect(tender[:archive_url]).to eq(archive_url)
        expect(tender[:processed_at]).to be_a(Time)
      end
    end
  end

  describe 'error handling in SOAP requests' do
    before do
      allow(client).to receive(:create_soap_client).and_raise(StandardError, 'Connection failed')
    end

    it 'handles general errors gracefully' do
      result = client.get_docs_by_region(
        org_region: '77',
        exact_date: '2024-01-01'
      )

      expect(result).to be_failure
      expect(result.error).to include('Request error: Connection failed')
    end
  end
end
