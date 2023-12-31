# frozen_string_literal: true

require "ddtrace"
require "logger"
require "json"

module Datadog
  module Loggers
    class JSONFormatter < Logger::Formatter
      def self.call(severity, datetime, progname, msg)
        log_hash = base_log_hash(severity, datetime, progname)
        formatter = formatter_for(msg)
        formatter.format(log_hash, msg)

        yield(log_hash) if block_given?

        "#{log_hash.to_json}\r\n"
      end

      def self.base_log_hash(severity, datetime, progname)
        {
          dd: correlation_hash,
          timestamp: datetime.to_s,
          severity: severity.ljust(5).to_s,
          progname: progname.to_s
        }
      end

      def self.formatter_for(msg)
        case msg
        when Hash then HashFormatter
        when Exception then ExceptionFormatter
        when String then StringFormatter
        else DefaultFormatter
        end
      end

      def self.correlation_hash
        correlation = Datadog::Tracing.correlation
        {
          trace_id: correlation.trace_id&.to_s,
          span_id: correlation.span_id&.to_s,
          env: correlation.env&.to_s,
          service: correlation.service&.to_s,
          version: correlation.version&.to_s
        }
      end

      class HashFormatter
        def self.format(log_hash, msg)
          log_hash.merge!(msg)
        end
      end

      class ExceptionFormatter
        def self.format(log_hash, exception)
          log_hash.merge!(
            exception: exception,
            exception_message: exception.message,
            exception_backtrace: exception.backtrace
          )
        end
      end

      class StringFormatter
        def self.format(log_hash, msg)
          log_hash[:message] = msg.dup.force_encoding("utf-8")
        end
      end

      class DefaultFormatter
        def self.format(log_hash, msg)
          log_hash[:message] = msg.to_s
        end
      end
    end
  end
end
