# frozen_string_literal: true

require 'logger'

module OxTenderAbstract
  # Simple logging module for the library
  module ContextualLogger
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def logger
        @logger ||= OxTenderAbstract.configuration.logger
      end
    end

    def logger
      self.class.logger
    end

    def log_debug(message)
      logger.debug("[#{self.class.name}] #{message}")
    end

    def log_info(message)
      logger.info("[#{self.class.name}] #{message}")
    end

    def log_warn(message)
      logger.warn("[#{self.class.name}] #{message}")
    end

    def log_error(message)
      logger.error("[#{self.class.name}] #{message}")
    end

    def log_fatal(message)
      logger.fatal("[#{self.class.name}] #{message}")
    end
  end
end
