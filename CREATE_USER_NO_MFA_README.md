# Snowflake User Creation - No MFA Required

This directory contains scripts to create Snowflake users with password authentication and MFA explicitly disabled.

## Files Included

- `create_user_no_mfa.sql` - SQL script for creating users
- `create_user_no_mfa.py` - Python script for programmatic user creation
- `CREATE_USER_NO_MFA_README.md` - This file

## Option 1: Using SQL Script

### Prerequisites
- Access to Snowflake with `ACCOUNTADMIN` or `SECURITYADMIN` role
- SnowSQL CLI or Snowflake Web UI

### Steps

1. **Edit the SQL script** to customize user details:
   ```sql
   -- Update these values in create_user_no_mfa.sql
   CREATE USER IF NOT EXISTS demo_user
     PASSWORD = 'YourSecurePassword123!'
     EMAIL = 'user@example.com'
     DEFAULT_WAREHOUSE = 'YOUR_WAREHOUSE'
     DEFAULT_ROLE = 'YOUR_ROLE'
   ```

2. **Run the script** in one of these ways:

   **Option A: Using SnowSQL**
   ```bash
   snowsql -a <account_identifier> -u <admin_username> -f create_user_no_mfa.sql
   ```

   **Option B: Using Snowflake Web UI**
   - Log in to Snowflake
   - Navigate to Worksheets
   - Copy and paste the SQL script
   - Execute the script

### Key SQL Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `DISABLE_MFA` | Explicitly disables MFA | `TRUE` |
| `MINS_TO_BYPASS_MFA` | Minutes to bypass MFA (0 = disabled) | `0` |
| `MUST_CHANGE_PASSWORD` | Force password change on first login | `FALSE` |
| `DAYS_TO_EXPIRY` | Password expiration in days (0 = never) | `90` |

## Option 2: Using Python Script

### Prerequisites
- Python 3.7+
- Snowflake Python connector

### Installation

```bash
# Install required package
pip install snowflake-connector-python

# Or use the requirements.txt if available
pip install -r requirements.txt
```

### Usage

**Interactive Mode:**
```bash
python create_user_no_mfa.py
```

The script will prompt you for:
- Snowflake account identifier
- Admin credentials
- New user details (username, password, email, etc.)

**Programmatic Usage:**

```python
from create_user_no_mfa import create_user_no_mfa

success = create_user_no_mfa(
    account="your_account",
    admin_user="admin_username",
    admin_password="admin_password",
    new_username="demo_user",
    new_password="SecurePassword123!",
    email="demo@example.com",
    first_name="Demo",
    last_name="User",
    default_warehouse="COMPUTE_WH",
    default_role="PUBLIC"
)
```

### Disable MFA for Existing User

To disable MFA for an existing user:

**SQL:**
```sql
ALTER USER existing_user SET 
  DISABLE_MFA = TRUE
  MINS_TO_BYPASS_MFA = 0;
```

**Python:**
```python
from create_user_no_mfa import modify_existing_user_disable_mfa

modify_existing_user_disable_mfa(
    account="your_account",
    admin_user="admin_username",
    admin_password="admin_password",
    username="existing_user"
)
```

## Security Considerations

⚠️ **Important Security Notes:**

1. **Password Strength**: Always use strong passwords with:
   - Minimum 8 characters
   - Mix of uppercase, lowercase, numbers, and special characters

2. **Principle of Least Privilege**: Grant only necessary roles and permissions

3. **Password Management**: 
   - Don't hard-code passwords in scripts
   - Use environment variables or secure password managers
   - Rotate passwords regularly

4. **MFA Recommendation**: 
   - MFA is disabled for shareability, but consider enabling for production accounts
   - Use this configuration only for demo/test accounts when necessary

5. **Audit Trail**: Monitor user activities through Snowflake's audit logs

## Common Use Cases

### Creating a Read-Only Demo User

```sql
CREATE USER IF NOT EXISTS demo_readonly
  PASSWORD = 'DemoPass123!'
  EMAIL = 'demo@example.com'
  DISABLE_MFA = TRUE
  MINS_TO_BYPASS_MFA = 0
  DEFAULT_ROLE = 'PUBLIC';

-- Grant read-only access to specific database
GRANT USAGE ON DATABASE demo_db TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA demo_db.public TO ROLE PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA demo_db.public TO ROLE PUBLIC;
```

### Creating a Power User

```sql
CREATE USER IF NOT EXISTS power_user
  PASSWORD = 'PowerUser123!'
  EMAIL = 'poweruser@example.com'
  DISABLE_MFA = TRUE
  DEFAULT_ROLE = 'SYSADMIN';

GRANT ROLE SYSADMIN TO USER power_user;
```

## Verifying User Creation

```sql
-- Show user details
SHOW USERS LIKE 'demo_user';

-- Describe user properties
DESC USER demo_user;

-- Check MFA status
SELECT 
    NAME,
    DISABLED,
    MINS_TO_BYPASS_MFA,
    HAS_MFA
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE NAME = 'DEMO_USER';
```

## Connection Information

After creating a user, share these details:

```
Account URL: https://<account_locator>.<region>.snowflakecomputing.com
Username: demo_user
Password: [provided password]
```

## Troubleshooting

### Issue: Insufficient Privileges
**Solution**: Ensure you're using `ACCOUNTADMIN` or `SECURITYADMIN` role

### Issue: Warehouse Does Not Exist
**Solution**: Create the warehouse first or use an existing one:
```sql
SHOW WAREHOUSES;
```

### Issue: MFA Still Required
**Solution**: Verify both parameters are set:
```sql
ALTER USER demo_user SET 
  DISABLE_MFA = TRUE,
  MINS_TO_BYPASS_MFA = 0;
```

## Additional Resources

- [Snowflake User Management Documentation](https://docs.snowflake.com/en/sql-reference/sql/create-user.html)
- [Snowflake Security Best Practices](https://docs.snowflake.com/en/user-guide/security-best-practices.html)
- [Snowflake MFA Documentation](https://docs.snowflake.com/en/user-guide/security-mfa.html)

## Support

For issues or questions, refer to the Snowflake documentation or your organization's Snowflake administrator.

