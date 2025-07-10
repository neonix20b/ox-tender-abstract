# frozen_string_literal: true

RSpec.describe OxTenderAbstract do
  describe 'VERSION' do
    it 'has a version number' do
      expect(OxTenderAbstract::VERSION).not_to be nil
      expect(OxTenderAbstract::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe '.configure' do
    after { OxTenderAbstract.reset_configuration! }

    it 'allows configuration via block' do
      OxTenderAbstract.configure do |config|
        config.token = 'test_token'
        config.timeout_open = 60
      end

      expect(OxTenderAbstract.configuration.token).to eq('test_token')
      expect(OxTenderAbstract.configuration.timeout_open).to eq(60)
    end
  end

  describe '.client' do
    it 'creates a new client instance' do
      expect(OxTenderAbstract.client(token: 'test')).to be_a(OxTenderAbstract::Client)
    end
  end

  describe 'convenience methods' do
    let(:client_double) { instance_double(OxTenderAbstract::Client) }

    before do
      allow(OxTenderAbstract::Client).to receive(:new).and_return(client_double)
    end

    describe '.search_tenders' do
      it 'delegates to client instance' do
        expect(client_double).to receive(:search_tenders)
          .with(org_region: '77', exact_date: '2024-01-01')

        OxTenderAbstract.search_tenders(
          org_region: '77',
          exact_date: '2024-01-01',
          token: 'test'
        )
      end
    end

    describe '.get_docs_by_reestr_number' do
      it 'delegates to client instance' do
        expect(client_double).to receive(:get_docs_by_reestr_number)
          .with(reestr_number: '123456')

        OxTenderAbstract.get_docs_by_reestr_number(
          reestr_number: '123456',
          token: 'test'
        )
      end
    end
  end
end
