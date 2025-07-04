class Api::Auth::SessionsController < ApplicationController
  def login
    @auth_response = {
      success: true,
      user: {
        id: 1,
        email: "user@example.com",
        name: "John Doe"
      },
      token: "jwt_token_here",
      expires_at: 24.hours.from_now
    }
  end

  def register
    @user = {
      id: 1,
      email: "newuser@example.com", 
      name: "New User"
    }
  end

  def logout
    # DELETE endpoint
    render json: { success: true, message: "Logged out successfully" }
  end
end