module Api
  class UsersController < ApplicationController
    skip_before_action :doorkeeper_authorize!, only: %i[create login]

    def create
      user = User.new(email: user_params[:email], password: user_params[:password])
      client_app = Doorkeeper::Application.find_by(uid: params[:client_id])
      return render(json: { error: 'Invalid client ID'}, status: 403) unless client_app

      if user.save
        access_token = Doorkeeper::AccessToken.create(
          resource_owner_id: user.id,
          application_id: client_app.id,
          refresh_token: generate_refresh_token,
          expires_in: Doorkeeper.configuration.access_token_expires_in.to_i,
          scopes: ''
        )
        
        render(json: {
          user: {
            id: user.id,
            email: user.email,
            access_token: access_token.token,
            token_type: 'bearer',
            expires_in: access_token.expires_in,
            refresh_token: access_token.refresh_token,
            created_at: access_token.created_at.to_time.to_i
          }
        })
      else
        render(json: { error: user.errors.full_messages }, status: 422)
      end
    end

    def login
      # Rate limiting check
      if rate_limit_exceeded?(request.remote_ip)
        return render(json: { error: 'Too many login attempts. Please try again later.' }, status: 429)
      end

      # Validate required parameters
      unless login_params[:email].present? && login_params[:password].present?
        return render(json: { error: 'Email and password are required' }, status: 400)
      end

      # Validate email format
      unless URI::MailTo::EMAIL_REGEXP.match?(login_params[:email])
        return render(json: { error: 'Invalid email format' }, status: 400)
      end

      client_app = Doorkeeper::Application.find_by(uid: params[:client_id])
      return render(json: { error: 'Invalid client ID'}, status: 403) unless client_app

      # Find user by email
      user = User.find_by(email: login_params[:email].downcase.strip)
      
      # Security: Always check password even if user doesn't exist to prevent timing attacks
      if user.nil? || !user.valid_password?(login_params[:password])
        # Track failed login attempt
        track_failed_login(request.remote_ip, login_params[:email])
        return render(json: { error: 'Invalid email or password' }, status: 401)
      end

      # Check if user account is locked or disabled
      if user.access_locked?
        return render(json: { error: 'Account is locked. Please contact support.' }, status: 403)
      end

      # Reset failed login attempts on successful login
      reset_failed_login(request.remote_ip)

      # Create access token
      access_token = Doorkeeper::AccessToken.create(
        resource_owner_id: user.id,
        application_id: client_app.id,
        refresh_token: generate_refresh_token,
        expires_in: Doorkeeper.configuration.access_token_expires_in.to_i,
        scopes: ''
      )

      # Update last login timestamp
      user.update(last_sign_in_at: Time.current)

      render(json: {
        user: {
          id: user.id,
          email: user.email,
          access_token: access_token.token,
          token_type: 'bearer',
          expires_in: access_token.expires_in,
          refresh_token: access_token.refresh_token,
          created_at: access_token.created_at.to_time.to_i
        }
      })
    end

    private

    def user_params
      params.permit(:email, :password)
    end

    def login_params
      params.permit(:email, :password)
    end

    def generate_refresh_token
      loop do
        token = SecureRandom.hex(32)
        break token unless Doorkeeper::AccessToken.exists?(refresh_token: token)
      end
    end

    # Rate limiting methods
    def rate_limit_exceeded?(ip_address)
      # Implement rate limiting logic
      # You can use Redis or Rails cache for production
      key = "login_attempts:#{ip_address}"
      attempts = Rails.cache.read(key).to_i
      attempts >= 5 # Limit to 5 attempts per IP
    end

    def track_failed_login(ip_address, email)
      # Track failed login attempts
      key = "login_attempts:#{ip_address}"
      attempts = Rails.cache.read(key).to_i + 1
      Rails.cache.write(key, attempts, expires_in: 15.minutes)

      # Also track by email for account-specific locking
      email_key = "failed_logins:#{email.downcase.strip}"
      email_attempts = Rails.cache.read(email_key).to_i + 1
      Rails.cache.write(email_key, email_attempts, expires_in: 1.hour)

      # Lock account after 10 failed attempts
      if email_attempts >= 10
        user = User.find_by(email: email.downcase.strip)
        user&.lock_access! if user
      end
    end

    def reset_failed_login(ip_address)
      # Reset failed login attempts on successful login
      key = "login_attempts:#{ip_address}"
      Rails.cache.delete(key)
    end
  end
end
