# Testing Rules

## Usefull Folders And Files
- @test/ : the main testing folder
- @test/fixtures : Fixtures folder
- @spec/test_helper.rb : Test helper file
- @spec/application_system_test_case.rb : System test helper file

## Arrange-Act-Assert
1. **Arrange**: Set up test data and prerequisites
2. **Act**: Execute the code being tested
3. **Assert**: Verify the expected outcome

## Test Data
- Use factories (FactoryBot) or fixtures
- Create minimal data needed for each test
- Avoid dependencies between tests
- Clean up after tests

## Edge Cases
- **Handling Empty Datasets:** Ensure code handles empty datasets gracefully.
- **Handling Large Datasets:** Optimize code to handle large datasets efficiently.
- **Handling Time Zones:** Be aware of time zone issues when working with dates and times.
- **Handling Exceptions:** Failing to handle exceptions can cause the application to crash.
- **Invalid inputs**: Test invalid input, never trust user input

## Coverage Guidelines
- Aim for high coverage but focus on meaningful tests
- Test all public methods
- Test edge cases and error conditions
- Don't test Rails framework itself
- Focus on business logic coverage

## Minitest Best Practices

```ruby
class UserTest < ActiveSupport::TestCase
  test "should not save user without email" do
    user = User.new
    assert_not user.save, "Saved the user without an email"
  end

  test "should report full name" do
    user = User.new(first_name: "John", last_name: "Doe")
    assert_equal "John Doe", user.full_name
  end
end
```

## Integration Tests
```ruby
class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should get index" do
    get users_url
    assert_response :success
  end

  test "should create user" do
    assert_difference('User.count') do
      post users_url, params: { user: { email: 'new@example.com' } }
    end

    assert_redirected_to user_url(User.last)
  end
end
```
<% end %>