# frozen_string_literal: true

RSpec.describe OxTenderAbstract::Configuration do
  subject(:config) { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(config.token).to be_nil
      expect(config.timeout_open).to eq(30)
      expect(config.timeout_read).to eq(120)
      expect(config.ssl_verify).to be false
      expect(config.wsdl_url).to eq(OxTenderAbstract::DocumentTypes::API_CONFIG[:wsdl])
      expect(config.logger).to be_a(Logger)
    end
  end

  describe '#valid?' do
    it 'returns false when token is nil' do
      config.token = nil
      expect(config.valid?).to be false
    end

    it 'returns false when token is empty' do
      config.token = ''
      expect(config.valid?).to be false
    end

    it 'returns true when token is present' do
      config.token = 'valid_token'
      expect(config.valid?).to be true
    end
  end

  describe '#token_from_file' do
    let(:temp_file) { Tempfile.new('token') }

    after { temp_file.unlink }

    it 'returns nil for non-existent file' do
      expect(config.token_from_file('/non/existent/file')).to be_nil
    end

    it 'returns nil for empty file' do
      temp_file.write('')
      temp_file.close
      expect(config.token_from_file(temp_file.path)).to be_nil
    end

    it 'returns token content from file' do
      token_content = 'test_token_content'
      temp_file.write(token_content)
      temp_file.close
      expect(config.token_from_file(temp_file.path)).to eq(token_content)
    end

    it 'strips whitespace from token content' do
      token_content = "  test_token_content  \n"
      temp_file.write(token_content)
      temp_file.close
      expect(config.token_from_file(temp_file.path)).to eq('test_token_content')
    end
  end

  describe 'attribute accessors' do
    it 'allows setting and getting token' do
      config.token = 'new_token'
      expect(config.token).to eq('new_token')
    end

    it 'allows setting and getting timeout_open' do
      config.timeout_open = 60
      expect(config.timeout_open).to eq(60)
    end

    it 'allows setting and getting timeout_read' do
      config.timeout_read = 300
      expect(config.timeout_read).to eq(300)
    end

    it 'allows setting and getting ssl_verify' do
      config.ssl_verify = true
      expect(config.ssl_verify).to be true
    end

    it 'allows setting and getting wsdl_url' do
      config.wsdl_url = 'https://example.com/wsdl'
      expect(config.wsdl_url).to eq('https://example.com/wsdl')
    end

    it 'allows setting and getting logger' do
      custom_logger = Logger.new(STDERR)
      config.logger = custom_logger
      expect(config.logger).to eq(custom_logger)
    end
  end
end
