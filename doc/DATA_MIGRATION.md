# Data Migration Guide

This document outlines the data migration process for implementing user authentication in the XLS Importer application.

## Overview

When user authentication was added to the XLS Importer, existing import templates and data records needed to be assigned to users. This document describes the migration process and available tools.

## Migration Strategy

The migration approach assigns all existing orphaned data to a default admin user:

- **Admin User**: `admin@xls-importer.com` with password `password123`
- **Process**: Orphaned import templates are assigned to the admin user
- **Data Records**: Automatically associated through their parent import templates

## Available Rake Tasks

### Check Data Ownership Status

```bash
bin/rails data:show_ownership_status
```

This command displays:
- Total counts of users, templates, and records
- Number of orphaned templates (without users)
- Data breakdown by user

### Create Admin User

```bash
bin/rails data:create_admin
```

Creates the default admin user if it doesn't exist:
- Email: `admin@xls-importer.com`
- Password: `password123`
- Status: Confirmed (ready to login)

### Migrate Existing Data

```bash
bin/rails data:migrate_existing_data
```

This command:
1. Creates/finds the admin user
2. Identifies orphaned import templates
3. Assigns them to the admin user
4. Reports the migration results

## Database Schema Changes

The authentication implementation added:

### Users Table
- `id` - Primary key
- `email` - Unique identifier for login
- `encrypted_password` - Devise password storage
- `confirmed_at` - Email confirmation timestamp
- Other Devise fields (reset tokens, remember tokens, etc.)

### Import Templates Table
- Added `user_id` - Foreign key to users table
- Added `NOT NULL` constraint after migration

### Data Records Table
- No direct changes (inherits user through import_template)

## Seed Data

The application includes seed data for development and testing:

```bash
bin/rails db:seed
```

This creates:
- **Admin User**: `admin@xls-importer.com` / `password123`
- **Demo User**: `demo@xls-importer.com` / `password123`
- Sample employee data template with 5 records
- Sample product catalog template with 4 records

## Migration Process Steps

For production deployment, follow these steps:

1. **Backup Database**
   ```bash
   # Create database backup before migration
   cp production.db production.db.backup
   ```

2. **Run Database Migrations**
   ```bash
   bin/rails db:migrate
   ```

3. **Check Current Data Status**
   ```bash
   bin/rails data:show_ownership_status
   ```

4. **Create Admin User**
   ```bash
   bin/rails data:create_admin
   ```

5. **Migrate Existing Data**
   ```bash
   bin/rails data:migrate_existing_data
   ```

6. **Verify Migration**
   ```bash
   bin/rails data:show_ownership_status
   ```

## Post-Migration Considerations

After migration:

1. **Admin Access**: The admin user can access all migrated data
2. **User Creation**: New users start with empty templates
3. **Data Isolation**: Users can only see their own import templates and data
4. **Email Configuration**: Ensure email delivery is configured for user registration

## Rollback Strategy

If rollback is needed:

1. **Database Rollback**
   ```bash
   # Restore from backup
   cp production.db.backup production.db
   
   # Or rollback specific migrations
   bin/rails db:rollback STEP=3
   ```

2. **Remove Authentication**
   - Remove `belongs_to :user` from ImportTemplate model
   - Remove `before_action :authenticate_user!` from ApplicationController
   - Remove user_id column constraint

## Testing

Verify the migration works correctly:

1. **Unit Tests**: Run model and controller tests
   ```bash
   bin/rails test
   ```

2. **System Tests**: Run authentication flow tests
   ```bash
   bin/rails test:system
   ```

3. **Manual Testing**:
   - Login as admin user
   - Verify access to migrated templates
   - Create new user and verify data isolation

## Security Considerations

- Default admin password should be changed in production
- Email confirmation is enabled by default
- Strong password requirements are enforced
- User data is properly isolated by database constraints

## Support

For issues with data migration:
1. Check application logs for detailed error messages
2. Verify database constraints and foreign keys
3. Use the status commands to inspect data ownership
4. Ensure all users have confirmed email addresses for login

## File Locations

- Migration scripts: `lib/tasks/migrate_existing_data.rake`
- Seed data: `db/seeds.rb`
- User model: `app/models/user.rb`
- Authentication controllers: `app/controllers/` (Devise generated)
- Documentation: `doc/DATA_MIGRATION.md` (this file)