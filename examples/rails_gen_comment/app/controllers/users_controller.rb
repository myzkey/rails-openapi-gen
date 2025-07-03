class UsersController < ApplicationController
  def index
    @users = [
      { id: 1, email: "john@example.com", name: "John Doe", status: "active" },
      { id: 2, email: "jane@example.com", name: "Jane Smith", status: "inactive" }
    ]
  end

  def show
    @user = {
      id: params[:id].to_i,
      email: "user#{params[:id]}@example.com",
      name: "User #{params[:id]}",
      status: "active",
      role: "user",
      created_at: Time.current,
      profile: {
        bio: "Sample bio for user #{params[:id]}",
        avatar_url: "https://example.com/avatar.jpg",
        verified: true
      }
    }
  end
end