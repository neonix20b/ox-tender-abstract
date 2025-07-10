# frozen_string_literal: true

module OxTenderAbstract
  # Result structure for API operations
  class Result
    attr_reader :success, :data, :error, :metadata

    def initialize(success:, data: nil, error: nil, metadata: {})
      @success = success
      @data = data
      @error = error
      @metadata = metadata
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    def self.success(data, metadata = {})
      new(success: true, data:, metadata:)
    end

    def self.failure(error, metadata = {})
      new(success: false, error:, metadata:)
    end
  end
end
