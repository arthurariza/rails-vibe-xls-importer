## Relevant Files

- `Gemfile` - Add Devise gem dependency
- `app/models/user.rb` - User model with Devise modules
- `db/migrate/xxx_devise_create_users.rb` - Migration to create users table
- `db/migrate/xxx_add_user_id_to_import_templates.rb` - Migration to add user association to import templates
- `db/migrate/xxx_add_user_id_to_data_records.rb` - Migration to add user association to data records
- `app/models/import_template.rb` - Add belongs_to :user relationship
- `app/models/data_record.rb` - Add belongs_to :user relationship
- `app/controllers/application_controller.rb` - Add Devise authentication and user scoping
- `app/controllers/import_templates_controller.rb` - Update to scope queries by current_user
- `app/controllers/data_records_controller.rb` - Update to scope queries by current_user
- `app/views/devise/sessions/new.html.erb` - Custom login form with TailwindCSS styling
- `app/views/devise/registrations/new.html.erb` - Custom registration form with TailwindCSS styling
- `app/views/devise/registrations/edit.html.erb` - Custom account edit form with TailwindCSS styling
- `app/views/devise/passwords/new.html.erb` - Custom password reset form with TailwindCSS styling
- `app/views/devise/passwords/edit.html.erb` - Custom password reset confirmation form with TailwindCSS styling
- `app/views/devise/confirmations/new.html.erb` - Custom email confirmation form with TailwindCSS styling
- `app/views/layouts/application.html.erb` - Add authentication links to navigation
- `app/views/layouts/_devise_layout.html.erb` - Optional separate layout for authentication pages
- `config/initializers/devise.rb` - Devise configuration
- `config/routes.rb` - Add Devise routes and update root route
- `test/models/user_test.rb` - Unit tests for User model
- `test/controllers/import_templates_controller_test.rb` - Update tests for user authentication
- `test/controllers/data_records_controller_test.rb` - Update tests for user authentication
- `test/system/authentication_test.rb` - System tests for authentication flows

### Notes

- Devise automatically generates migration files when installed
- User associations will need to be added to existing models with foreign key migrations
- Existing data may need to be migrated to be owned by a default user
- Email configuration will be needed for confirmation and password reset emails
- Use `bin/rails test` to run all tests
- Use `bin/rails test:system` to run system tests with Capybara

## Tasks

- [x] 1.0 Setup Devise Gem and Configuration
  - [x] 1.1 Add `gem "devise"` to Gemfile
  - [x] 1.2 Run `bundle install` to install the gem
  - [x] 1.3 Run `rails generate devise:install` to generate configuration files
  - [x] 1.4 Configure Devise settings in `config/initializers/devise.rb` (mailer sender, secret key)
  - [x] 1.5 Set default URL options in development environment config

- [x] 2.0 Create User Model and Database Migrations
  - [x] 2.1 Run `rails generate devise user` to create User model and migration
  - [x] 2.2 Review and customize the generated User migration (add confirmable, rememberable modules)
  - [x] 2.3 Run `rails db:migrate` to create the users table
  - [x] 2.4 Configure User model with desired Devise modules (database_authenticatable, registerable, recoverable, rememberable, validatable, confirmable)

- [ ] 3.0 Update Existing Models with User Associations
  - [ ] 3.1 Generate migration to add user_id to import_templates table
  - [ ] 3.2 Generate migration to add user_id to data_records table  
  - [ ] 3.3 Add `belongs_to :user` to ImportTemplate model
  - [ ] 3.4 Add `belongs_to :user` to DataRecord model
  - [ ] 3.5 Add `has_many :import_templates` and `has_many :data_records` to User model
  - [ ] 3.6 Run migrations to update database schema

- [ ] 4.0 Add Authentication to Controllers
  - [ ] 4.1 Add `before_action :authenticate_user!` to ApplicationController
  - [ ] 4.2 Update ImportTemplatesController to scope queries by `current_user.import_templates`
  - [ ] 4.3 Update DataRecordsController to scope queries through user's import_templates
  - [ ] 4.4 Ensure new records are automatically associated with current_user
  - [ ] 4.5 Add authorization checks to prevent access to other users' data
  - [ ] 4.6 Update root route to redirect to import_templates_path after authentication

- [ ] 5.0 Create and Style Devise Views (Make use of the playwright mcp in all sub tasks)
  - [ ] 5.1 Run `rails generate devise:views` to generate customizable view templates
  - [ ] 5.2 Style login form (sessions/new.html.erb) with TailwindCSS to match existing forms
  - [ ] 5.3 Style registration form (registrations/new.html.erb) with TailwindCSS
  - [ ] 5.4 Style account edit form (registrations/edit.html.erb) with TailwindCSS  
  - [ ] 5.5 Style password reset forms (passwords/new.html.erb and edit.html.erb) with TailwindCSS
  - [ ] 5.6 Style email confirmation form (confirmations/new.html.erb) with TailwindCSS
  - [ ] 5.7 Customize Devise flash message styling to match existing notice/alert classes

- [ ] 6.0 Update Application Layout and Navigation
  - [ ] 6.1 Add authentication links to navigation bar in application.html.erb
  - [ ] 6.2 Show "Sign Up" and "Log In" links for unauthenticated users
  - [ ] 6.3 Show user email and "Log Out" link for authenticated users
  - [ ] 6.4 Add conditional logic to hide/show navigation items based on authentication status
  - [ ] 6.5 Style authentication links to match existing navigation styling

- [ ] 7.0 Configure Email Settings  
  - [ ] 7.1 Configure ActionMailer settings in development.rb for email confirmation
  - [ ] 7.2 Set up SMTP configuration or use letter_opener gem for development testing
  - [ ] 7.3 Customize Devise email templates if needed
  - [ ] 7.4 Test email delivery for registration confirmation and password reset

- [ ] 8.0 Write Tests for Authentication
  - [ ] 8.1 Create User model tests (validation, associations)
  - [ ] 8.2 Update ImportTemplatesController tests to include authentication and user scoping
  - [ ] 8.3 Update DataRecordsController tests to include authentication and user scoping  
  - [ ] 8.4 Create system tests for user registration flow
  - [ ] 8.5 Create system tests for login/logout flow
  - [ ] 8.6 Create system tests for password reset flow
  - [ ] 8.7 Create system tests for email confirmation flow
  - [ ] 8.8 Test user data isolation (users can't see each other's data)

- [ ] 9.0 Data Migration for Existing Records
  - [ ] 9.1 Create a rake task or migration to assign existing import_templates to a default user
  - [ ] 9.2 Create a rake task or migration to assign existing data_records to the same default user
  - [ ] 9.3 Test the migration with existing data
  - [ ] 9.4 Document the migration process for future reference