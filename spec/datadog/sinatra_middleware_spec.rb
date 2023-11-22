# frozen_string_literal: true

require "spec_helper"
require "rack/test"
require "datadog/sinatra_middleware"

RSpec.describe Datadog::SinatraMiddleware do
  let(:app) { ->(_env) { [status_code, { "Content-Type" => "text/html" }, ["Response"]] } }
  let(:env) { Rack::MockRequest.env_for("/test") }
  let(:logger) { instance_double("Logger") }
  let(:middleware) { described_class.new(app, logger) }
  let(:status_code) { 200 }

  before do
    allow(logger).to receive(:info)
  end

  describe "#call" do
    context "when making a GET request" do
      let(:env) { Rack::MockRequest.env_for("/test?foo=bar", method: "GET") }

      it "logs GET requests" do
        middleware.call(env)
        expect(logger).to have_received(:info).with(hash_including(method: "GET"))
      end
    end

    context "when making a POST request" do
      let(:env) { Rack::MockRequest.env_for("/test", method: "POST", params: { foo: "bar" }) }

      it "logs POST requests with parameters" do
        middleware.call(env)
        expect(logger).to have_received(:info)
          .with(hash_including(method: "POST"))
          .with(hash_not_including(params: { "foo" => "bar" }))
      end
    end

    context "when the response is an error" do
      let(:status_code) { 500 }
      let(:env) { Rack::MockRequest.env_for("/error") }

      it "logs the error status code" do
        middleware.call(env)
        expect(logger).to have_received(:info).with(hash_including(status: 500))
      end
    end

    context "when request contains custom headers" do
      let(:env) { Rack::MockRequest.env_for("/test", { "HTTP_CUSTOM_HEADER" => "CustomValue" }) }

      it "logs requests with custom headers" do
        middleware.call(env)
        expect(logger).to have_received(:info).with(hash_not_including(headers: include("Custom-Header")))
      end
    end

    context "when response content type is JSON" do
      let(:app) { ->(_env) { [200, { "Content-Type" => "application/json" }, ['{"message":"OK"}']] } }

      it "logs JSON content type responses" do
        middleware.call(env)
        expect(logger).to have_received(:info).with(hash_including(format: "application/json"))
      end
    end

    context "when request has multiple query parameters" do
      let(:env) { Rack::MockRequest.env_for("/test?foo=bar&baz=qux") }

      it "logs multiple query parameters" do
        middleware.call(env)
        expect(logger).to have_received(:info).with(hash_including(params: include("foo", "baz")))
      end
    end

    context "when response is a redirect" do
      let(:status_code) { 302 }
      let(:env) { Rack::MockRequest.env_for("/redirect") }

      it "logs redirect status code" do
        middleware.call(env)
        expect(logger).to have_received(:info).with(hash_including(status: 302))
      end
    end
  end
end
