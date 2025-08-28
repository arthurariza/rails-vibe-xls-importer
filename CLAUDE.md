# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
- **Database**: SQLite3 (development/test)  
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

# Reach for context in the @context/project.md file

## Plan Mode
- **Every time** you formulate a plan you should add a step 0 to create a product requirement file under the folder @context/prds/
- You should create the PRD for every feature we are planning
- Each prd should come prefixed with a number-prd so we can keep the order we built things EX: 1-prd-gems.md 2-prd-models.md
