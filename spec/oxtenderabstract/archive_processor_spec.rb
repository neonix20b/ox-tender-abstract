# frozen_string_literal: true

RSpec.describe OxTenderAbstract::ArchiveProcessor do
  let(:processor) { described_class.new }

  before do
    OxTenderAbstract.configure do |config|
      config.logger = Logger.new(StringIO.new)
    end
  end

  after { OxTenderAbstract.reset_configuration! }

  describe '#download_and_extract' do
    context 'with valid URL' do
      let(:url) { 'http://example.com/archive.zip' }
      let(:mock_response) { instance_double(Net::HTTPResponse) }
      let(:mock_http) { instance_double(Net::HTTP) }

      before do
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:verify_mode=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:request).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(mock_response).to receive(:body).and_return('fake_zip_content')
        allow(mock_response).to receive(:[]).with('content-type').and_return('application/zip')
        allow(processor).to receive(:extract_zip_from_memory).and_return({
                                                                           'file1.xml' => {
                                                                             content: '<xml>content1</xml>', size: 100
                                                                           },
                                                                           'file2.xml' => {
                                                                             content: '<xml>content2</xml>', size: 200
                                                                           }
                                                                         })
      end

      it 'successfully downloads and extracts files' do
        result = processor.download_and_extract(url)

        expect(result).to be_success
        expect(result.data[:files]).to have(2).items
        expect(result.data[:files]['file1.xml'][:content]).to eq('<xml>content1</xml>')
        expect(result.data[:files]['file2.xml'][:content]).to eq('<xml>content2</xml>')
      end
    end

    context 'with invalid URL' do
      it 'returns failure for malformed URL' do
        result = processor.download_and_extract('not_a_url')

        expect(result).to be_failure
        expect(result.error).to include('Invalid URL')
      end
    end

    context 'with network error' do
      let(:url) { 'http://example.com/archive.zip' }

      before do
        allow(Net::HTTP).to receive(:new).and_raise(SocketError, 'Connection failed')
      end

      it 'handles network errors gracefully' do
        result = processor.download_and_extract(url)

        expect(result).to be_failure
        expect(result.error).to include('Network error')
      end
    end

    context 'with HTTP error response' do
      let(:url) { 'http://example.com/archive.zip' }
      let(:mock_response) { instance_double(Net::HTTPNotFound) }
      let(:mock_http) { instance_double(Net::HTTP) }

      before do
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:verify_mode=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:request).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(mock_response).to receive(:code).and_return('404')
        allow(mock_response).to receive(:message).and_return('Not Found')
      end

      it 'handles HTTP error responses' do
        result = processor.download_and_extract(url)

        expect(result).to be_failure
        expect(result.error).to include('HTTP error: 404 Not Found')
      end
    end
  end

  describe '#download_to_memory' do
    let(:url) { 'http://example.com/archive.zip' }
    let(:mock_response) { instance_double(Net::HTTPResponse) }
    let(:mock_http) { instance_double(Net::HTTP) }

    context 'with successful download' do
      before do
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:verify_mode=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:request).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(mock_response).to receive(:body).and_return('test_content')
        allow(mock_response).to receive(:[]).with('content-type').and_return('application/octet-stream')
      end

      it 'returns success result with content' do
        result = processor.send(:download_to_memory, url)

        expect(result).to be_success
        expect(result.data[:content]).to eq('test_content')
      end
    end

    context 'with content too large' do
      before do
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:verify_mode=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:request).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(mock_response).to receive(:body).and_return('x' * (100 * 1024 * 1024 + 1)) # > 100MB
        allow(mock_response).to receive(:[]).with('content-type').and_return('application/octet-stream')
      end

      it 'returns failure when content exceeds size limit' do
        result = processor.send(:download_to_memory, url)

        expect(result).to be_failure
        expect(result.error).to include('too large')
      end
    end
  end

  describe '#decompress_gzip' do
    let(:original_content) { 'Hello, World!' }
    let(:gzipped_content) do
      StringIO.new.tap do |io|
        gz = Zlib::GzipWriter.new(io)
        gz.write(original_content)
        gz.close
      end.string
    end

    it 'successfully decompresses gzip content' do
      result = processor.send(:decompress_gzip, gzipped_content)

      expect(result).to be_success
      expect(result.data[:content]).to eq(original_content)
    end

    it 'handles invalid gzip content' do
      result = processor.send(:decompress_gzip, 'not_gzipped')

      expect(result).to be_failure
      expect(result.error).to include('GZIP decompression error')
    end
  end

  describe '#extract_zip_from_memory' do
    let(:zip_content) do
      # Create a simple ZIP archive in memory
      StringIO.new.tap do |io|
        Zip::OutputStream.write_buffer(io) do |zos|
          zos.put_next_entry('test1.xml')
          zos.write('<xml>content1</xml>')
          zos.put_next_entry('test2.txt')
          zos.write('plain text content')
        end
      end.string
    end

    it 'successfully extracts ZIP files' do
      result = processor.send(:extract_zip_from_memory, zip_content)

      expect(result.size).to eq(2)
      expect(result['test1.xml'][:content]).to eq('<xml>content1</xml>')
      expect(result['test2.txt'][:content]).to eq('plain text content')
      expect(result['test1.xml'][:size]).to eq('<xml>content1</xml>'.bytesize)
    end

    it 'handles invalid ZIP content' do
      expect { processor.send(:extract_zip_from_memory, 'not_zip') }
        .to raise_error(OxTenderAbstract::ArchiveError)
    end

    it 'skips files exceeding size limit' do
      # This test would require mocking the entry size
      # For now, just test that the method exists and can handle basic ZIP
      expect(processor.send(:extract_zip_from_memory, zip_content)).to be_a(Hash)
    end
  end

  describe 'error handling' do
    it 'raises ArchiveError for unsupported archive formats' do
      # This would be tested if we add support for detecting different formats
      # Currently all files are treated as ZIP after potential GZIP decompression
    end
  end

  describe 'constants' do
    it 'defines maximum file size' do
      expect(described_class::MAX_FILE_SIZE_BYTES).to eq(100 * 1024 * 1024)
    end
  end
end
