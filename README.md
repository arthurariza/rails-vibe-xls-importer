# Rails 8 + esbuild + Vite + Docker App Creator

A template for creating new Rails applications with esbuild, Vite and Docker and a pre-configured set of gems and tools.

## Usage
Create a new directory with the name of your project and change directory into it.

```
mkdir project_name && cd project_name
```

Clone this repository into the directory
```
git clone git@github.com:arthurariza/rails-new.git .
```

Run the script (with Docker)
```
bin/rails-new-docker
```
Run the script (without Docker)
```
bin/rails-new
```

## Default Configuration

This template uses the following Rails configuration options:

```
--database=sqlite3
--javascript=esbuild
--skip-jbuilder
--skip-rubocop
```

These options configure your Rails application with:
- SQLite database
- esbuild as the JavaScript runtime
- Vite as the JavaScript and asset bundler with Hot Module Reload
- Skips JBuilder
- Skips default test framework (uses RSpec instead)
- Skips Rubocop

> **Note:** You can customize these options by modifying the `railsrc` file before running the script. Feel free to add or remove options based on your project's specific needs.

## Included Gems & Tools

This template installs and configures the following gems and tools:

### Development & Test

- **rspec-rails** - Testing framework
- **factory_bot_rails** - Test data generation
- **faker** - Fake data generation for tests
- **dotenv-rails** - Environment variable management
- **bullet** - N+1 query detection

### Development Only

- **vite_rails** - Integrates Vite for asset bundling
- **prettier** - Code formatter for JavaScript/TypeScript
- **htmlbeautifier** - (Optional) HTML ERB beautifier
- **rubocop** - Ruby linter, configured with custom rules

### Test Only

- **shoulda-matchers** - Test matchers for common Rails functionality

## Features

- Vite-powered frontend with Hot Module Reload
- TailwindCSS for styles
- Configures RSpec with FactoryBot and Shoulda Matchers
- Sets up Bullet for N+1 query detection
- Pagination ready with Pagy
- Authorization setup with Pundit
- Creates a services directory with Rails autoloading
- Includes a pre-configured custom Rubocop setup
- Optional authentication setup
- Optional Active Storage setup
- Creates common files like .env and .env.template

## Thanks

Based on [this blog post](https://danielabaron.me/blog/kickstart-a-new-rails-project/#rubocop), [this repository](https://github.com/CodingItWrong/apiup/tree/main), [official Rails template guide](https://guides.rubyonrails.org/rails_application_templates.html), and [Ruby On Whales](https://github.com/evilmartians/ruby-on-whales)

## License

This project is available as open source under the terms of the [MIT License](LICENSE).
