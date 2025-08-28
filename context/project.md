# Xls Importer Project
- This document will detail what the goal of this project is and what im trying to achieve

## Goal
- This is a **prototype** application, not a real app for production
- The main feature will be to generate a XLS trough Ruby On Rails and lets users input the same file back into the app
- We will need to verify headers, and go trough each row of the sheet and update or create data
- The headers should be dynamic
- The data can be whatever you want (we can keep at 5 columns)
- A frontend will be needed to create the xls sheet and later when the user inputs the file back into the app it will need to reflect the data
- Use **HTML + ERB and maybe hotwire** for frontend don't reach for manual JavaScript

## Testing
- This project uses minitest with default fixtures
- We dont need to test super deeply just important cases

## Xls gem
- We need to define a gem to read and write xls

## Xls MCP Server
- You have access to a XLS MCP Server

## Documentation
- You can reach for documentation under the @context folder

### Ruby On Rails
- Documentation for Ruby On Rails can be found at @context/rails

### Stimulus
- Documentation for Stimulus can be found at @context/stimulus

### Turbo
- Documentation for Turbo can be found at @context/turbo