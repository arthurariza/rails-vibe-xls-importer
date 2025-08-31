# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  test "should be valid with valid attributes" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_predicate user, :valid?
  end

  test "should require email" do
    user = User.new(password: "password123", password_confirmation: "password123")

    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should require password" do
    user = User.new(email: "test@example.com")

    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "should require unique email" do
    duplicate_user = User.new(
      email: @user.email,
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email], "has already been taken"
  end

  test "should require valid email format" do
    user = User.new(
      email: "invalid_email",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "should require password minimum length" do
    user = User.new(
      email: "test@example.com",
      password: "short",
      password_confirmation: "short"
    )

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 6 characters)"
  end

  test "should have many import_templates" do
    assert_respond_to @user, :import_templates
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @user.import_templates
  end

  test "should have many data_records through import_templates" do
    assert_respond_to @user, :data_records
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @user.data_records
  end

  test "should destroy associated import_templates when user is destroyed" do
    initial_count = @user.import_templates.count
    ImportTemplate.create!(
      name: "Test Template",
      user: @user,
      column_definitions: { "column_1" => { "name" => "Name", "data_type" => "string" } }
    )

    expected_decrease = initial_count + 1 # All existing templates plus the new one
    assert_difference "ImportTemplate.count", -expected_decrease do
      @user.destroy
    end
  end
end
