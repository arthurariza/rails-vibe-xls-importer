# Testing Rules

## Usefull Folders And Files
- @spec/ : the main testing folder
- @spec/fixtures : Fixtures folder
- @spec/rails_helper.rb : Rails helper file
- @spec/spec_helper.rb : Spec helper file
- @spec/swagger_helper.rb: Swagger helper file

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

## Rspec Context
- Use context blocks to group related functionality
- Use context blocks to group functionality by country
```ruby
context 'when employee is from Brazil' do
  ...
end

context 'when company is Mexican' do
  ...
end
```

## Rspec Anti Patterns
- Never use **let!**
- Chaining to many context blocks
- Never use `allow_any_instance_of` use `allow(Class).to_receive(:method).and_return(instance)` pattern
- Calling Timecop.freeze **in a before block** (Always ensure to call Timecop.return **in a after block**)

## Rspec Good Pattern
- **Describe Your Methods**: Be clear about what method you are describing.
- **Keep your description short**: A spec description should never be longer than 40 characters. If this happens you should split it using a context.
- **Single expectation test**: This helps you on finding possible errors, going directly to the failing test, and to make your code readable. In isolated unit specs, you want each example to specify one (and only one) behavior. Multiple expectations in the same example are a signal that you may be specifying multiple behaviors.
- **Test all possible cases**: Testing is a good practice, but if you do not test the edge cases, it will not be useful. Test valid, edge and invalid case.
- **Expect Syntax**: Always use the expect syntax.
- **Create only the data you need**
- **Use factories and not fixtures**: Use the FactoryBot gem