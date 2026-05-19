if Doorkeeper::Application.count.zero?
  Doorkeeper::Application.create(name: "Facebook-API", redirect_uri: "", scopes: "")
end


# Create test user for login API
puts "Creating test user..."
test_user = User.find_or_create_by!(email: 'test@example.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
end
puts "Test user created: #{test_user.email}"

# Create OAuth application for API access
puts "Creating OAuth application..."
oauth_app = Doorkeeper::Application.find_or_create_by!(name: 'API Test Client') do |app|
  app.redirect_uri = 'https://example.com/callback'
  app.scopes = ''
end
puts "OAuth application created:"
puts "  Client ID: #{oauth_app.uid}"
puts "  Client Secret: #{oauth_app.secret}"
puts "  Name: #{oauth_app.name}"

puts "\nLogin API is ready to use!"
puts "Use the following credentials for testing:"
puts "  Email: test@example.com"
puts "  Password: password123"
puts "  Client ID: #{oauth_app.uid}"