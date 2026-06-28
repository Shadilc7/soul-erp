class CustomFailure < Devise::FailureApp
  def redirect_url
    new_user_session_path
  end

  def respond
    if http_auth?
      http_auth
    else
      # Set the flash alert so the user sees the error message on the login page
      flash[:alert] = "Invalid user or user not approved."
      redirect
    end
  end
end
