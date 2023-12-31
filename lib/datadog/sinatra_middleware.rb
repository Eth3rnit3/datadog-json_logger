# frozen_string_literal: true

require "uri"
require "json"

module Rack
  class CommonLogger
    def log(_env, _status, _response_headers, _began_at)
      # Disable default rack logger output
      nil
    end
  end
end

module Datadog
  class SinatraMiddleware
    attr_reader :app, :logger

    def initialize(app, logger)
      @app = app
      @logger = logger
    end

    def call(env)
      request = Rack::Request.new(env)
      start_time = Time.now

      status, headers, body = safely_process_request(env)
      end_time = Time.now

      log_request(request, env, status, headers, start_time, end_time)

      [status, headers, body]
    rescue StandardError => e
      handle_exception(e)
    end

    private

    def safely_process_request(env)
      app.call(env)
    rescue StandardError
      [500, { "Content-Type" => "text/html" }, ["Internal Server Error"]]
    end

    def log_request(request, env, status, headers, start_time, end_time)
      log_data = {
        request: true,
        request_ip: request.ip,
        method: request.request_method,
        controller: env["sinatra.controller_name"],
        action: env["sinatra.action_name"],
        path: request.path,
        params: parse_query(request.query_string),
        status: status,
        format: headers["Content-Type"],
        duration: calculate_duration(start_time, end_time)
      }

      logger.info(log_data)
    end

    def calculate_duration(start_time, end_time)
      ((end_time - start_time) * 1000).round # Duration in milliseconds
    end

    def parse_query(query_string)
      URI.decode_www_form(query_string).to_h
    end

    def handle_exception(exception)
      logger.error(
        exception: exception.class.name,
        exception_message: exception.message,
        exception_backtrace: exception.backtrace
      )

      raise exception
    end
  end
end
