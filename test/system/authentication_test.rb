# frozen_string_literal: true

require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "user registration form is accessible" do
    visit root_path
    
    # Should see sign up link when not authenticated
    assert_selector "a", text: "Sign Up"
    
    click_link "Sign Up"
    
    # Should load registration form
    assert_current_path new_user_registration_path
    assert_selector "h2", text: "Sign up"
    assert_selector "input[type=email]"
    assert_selector "input[type=password]"
  end

  test "user cannot sign up with invalid email" do
    visit new_user_registration_path
    
    fill_in "Email", with: "invalid_email"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    
    click_button "Sign up"
    
    # Should stay on registration page 
    assert_current_path new_user_registration_path
    
    # User should not be created in database
    assert_not User.exists?(email: "invalid_email")
  end

  test "user cannot sign up with short password" do
    visit new_user_registration_path
    
    fill_in "Email", with: "test@example.com"
    fill_in "Password", with: "short"
    fill_in "Password confirmation", with: "short"
    
    click_button "Sign up"
    
    # Should stay on registration page and show validation error
    assert_current_path new_user_registration_path
    assert_text "prohibited this user from being saved"
  end

  test "user cannot sign up with mismatched passwords" do
    visit new_user_registration_path
    
    fill_in "Email", with: "test@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "different123"
    
    click_button "Sign up"
    
    # Should stay on registration page and show validation error
    assert_current_path new_user_registration_path
    assert_text "prohibited this user from being saved"
  end

  test "user cannot sign up with existing email" do
    # Create a user first
    User.create!(
      email: "existing@example.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )
    
    visit new_user_registration_path
    
    fill_in "Email", with: "existing@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    
    click_button "Sign up"
    
    # Should stay on registration page and show validation error
    assert_current_path new_user_registration_path
    assert_text "prohibited this user from being saved"
  end

  test "registration form has proper styling" do
    visit new_user_registration_path
    
    # Check for TailwindCSS styling classes
    assert_selector ".max-w-md.mx-auto"
    assert_selector "h2", text: "Sign up"
    assert_selector "input.border-gray-300.rounded-md"
    assert_selector "input[type=submit].bg-blue-600"
    
    # Check for links to other auth pages
    assert_link "Log in"
  end

  test "user can log in successfully" do
    # Create a confirmed user
    user = User.create!(
      email: "loginuser@example.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )
    
    visit root_path
    
    # Should see login link when not authenticated
    assert_selector "a", text: "Log In"
    
    click_link "Log In"
    
    # Fill out login form
    fill_in "Email", with: "loginuser@example.com"
    fill_in "Password", with: "password123"
    
    click_button "Log in"
    
    # Should redirect to root after successful login (which points to import_templates#index)
    assert_current_path root_path
    
    # Should show user email in navigation
    assert_selector "span", text: "loginuser@example.com"
    assert_selector "form button", text: "Log Out"
  end

  test "user cannot log in with invalid credentials" do
    visit new_user_session_path
    
    fill_in "Email", with: "nonexistent@example.com"
    fill_in "Password", with: "wrongpassword"
    
    click_button "Log in"
    
    # Should stay on login page
    assert_current_path new_user_session_path
    
    # Should show error message
    assert_text "Invalid Email or password"
  end

  test "user cannot log in with unconfirmed account" do
    # Create an unconfirmed user
    User.create!(
      email: "unconfirmed@example.com",
      password: "password123",
      password_confirmation: "password123"
      # confirmed_at is nil by default
    )
    
    visit new_user_session_path
    
    fill_in "Email", with: "unconfirmed@example.com"
    fill_in "Password", with: "password123"
    
    click_button "Log in"
    
    # Should stay on login page
    assert_current_path new_user_session_path
    
    # Should show confirmation error
    assert_text "You have to confirm your email address before continuing"
  end

  test "user can log out successfully" do
    # Create and sign in a user
    user = User.create!(
      email: "logoutuser@example.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )
    
    visit new_user_session_path
    fill_in "Email", with: "logoutuser@example.com"
    fill_in "Password", with: "password123"
    click_button "Log in"
    
    # Should be logged in
    assert_current_path root_path
    assert_selector "span", text: "logoutuser@example.com"
    
    # Click logout
    click_button "Log Out"
    
    # Should redirect to root and show login/signup links
    assert_current_path root_path
    assert_selector "a", text: "Log In"
    assert_selector "a", text: "Sign Up"
  end

  test "login form has proper styling" do
    visit new_user_session_path
    
    # Check for TailwindCSS styling classes
    assert_selector ".max-w-md.mx-auto"
    assert_selector "h2", text: "Log in"
    assert_selector "input.border-gray-300.rounded-md"
    assert_selector "input[type=submit].bg-blue-600"
    
    # Check for links to other auth pages
    assert_link "Sign up"
    assert_link "Forgot your password?"
  end

  test "user can access password reset form" do
    visit new_user_session_path
    
    click_link "Forgot your password?"
    
    # Should load password reset form
    assert_current_path new_user_password_path
    assert_selector "h2", text: "Forgot your password?"
    assert_selector "input[type=email]"
    assert_selector "input[type=submit][value='Send me reset password instructions']"
  end

  test "user can request password reset" do
    # Create a confirmed user
    user = User.create!(
      email: "resetuser@example.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )
    
    visit new_user_password_path
    
    fill_in "Email", with: "resetuser@example.com"
    click_button "Send me reset password instructions"
    
    # Should redirect to login page
    assert_current_path new_user_session_path
    
    # Should show success message
    assert_text "You will receive an email with instructions on how to reset your password in a few minutes"
  end

  test "user cannot request password reset with invalid email" do
    visit new_user_password_path
    
    fill_in "Email", with: "nonexistent@example.com"
    click_button "Send me reset password instructions"
    
    # Should stay on password reset page and show error
    assert_current_path new_user_password_path
    assert_text "Email not found"
  end

  test "password reset form has proper styling" do
    visit new_user_password_path
    
    # Check for TailwindCSS styling classes
    assert_selector ".max-w-md.mx-auto"
    assert_selector "h2", text: "Forgot your password?"
    assert_selector "input.border-gray-300.rounded-md"
    assert_selector "input[type=submit].bg-blue-600"
    
    # Check for link back to login
    assert_link "Log in"
  end

  test "user can access email confirmation form" do
    visit new_user_confirmation_path
    
    # Should load confirmation form
    assert_current_path new_user_confirmation_path
    assert_selector "h2", text: "Resend confirmation instructions"
    assert_selector "input[type=email]"
    assert_selector "input[type=submit][value='Resend confirmation instructions']"
  end

  test "user can request email confirmation resend" do
    # Create an unconfirmed user
    user = User.create!(
      email: "unconfirmed@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    visit new_user_confirmation_path
    
    fill_in "Email", with: "unconfirmed@example.com"
    click_button "Resend confirmation instructions"
    
    # Should redirect to login page
    assert_current_path new_user_session_path
    
    # Should show success message
    assert_text "You will receive an email with instructions for how to confirm your email address in a few minutes"
  end

  test "confirmation form has proper styling" do
    visit new_user_confirmation_path
    
    # Check for TailwindCSS styling classes
    assert_selector ".max-w-md.mx-auto"
    assert_selector "h2", text: "Resend confirmation instructions"
    assert_selector "input.border-gray-300.rounded-md"
    assert_selector "input[type=submit].bg-blue-600"
    
    # Check for link back to login
    assert_link "Log in"
  end

  test "users can only see their own import templates" do
    # Create two users with templates
    user1 = User.create!(
      email: "isolation1@example.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )
    
    user2 = User.create!(
      email: "isolation2@example.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )
    
    template1 = ImportTemplate.create!(
      name: "User 1 Template",
      user: user1,
      column_definitions: { "column_1" => { "name" => "Name", "data_type" => "string" } }
    )
    
    template2 = ImportTemplate.create!(
      name: "User 2 Template",
      user: user2,
      column_definitions: { "column_1" => { "name" => "Title", "data_type" => "string" } }
    )
    
    # Login as user1
    visit new_user_session_path
    fill_in "Email", with: "isolation1@example.com"
    fill_in "Password", with: "password123"
    click_button "Log in"
    
    # Should see only user1's template
    assert_text "User 1 Template"
    assert_no_text "User 2 Template"
  end

  test "users cannot access other users' templates via direct URL" do
    # Create two users with templates
    user1 = User.create!(
      email: "isolated1@example.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )
    
    user2 = User.create!(
      email: "isolated2@example.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )
    
    template1 = ImportTemplate.create!(
      name: "Private Template 1",
      user: user1,
      column_definitions: { "column_1" => { "name" => "Name", "data_type" => "string" } }
    )
    
    template2 = ImportTemplate.create!(
      name: "Private Template 2", 
      user: user2,
      column_definitions: { "column_1" => { "name" => "Title", "data_type" => "string" } }
    )
    
    # Login as user1
    visit new_user_session_path
    fill_in "Email", with: "isolated1@example.com"
    fill_in "Password", with: "password123"
    click_button "Log in"
    
    # Should be at root page after login
    assert_current_path root_path
    
    # Try to access user2's template directly (this triggers the authorization check)
    visit "/import_templates/#{template2.id}"
    
    # Should be redirected back to root with error message
    assert_current_path root_path
    assert_text "You don't have permission to access that resource"
  end
end