-- =====================================================
-- Create Snowflake User with Password (No MFA)
-- =====================================================
-- This script creates a user that can be shared with 
-- password authentication and ensures MFA is disabled
-- =====================================================

-- Set context (adjust as needed for your environment)
USE ROLE ACCOUNTADMIN;  -- or SECURITYADMIN

-- =====================================================
-- Create User with Password Authentication
-- =====================================================

CREATE USER IF NOT EXISTS demo_user
  PASSWORD = 'ChangeMe123!'  -- Set a strong password here
  LOGIN_NAME = 'demo_user'
  DISPLAY_NAME = 'Demo User'
  FIRST_NAME = 'Demo'
  LAST_NAME = 'User'
  EMAIL = 'demo.user@example.com'
  
  -- Disable MFA requirement
  MINS_TO_BYPASS_MFA = 0  -- Disable MFA bypass timer (MFA not required)
  DISABLE_MFA = TRUE      -- Explicitly disable MFA for this user
  
  -- Password settings
  MUST_CHANGE_PASSWORD = FALSE  -- User doesn't need to change password on first login
  
  -- Default settings (adjust as needed)
  DEFAULT_WAREHOUSE = 'COMPUTE_WH'  -- Set your default warehouse
  DEFAULT_NAMESPACE = 'PUBLIC'       -- Default database.schema
  DEFAULT_ROLE = 'PUBLIC'            -- Set appropriate default role
  
  -- Session parameters
  MINS_TO_UNLOCK = 15                -- Minutes until account unlocks after failed login attempts
  DAYS_TO_EXPIRY = 90                -- Password expiration in days (0 = never expires)
  
  -- Additional settings
  COMMENT = 'Demo user account with password authentication and no MFA requirement';

-- =====================================================
-- Grant Roles to User (customize as needed)
-- =====================================================

-- Grant basic role
GRANT ROLE PUBLIC TO USER demo_user;

-- Optional: Grant additional roles for more permissions
-- GRANT ROLE SYSADMIN TO USER demo_user;
-- GRANT ROLE ANALYST TO USER demo_user;

-- =====================================================
-- Grant Warehouse Usage (customize as needed)
-- =====================================================

GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE PUBLIC;

-- =====================================================
-- Verify User Creation
-- =====================================================

-- Show user details
SHOW USERS LIKE 'demo_user';

-- View user properties
DESC USER demo_user;

-- =====================================================
-- Connection Information to Share
-- =====================================================
-- Account URL: https://<account_locator>.<region>.snowflakecomputing.com
-- Username: demo_user
-- Password: ChangeMe123!
-- =====================================================

-- =====================================================
-- Optional: Modify Existing User to Disable MFA
-- =====================================================
-- If you need to disable MFA for an existing user:
/*
ALTER USER existing_user SET 
  DISABLE_MFA = TRUE
  MINS_TO_BYPASS_MFA = 0;
*/

-- =====================================================
-- Optional: Reset User Password
-- =====================================================
-- To reset password for an existing user:
/*
ALTER USER demo_user SET PASSWORD = 'NewPassword123!';
*/

-- =====================================================
-- Optional: Drop User
-- =====================================================
-- To remove the user:
/*
DROP USER IF EXISTS demo_user;
*/

