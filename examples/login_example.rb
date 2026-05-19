#!/usr/bin/env ruby
# Example script to demonstrate the login API

require 'net/http'
require 'uri'
require 'json'

class LoginExample
  def initialize(base_url = 'http://localhost:3000')
    @base_url = base_url
  end

  def login(email, password, client_id)
    uri = URI.parse("#{@base_url}/api/users/login")
    
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request.body = JSON.dump({
      email: email,
      password: password,
      client_id: client_id
    })

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    {
      status: response.code.to_i,
      body: JSON.parse(response.body) rescue response.body
    }
  end

  def create_user(email, password, client_id)
    uri = URI.parse("#{@base_url}/api/users")
    
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request.body = JSON.dump({
      email: email,
      password: password,
      client_id: client_id
    })

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    {
      status: response.code.to_i,
      body: JSON.parse(response.body) rescue response.body
    }
  end

  def run_examples
    puts "=== Login API Examples ===\n\n"

    # First, create a Doorkeeper application to get client_id
    puts "1. First, you need to create a Doorkeeper application:"
    puts "   rails console"
    puts "   app = Doorkeeper::Application.create!(name: 'Test App', redirect_uri: 'https://example.com')"
    puts "   puts app.uid # This is your client_id\n\n"

    puts "2. Example API calls (replace CLIENT_ID with your actual client_id):\n\n"

    puts "   a) Successful login:"
    puts "     POST /api/users/login"
    puts "     Body: {"
    puts "       \"email\": \"user@example.com\","
    puts "       \"password\": \"password123\","
    puts "       \"client_id\": \"CLIENT_ID\""
    puts "     }\n\n"

    puts "   b) Invalid credentials:"
    puts "     POST /api/users/login"
    puts "     Body: {"
    puts "       \"email\": \"wrong@example.com\","
    puts "       \"password\": \"wrongpassword\","
    puts "       \"client_id\": \"CLIENT_ID\""
    puts "     }"
    puts "     Response: 401 Unauthorized\n\n"

    puts "   c) Missing email:"
    puts "     POST /api/users/login"
    puts "     Body: {"
    puts "       \"password\": \"password123\","
    puts "       \"client_id\": \"CLIENT_ID\""
    puts "     }"
    puts "     Response: 400 Bad Request\n\n"

    puts "   d) Invalid email format:"
    puts "     POST /api/users/login"
    puts "     Body: {"
    puts "       \"email\": \"invalid-email\","
    puts "       \"password\": \"password123\","
    puts "       \"client_id\": \"CLIENT_ID\""
    puts "     }"
    puts "     Response: 400 Bad Request\n\n"

    puts "   e) Invalid client ID:"
    puts "     POST /api/users/login"
    puts "     Body: {"
    puts "       \"email\": \"user@example.com\","
    puts "       \"password\": \"password123\","
    puts "       \"client_id\": \"invalid_client_id\""
    puts "     }"
    puts "     Response: 403 Forbidden\n\n"

    puts "3. Security features demonstrated:"
    puts "   - Rate limiting (5 attempts per IP in 15 minutes)"
    puts "   - Account locking (after 10 failed attempts)"
    puts "   - Timing attack protection"
    puts "   - Input validation"
    puts "   - Secure token generation"
  end
end

if __FILE__ == $0
  example = LoginExample.new
  example.run_examples
end