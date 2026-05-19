require "test_helper"

module Api
  class UsersControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @user = users(:one)
      @client_app = Doorkeeper::Application.create!(
        name: "Test App",
        redirect_uri: "https://example.com",
        scopes: ""
      )
    end

    test "should login with valid credentials" do
      post login_api_users_path, params: {
        email: @user.email,
        password: "password",
        client_id: @client_app.uid
      }

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["user"]["id"]
      assert json_response["user"]["email"]
      assert json_response["user"]["access_token"]
      assert json_response["user"]["refresh_token"]
    end

    test "should not login with invalid email" do
      post login_api_users_path, params: {
        email: "wrong@example.com",
        password: "password",
        client_id: @client_app.uid
      }

      assert_response :unauthorized
      json_response = JSON.parse(response.body)
      assert_equal "Invalid email or password", json_response["error"]
    end

    test "should not login with invalid password" do
      post login_api_users_path, params: {
        email: @user.email,
        password: "wrongpassword",
        client_id: @client_app.uid
      }

      assert_response :unauthorized
      json_response = JSON.parse(response.body)
      assert_equal "Invalid email or password", json_response["error"]
    end

    test "should not login without email" do
      post login_api_users_path, params: {
        password: "password",
        client_id: @client_app.uid
      }

      assert_response :bad_request
      json_response = JSON.parse(response.body)
      assert_equal "Email and password are required", json_response["error"]
    end

    test "should not login without password" do
      post login_api_users_path, params: {
        email: @user.email,
        client_id: @client_app.uid
      }

      assert_response :bad_request
      json_response = JSON.parse(response.body)
      assert_equal "Email and password are required", json_response["error"]
    end

    test "should not login with invalid client ID" do
      post login_api_users_path, params: {
        email: @user.email,
        password: "password",
        client_id: "invalid_client_id"
      }

      assert_response :forbidden
      json_response = JSON.parse(response.body)
      assert_equal "Invalid client ID", json_response["error"]
    end

    test "should not login with invalid email format" do
      post login_api_users_path, params: {
        email: "invalid-email",
        password: "password",
        client_id: @client_app.uid
      }

      assert_response :bad_request
      json_response = JSON.parse(response.body)
      assert_equal "Invalid email format", json_response["error"]
    end

    test "should lock account after multiple failed attempts" do
      # Simulate 10 failed login attempts
      10.times do
        post login_api_users_path, params: {
          email: @user.email,
          password: "wrongpassword",
          client_id: @client_app.uid
        }
      end

      # Try to login with correct password after account is locked
      post login_api_users_path, params: {
        email: @user.email,
        password: "password",
        client_id: @client_app.uid
      }

      assert_response :forbidden
      json_response = JSON.parse(response.body)
      assert_equal "Account is locked. Please contact support.", json_response["error"]
    end
  end
end