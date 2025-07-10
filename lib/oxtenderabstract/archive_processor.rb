# frozen_string_literal: true

require "net/http"
require "uri"
require "openssl"
require "zlib"
require "stringio"
require "zip"

module OxTenderAbstract
  # Archive processor for downloading and extracting archive files
  class ArchiveProcessor
    include ContextualLogger

    MAX_FILE_SIZE_BYTES = 100 * 1024 * 1024  # 100 MB in bytes
    
    def initialize
      # Archive processor initialization
    end

    # Download and extract archive data
    def download_and_extract(archive_url)
      return Result.failure("Empty archive URL") if archive_url.nil? || archive_url.empty?

      begin
        # Download archive to memory
        download_result = download_to_memory(archive_url)
        return download_result if download_result.failure?

        content = download_result.data[:content]

        # Determine archive format by first bytes
        first_bytes = content[0..1].unpack("H*").first

        if first_bytes == "1f8b"
          # This is GZIP archive - decompress GZIP, then ZIP
          gunzip_result = decompress_gzip(content)
          return gunzip_result if gunzip_result.failure?

          zip_result = extract_zip_from_memory(gunzip_result.data[:content])

          Result.success({
            files: zip_result,
            total_size: download_result.data[:size],
            compressed_size: gunzip_result.data[:compressed_size],
            file_count: zip_result.size
          })
        elsif content[0..1] == "PK"
          # This is already ZIP archive - parse directly
          zip_result = extract_zip_from_memory(content)

          Result.success({
            files: zip_result,
            total_size: download_result.data[:size],
            compressed_size: nil,
            file_count: zip_result.size
          })
        else
          Result.failure("Unknown archive format (not GZIP and not ZIP)")
        end
      rescue => e
        Result.failure("Archive processing error: #{e.message}")
      end
    end

    private

    def download_to_memory(url)
      begin
        uri = URI.parse(url)
        # Check if URI is valid HTTP/HTTPS
        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          return Result.failure("Invalid URL: not HTTP/HTTPS")
        end
      rescue URI::InvalidURIError => e
        return Result.failure("Invalid URL: #{e.message}")
      end

      begin
        http = create_http_client(uri)

        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "OxTenderAbstract/#{OxTenderAbstract::VERSION}"
        request["individualPerson_token"] = OxTenderAbstract.configuration.token

        log_debug "Downloading archive from: #{url}"

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          return Result.failure("HTTP error: #{response.code} #{response.message}")
        end

        content = response.body
        size = content.bytesize

        if size > MAX_FILE_SIZE_BYTES
          return Result.failure("Archive too large: #{size} bytes (max: #{MAX_FILE_SIZE_BYTES})")
        end

        log_debug "Downloaded archive: #{size} bytes"

        Result.success({
          content: content,
          size: size,
          content_type: response["content-type"]
        })
      rescue SocketError, Timeout::Error => e
        Result.failure("Network error: #{e.message}")
      rescue => e
        Result.failure("Download error: #{e.message}")
      end
    end

    def create_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.verify_mode = OxTenderAbstract.configuration.ssl_verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = OxTenderAbstract.configuration.timeout_open
      http.read_timeout = OxTenderAbstract.configuration.timeout_read
      http
    end

    def decompress_gzip(gzip_content)
      begin
        log_debug "Decompressing GZIP archive"
        
        gz = Zlib::GzipReader.new(StringIO.new(gzip_content))
        decompressed_content = gz.read
        gz.close

        Result.success({
          content: decompressed_content,
          compressed_size: gzip_content.bytesize,
          decompressed_size: decompressed_content.bytesize
        })
      rescue Zlib::GzipFile::Error => e
        Result.failure("GZIP decompression error: #{e.message}")
      rescue => e
        Result.failure("Decompression error: #{e.message}")
      end
    end

    def extract_zip_from_memory(zip_content)
      begin
        log_debug "Extracting ZIP archive from memory"
        
        files = {}
        zip_io = StringIO.new(zip_content)

        Zip::File.open_buffer(zip_io) do |zip_file|
          zip_file.each do |entry|
            next if entry.directory?
            
            log_debug "Extracting file: #{entry.name} (#{entry.size} bytes)"
            
            files[entry.name] = {
              content: entry.get_input_stream.read,
              size: entry.size,
              compressed_size: entry.compressed_size,
              crc: entry.crc
            }
          end
        end

        log_debug "Extracted #{files.size} files from ZIP archive"
        files
      rescue Zip::Error => e
        raise ArchiveError, "ZIP extraction error: #{e.message}"
      rescue => e
        raise ArchiveError, "Archive extraction error: #{e.message}"
      end
    end
  end
end 