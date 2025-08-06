# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'openssl'
require 'zlib'
require 'stringio'
require 'zip'

module OxTenderAbstract
  # Archive processor for downloading and extracting archive files
  class ArchiveProcessor
    include ContextualLogger

    MAX_FILE_SIZE_BYTES = 100 * 1024 * 1024 # 100 MB in bytes
    MAX_RETRY_ATTEMPTS = 3
    RETRY_DELAY_SECONDS = 2

    def initialize
      # Archive processor initialization
    end

    # Download and extract archive data
    def download_and_extract(archive_url)
      return Result.failure('Empty archive URL') if archive_url.nil? || archive_url.empty?

      begin
        # Download archive to memory with retry logic
        download_result = download_with_retry(archive_url)
        return download_result if download_result.failure?

        content = download_result.data[:content]

        # Determine archive format by first bytes
        first_bytes = content[0..1].unpack1('H*')

        if first_bytes == '1f8b'
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
        elsif content[0..1] == 'PK'
          # This is already ZIP archive - parse directly
          zip_result = extract_zip_from_memory(content)

          Result.success({
                           files: zip_result,
                           total_size: download_result.data[:size],
                           compressed_size: nil,
                           file_count: zip_result.size
                         })
        else
          # Log first bytes for debugging
          log_error "Unknown archive format. First 10 bytes: #{content[0..9].unpack1('H*')}"
          Result.failure('Unknown archive format (not GZIP and not ZIP)')
        end
      rescue StandardError => e
        log_error "Archive processing error: #{e.message}"
        log_error e.backtrace.first(3).join("\n") if e.backtrace
        Result.failure("Archive processing error: #{e.message}")
      end
    end

    private

    def download_with_retry(archive_url)
      attempt = 1
      last_error = nil

      while attempt <= MAX_RETRY_ATTEMPTS
        begin
          log_info "Download attempt #{attempt}/#{MAX_RETRY_ATTEMPTS} for archive"
          result = download_to_memory(archive_url)

          if result.success?
            log_info "Download successful on attempt #{attempt}"
            return result
          else
            last_error = result.error
            log_warn "Download attempt #{attempt} failed: #{last_error}"
          end
        rescue StandardError => e
          last_error = begin
            e.message.force_encoding('UTF-8').scrub
          rescue StandardError
            e.message.to_s
          end
          log_error "Download error details: #{e.class} - #{last_error}"
        end

        if attempt < MAX_RETRY_ATTEMPTS
          sleep_time = RETRY_DELAY_SECONDS * attempt
          log_info "Waiting #{sleep_time} seconds before retry..."
          sleep(sleep_time)
        end

        attempt += 1
      end

      Result.failure("Download failed after #{MAX_RETRY_ATTEMPTS} attempts. Last error: #{last_error}")
    end

    def download_to_memory(url)
      begin
        uri = URI.parse(url)
        # Check if URI is valid HTTP/HTTPS
        return Result.failure('Invalid URL: not HTTP/HTTPS') unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      rescue URI::InvalidURIError => e
        return Result.failure("Invalid URL: #{e.message}")
      end

      begin
        http = create_http_client(uri)

        request = Net::HTTP::Get.new(uri.request_uri)
        request['User-Agent'] = "OxTenderAbstract/#{OxTenderAbstract::VERSION}"
        request['individualPerson_token'] = OxTenderAbstract.configuration.token

        log_debug "Downloading archive from: #{url[0..100]}..."

        response = http.request(request)

        # Enhanced error handling with response details
        unless response.is_a?(Net::HTTPSuccess)
          error_msg = "HTTP error: #{response.code} #{response.message}"
          if response.body && !response.body.empty?
            # Log first part of response body for debugging - safely handle encoding
            begin
              body_preview = response.body.force_encoding('UTF-8').scrub[0..500]
              log_error "Response body preview: #{body_preview}"
              error_msg += ". Response: #{body_preview[0..100]}"
            rescue StandardError => e
              log_error "Response body encoding error: #{e.message}"
              error_msg += '. Response body unreadable (encoding issue)'
            end
          end
          return Result.failure(error_msg)
        end

        # Check for download blocking message in successful response - safely handle encoding
        begin
          response_text = response.body&.force_encoding('UTF-8')&.scrub
          if response_text&.include?('Скачивание архива по данной ссылке заблокировано')
            if OxTenderAbstract.configuration.auto_wait_on_block
              wait_time = OxTenderAbstract.configuration.block_wait_time
              log_error "Archive download blocked. Auto-waiting for #{wait_time} seconds..."

              # Показываем прогресс ожидания
              show_wait_progress(wait_time)

              log_info 'Wait completed, retrying download...'
              # Рекурсивно повторяем попытку после ожидания
              return download_to_memory(url)
            else
              # Возвращаем специальную ошибку блокировки для ручной обработки
              return Result.failure('Archive download blocked for 10 minutes',
                                    ArchiveBlockedError.new('Archive download blocked', 600))
            end
          end
        rescue StandardError => e
          log_error "Encoding error when checking for blocking message: #{e.message}"
          # Продолжаем обработку, так как это может быть просто архив
        end

        content = response.body
        size = content.bytesize

        if size > MAX_FILE_SIZE_BYTES
          return Result.failure("Archive too large: #{size} bytes (max: #{MAX_FILE_SIZE_BYTES})")
        end

        return Result.failure('Empty archive downloaded') if size == 0

        log_debug "Downloaded archive: #{size} bytes, content-type: #{response['content-type']}"

        Result.success({
                         content: content,
                         size: size,
                         content_type: response['content-type']
                       })
      rescue SocketError, Timeout::Error => e
        Result.failure("Network error: #{e.message}")
      rescue StandardError => e
        log_error "Download error details: #{e.class} - #{e.message}"
        Result.failure("Download error: #{e.message}")
      end
    end

    def create_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.verify_mode = OxTenderAbstract.configuration.ssl_verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = OxTenderAbstract.configuration.timeout_open
      http.read_timeout = OxTenderAbstract.configuration.timeout_read

      # Add debug logging for HTTP client configuration
      log_debug "HTTP client config: SSL=#{http.use_ssl?}, verify=#{http.verify_mode}, open_timeout=#{http.open_timeout}, read_timeout=#{http.read_timeout}"

      http
    end

    def decompress_gzip(gzip_content)
      log_debug 'Decompressing GZIP archive'

      gz = Zlib::GzipReader.new(StringIO.new(gzip_content))
      decompressed_content = gz.read
      gz.close

      log_debug "GZIP decompression: #{gzip_content.bytesize} -> #{decompressed_content.bytesize} bytes"

      Result.success({
                       content: decompressed_content,
                       compressed_size: gzip_content.bytesize,
                       decompressed_size: decompressed_content.bytesize
                     })
    rescue Zlib::GzipFile::Error => e
      log_error "GZIP decompression error: #{e.message}"
      Result.failure("GZIP decompression error: #{e.message}")
    rescue StandardError => e
      log_error "Decompression error: #{e.message}"
      Result.failure("Decompression error: #{e.message}")
    end

    def extract_zip_from_memory(zip_content)
      log_debug "Extracting ZIP archive from memory (#{zip_content.bytesize} bytes)"

      files = {}
      zip_io = StringIO.new(zip_content)

      Zip::File.open_buffer(zip_io) do |zip_file|
        zip_file.each do |entry|
          next if entry.directory?

          log_debug "Extracting file: #{entry.name} (#{entry.size} bytes)"

          begin
            content = entry.get_input_stream.read

            files[entry.name] = {
              content: content,
              size: entry.size,
              compressed_size: entry.compressed_size,
              crc: entry.crc
            }
          rescue StandardError => e
            log_error "Error extracting file #{entry.name}: #{e.message}"
            # Continue with other files instead of failing completely
          end
        end
      end

      log_debug "Extracted #{files.size} files from ZIP archive"
      files
    rescue Zip::Error => e
      log_error "ZIP extraction error: #{e.message}"
      raise ArchiveError, "ZIP extraction error: #{e.message}"
    rescue StandardError => e
      log_error "Archive extraction error: #{e.message}"
      log_error e.backtrace.first(3).join("\n") if e.backtrace
      raise ArchiveError, "Archive extraction error: #{e.message}"
    end

    # Show wait progress during API block
    def show_wait_progress(total_seconds)
      return if total_seconds <= 0

      log_info "Waiting #{total_seconds} seconds for API block to expire..."

      # Показываем прогресс каждые 30 секунд для больших интервалов
      if total_seconds > 60
        intervals = [30, 60, 120, 180, 300].select { |i| i < total_seconds }

        intervals.each do |interval|
          sleep(interval)
          remaining = total_seconds - interval
          total_seconds = remaining

          if remaining > 60
            log_info "Still waiting... #{remaining} seconds remaining (#{(remaining / 60.0).round(1)} minutes)"
          else
            log_info "Still waiting... #{remaining} seconds remaining"
          end
        end

        # Ждем оставшееся время
        sleep(total_seconds) if total_seconds > 0
      else
        # Для коротких интервалов просто ждем
        sleep(total_seconds)
      end

      log_info 'Wait period completed!'
    end
  end
end
