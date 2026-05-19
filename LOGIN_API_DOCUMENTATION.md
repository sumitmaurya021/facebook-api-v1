# Secure Login API Documentation

## Overview
A secure login method has been added to the Users Controller with multiple security features including rate limiting, account locking, and protection against timing attacks.

## Endpoint

### POST /api/users/login

Authenticates a user and returns an access token.

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| email | string | Yes | User's email address |
| password | string | Yes | User's password |
| client_id | string | Yes | OAuth client application ID |

#### Request Example
```json
{
  "email": "user@example.com",
  "password": "password123",
  "client_id": "your_client_app_uid"
}
```

#### Response (Success - 200 OK)
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "access_token": "o7E78NkO_6HaHZ9TQJkpTFnpbFtne_6dqqK6K7DxluQ",
    "token_type": "bearer",
    "expires_in": 7200,
    "refresh_token": "abbc711652b0a0a95ec3d52b7ca89e3ba9fe43847ce3a2a6fcf09c478fb7914c",
    "created_at": 1779196833
  }
}
```

#### Error Responses

1. **400 Bad Request** - Missing required parameters or invalid email format
```json
{
  "error": "Email and password are required"
}
```

```json
{
  "error": "Invalid email format"
}
```

2. **401 Unauthorized** - Invalid credentials
```json
{
  "error": "Invalid email or password"
}
```

3. **403 Forbidden** - Invalid client ID or account locked
```json
{
  "error": "Invalid client ID"
}
```

```json
{
  "error": "Account is locked. Please contact support."
}
```

4. **429 Too Many Requests** - Rate limit exceeded
```json
{
  "error": "Too many login attempts. Please try again later."
}
```

## Security Features

### 1. Rate Limiting
- Limits to 5 login attempts per IP address within 15 minutes
- Prevents brute force attacks

### 2. Account Locking
- Locks user account after 10 failed login attempts
- Uses Devise's lockable module
- Account remains locked until manually unlocked

### 3. Timing Attack Protection
- Always validates password (even for non-existent users)
- Prevents attackers from determining valid emails via response time

### 4. Input Validation
- Validates email format using RFC-compliant regex
- Checks for required parameters
- Trims and downcases email addresses

### 5. Token Security
- Uses Doorkeeper for OAuth 2.0 token management
- Generates secure refresh tokens using `SecureRandom.hex(32)`
- Sets appropriate token expiration

## Setup Requirements

### 1. Database Migrations
The following columns have been added to the users table:
- `sign_in_count` (integer)
- `current_sign_in_at` (datetime)
- `last_sign_in_at` (datetime)
- `current_sign_in_ip` (string)
- `last_sign_in_ip` (string)
- `failed_attempts` (integer)
- `unlock_token` (string)
- `locked_at` (datetime)

### 2. Devise Configuration
The User model has been updated to include the `:lockable` module:
```ruby
devise :database_authenticatable, :registerable,
       :recoverable, :rememberable, :validatable,
       :lockable
```

### 3. Routes
The login endpoint has been added to the routes:
```ruby
namespace :api do
  resources :users, only: [:create] do
    collection do
      post :login
    end
  end
end
```

## Testing

### Running Tests
```bash
# Run all tests
rails test

# Run specific login tests
rails test test/controllers/api/users_controller_test.rb
```

### Test Coverage
The tests cover:
- Successful login with valid credentials
- Failed login with invalid email/password
- Missing required parameters
- Invalid client ID
- Invalid email format
- Account locking after multiple failed attempts

## Usage Example

### Using cURL
```bash
curl -X POST http://localhost:3000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123",
    "client_id": "your_client_app_uid"
  }'
```

### Using JavaScript (Fetch API)
```javascript
const response = await fetch('/api/users/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    email: 'user@example.com',
    password: 'password123',
    client_id: 'your_client_app_uid'
  })
});

const data = await response.json();
if (response.ok) {
  // Store the access token
  localStorage.setItem('access_token', data.user.access_token);
  localStorage.setItem('refresh_token', data.user.refresh_token);
} else {
  console.error('Login failed:', data.error);
}
```

## Notes

1. The `client_id` parameter is required and must match a registered Doorkeeper application.
2. Access tokens expire after 2 hours (7200 seconds) by default.
3. Refresh tokens can be used to obtain new access tokens without requiring the user to login again.
4. Account locking is temporary and requires admin intervention to unlock.
5. Rate limiting is implemented using Rails cache and resets after 15 minutes.