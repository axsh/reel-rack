require 'spec_helper'
require 'net/http'
require 'rack/lint'
require 'rack/head'

describe Reel::Rack::Server do
  let(:host) { "127.0.0.1" }
  let(:port) { 30000 }
  let(:headers) { {"Content-Type" => "text/plain", "Content-Length" => body.length.to_s} }
  let(:body) { "hello world" }
  let(:uri) { URI("http://#{host}:#{port}/") }
  let(:http) { Net::HTTP.new(uri.host, uri.port) }
  let(:rack_app) { proc { [200, headers, [body]] } }

  subject do
    described_class.new(Rack::Lint.new(Rack::Head.new(rack_app)), :Host => host, :Port => port)
  end

  before do
    # Hax to wait for server to be started
    subject.inspect
  end

  after do
    subject.terminate
  end


  it "runs a basic Hello World app" do
    expect(http.request_get(uri.path).body).to eq body
  end

  it "success with basic HTTP methods" do
    expect(http.request_get(uri.path).body).to eq body
    expect(http.request_head(uri.path).body).to eq nil

    expect(http.send_request('POST', uri.path, "test").body).to eq body
    expect(http.send_request('PUT', uri.path, "test").body).to eq body
    expect(http.send_request('PATCH', uri.path, "test").body).to eq body
    expect(http.send_request('DELETE', uri.path).body).to eq body
  end

  it "disables chunked transfer if a Content-Length header is set" do
    expect(http.send_request('GET', uri.path, 'test')['content-length']).to_not eq nil
    expect(http.send_request('GET', uri.path, 'test')['transfer-encoding']).to_not eq 'chunked'
  end

  context "with no Content-Length header and the body is Enumerable" do
    let(:headers) { {"Content-Type" => "text/plain"} }

    it "sends a chunked transfer response if there is no Content-Length header and the body is Enumerable" do
      expect(http.send_request('GET', uri.path, 'test')['content-length']).to eq nil
      expect(http.send_request('GET', uri.path, 'test')['transfer-encoding']).to eq 'chunked'
    end
  end

  context "works with Rack::Builder" do
    let(:rack_app) {
      headers = {"Content-Type" => "text/plain"}
      Rack::Builder.app {
        map("/path1") { run proc { [200, headers.merge("Content-Length"=>"5"), ["path1"]] } }
        run proc { [200, headers.merge("Content-Length"=>"3"), ["any"]] }
      }
    }

    it "routes the requests both exact path and any path" do
      expect(http.send_request('GET', "/path1", 'test').body).to eq "path1"
      expect(http.send_request('GET', "/", 'test').body).to eq "any"
      expect(http.send_request('GET', "/path2", 'test').body).to eq "any"
    end
  end
end
