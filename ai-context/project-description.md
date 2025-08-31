# Xls Importer Project

This document will detail what the goal of this project is and what im trying to achieve

## Goal
- This is a **prototype** application, not a real app for production
- The main feature will be to generate a XLS trough Ruby On Rails and lets users input the same file back into the app
- We will need to verify headers, and go trough each row of the sheet and update or create data
- The headers should be dynamic
- The data can be whatever you want (we can keep at 5 columns)

## Frontend
- A frontend will be needed to create the xls sheet and later when the user inputs the file back into the app it will need to reflect the data
- Use **HTML + ERB and hotwire** for frontend don't reach for manual JavaScript
- Use the playwright MCP when dealing with frontend tasks

## Testing
- This project uses minitest with default fixtures
- We dont need to test super deeply just important cases

## Xls gem
- We need to define a gem to read and write xls

## Xls MCP Server
- You have access to a XLS MCP Server

## Documentation
- You can reach for documentation under the @ai-context/docs folder

### Ruby On Rails
- Documentation for Ruby On Rails can be found at @ai-context/docs/rails

### Stimulus
- Documentation for Stimulus can be found at @ai-context/docs/stimulus

### Turbo
- Documentation for Turbo can be found at @ai-context/docs/turbo

## Commands

### Development
- `bin/dev` - Start development server with Vite, Rails server, and asset building via Foreman
- `bin/rails server` - Start Rails server only (port 3000)
- `bin/vite dev` - Start Vite development server for frontend assets

### Building and Assets  
- `bin/rails javascript:build` - Build JavaScript bundle with esbuild
- `bin/rails vite:build` - Bundle frontend entrypoints using Vite
- `bin/rails assets:precompile` - Compile all assets for production

### Database
- `bin/rails db:create` - Create databases  
- `bin/rails db:migrate` - Run database migrations
- `bin/rails db:seed` - Load seed data
- `bin/rails db:setup` - Create databases, load schema, and seed data

### Testing
- `bin/rails test` - Run all tests (Minitest framework)
- `bin/rails test:system` - Run system tests with Capybara/Selenium

### Code Quality
- `bin/rubocop` - Run Ruby linter with custom configuration
- `bin/brakeman` - Run security vulnerability scanner

## Architecture

### Stack
- **Rails 8** with modern defaults
- **Frontend**: Vite + esbuild + TailwindCSS + Stimulus + Turbo
- **Database**: SQLite3 (production/development/test)  
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **Real-time**: Solid Cable (ActionCable)

### Key Directories
- `app/services/` - Service objects (autoloaded)
- `app/javascript/` - Frontend JavaScript with Stimulus controllers
- `app/policies/` - Pundit authorization policies
- `config/` - Rails configuration
- `test/` - Minitest test suite

### Frontend Build System
The app uses a dual build system:
- **Vite** for development with HMR and modern tooling
- **esbuild** for JavaScript bundling (configured in package.json)
- Assets are built to `app/assets/builds/`

### Gems
- `pagy` - Pagination
- `pundit` - Authorization  
- `vite_rails` - Vite integration
- `bullet` - N+1 query detection (dev/test)
- `dotenv-rails` - Environment variables (dev/test)

### Configuration Notes
- Services directory is autoloaded via `config/application.rb`
- Rubocop configured with Rails, performance, and security cops
- String literals enforced as double quotes
- Documentation cops disabled