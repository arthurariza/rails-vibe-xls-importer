# Rails & Ruby Rules

## Core Rails Principle

- **Follow Ruby On Rails conventions first**: If Rails has a documented way to do something, use it. Only deviate when you have a clear justification.
- Use `bin/rails generate` commands to create new files (i.e. migrations, controllers, models, etc.).

## Class Structure
- Use key word arguments for the initializer method
- Inject dependencies in the initializer with key word arguments
- Use @variable instead of defining attr_reader

## Control Flow
- **Happy path last**: Handle error conditions first, success case last
- **Avoid else**: Use early returns instead of nested conditions  
- **Separate conditions**: Prefer multiple if statements over compound conditions

## Rails Conventions

### Controllers
- Plural resource names (`posts_controller`)
- Stick to CRUD methods (`index`, `show`, `new`, `create`, `edit`, `update`, `destroy`)
- Extract new controllers for non-CRUD actions
- Keep controllers thin **delegate business logic to services**

#### Security Considerations
- Always use strong parameters
- Implement CSRF protection (except for APIs)
- Validate authentication before actions
- Check authorization for each action
- Be careful with user input

### Routing Best Practices

```ruby
resources :users do
  member do
    post :activate
  end
  collection do
    get :search
  end
end
```

- Use resourceful routes
- Nest routes sparingly (max 1 level)
- Use constraints for advanced routing
- Keep routes RESTful

Remember: Controllers should be thin coordinators. Business logic belongs in models or service objects.

### Models
- When creating new models, create useful factories/fixtures and seeders for them too.

## Comments
- Add `# frozen_string_literal: true` comment at the top of each .rb file
- **Avoid comments** - write expressive code instead
- When needed, use proper formatting:
  ```ruby
  # Single line with space after
  
  # Multi
  # Line
  # Comment
  ```
- Refactor comments into descriptive function names

## Service Objects
- **Inheritance**: services should inherit from ApplicationService
- **Single Public Method**: Each Service Object must expose exactly one public method named `call`. All other methods must be private.
- **Initialization**: Service Objects should receive all required dependencies and parameters through their constructor.
- **Return Value**: The `call` method should return a result object with success/failure status and relevant data, not modify state through side effects.
- **Naming Convention**: Name Service Objects with verbs that describe their action (e.g., `CreateUser`, `GenerateReport`, `ValidateTransaction`).
- **Single Responsibility**: Each Service Object should perform exactly one business operation or transaction.
- **Immutability**: Service Objects should be immutable after initialization.
- **Error Handling**: Use custom exceptions for domain errors, Handle errors gracefully, Provide meaningful error messages
- **Notify Error Tracker**: The main rescue block from the call method needs to call `TP::ErrorTracker.notify(e, params = {})`
```ruby
def call
  ...
rescue StandardError => e
  TP::ErrorTracker.notify(e, employee_id: @employee_id)
end
# when using dependency injection
def call
  ...
rescue StandardError => e
  @error_tracker.notify(e, employee_id: @employee_id)
end
```

### Dependency Injection
```ruby
class NotificationService < ApplicationService
  def initialize(mailer: UserMailer, sms_client: TwilioClient.new)
    @mailer = mailer
    @sms_client = sms_client
  end
  
  def call
    @mailer.notification(user, message).deliver_later
    @sms_client.send_sms(user.phone, message) if user.sms_enabled?
  end
end
```

## Jobs
- **Job Design**: Create efficient, idempotent background jobs
- **Queue Management**: Organize jobs across different queues
- **Error Handling**: Implement retry strategies and error recovery
- **Performance**: Optimize job execution and resource usage
- **Monitoring**: Add logging and instrumentation

## Models
- **Model Design**: Create well-structured ActiveRecord models with appropriate validations
- **Associations**: Define relationships between models (has_many, belongs_to, has_and_belongs_to_many, etc.)
- **Migrations**: Write safe, reversible database migrations
- **Query Optimization**: Implement efficient scopes and query methods
- **Database Design**: Ensure proper normalization and indexing
- **Namespace Models**: Ensure related models are nested under the parent

### Validations
- Use built-in validators when possible
- Create custom validators for complex business rules
- Consider database-level constraints for critical validations

### Associations
- Use appropriate association types
- Consider :dependent options carefully
- Implement counter caches where beneficial
- Use :inverse_of for bidirectional associations

### Scopes and Queries
- Create named scopes for reusable queries
- Avoid N+1 queries with includes/preload/eager_load
- Use database indexes for frequently queried columns
- Consider using Arel for complex queries

### Callbacks
- Callbacks should be used only as a last resort
- Prefer service objects for complex operations
- Keep callbacks focused on the model's core concerns
- Callbacks should have a "guard" clause. EG: Only run when a specific attribute was changed or if a feature flag is enabled

## Migrations
- Add indexes for foreign keys and frequently queried columns
- Use strong data types (avoid string for everything)
- Consider the impact on existing data
- Test rollbacks before deploying

## Performance Considerations
- Index foreign keys and columns used in WHERE clauses
- Use counter caches for association counts
- Consider database views for complex queries
- Implement efficient bulk operations
- Monitor slow queries

## Version Specific Issues
- **Ruby Version Compatibility:** Ensure code is compatible with the target Ruby version.
- **Rails Version Compatibility:** Ensure code is compatible with the target Rails version.
