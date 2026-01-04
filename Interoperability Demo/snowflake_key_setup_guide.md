# Snowflake Key Pair Authentication Setup Guide

## 🔐 Generated Files

The following key pair has been generated for Snowflake authentication:

1. **`snowflake_private_key.pem`** - Private key (keep secure!)
2. **`snowflake_public_key.pem`** - Public key in standard PEM format
3. **`snowflake_public_key_snowflake_format.txt`** - Public key in Snowflake-required format

## 📋 Setup Instructions

### Step 1: Configure the Public Key in Snowflake

1. **Login to Snowflake** as an account administrator
2. **Run the following SQL command** to assign the public key to your user:

```sql
ALTER USER <your_username> SET RSA_PUBLIC_KEY='MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqRH9fnXzdkZ8kGaWQ0latV3ForMUvFJAwhW3wcq1sqiX6XxLnjWQn3rjmUBiQKrDBL+GGMCUxk5tw3bDEmN3tHQS9FeYGbZXUuS1KfE27gIn3kcHRXvIeWdMAqfxoWvJxi0hLwo91tzvOxFLucGbxBqG5bOTGdw8P4LpRqcOQp9kA86dAjxtXmvLGGS5dgBUU+NPxq3YC7EjkwConkJj3KHv3WaU6pWn95ebtT6hMRg2xCjfy6fWsCpZfrRabH/JaPcYxG+spIUo5uw1vW7U6vW8TkyfZtdZHqP9OArvC432z/HvqKcT+IONffr0AX962OybDjkqFGRCyd111uzOIwIDAQAB';
```

**Replace `<your_username>` with your actual Snowflake username.**

### Step 2: Test the Connection

You can now use the private key for authentication in various ways:

#### Option A: Using SnowSQL
```bash
snowsql -a <account_identifier> -u <username> --private-key-path snowflake_private_key.pem
```

#### Option B: Using Python Connector
```python
import snowflake.connector

conn = snowflake.connector.connect(
    user='<username>',
    account='<account_identifier>',
    private_key_file='snowflake_private_key.pem',
    warehouse='<warehouse_name>',
    database='<database_name>',
    schema='<schema_name>'
)
```

#### Option C: Using JDBC
Add these parameters to your JDBC connection string:
```
authenticator=snowflake_jwt&private_key_file=snowflake_private_key.pem
```

## 🔒 Security Best Practices

### 1. **Secure Storage**
- Store the private key in a secure location
- Set appropriate file permissions: `chmod 600 snowflake_private_key.pem`
- Never commit private keys to version control

### 2. **Key Rotation**
- Rotate keys periodically (recommended: every 90 days)
- Keep the old key active until all applications are updated

### 3. **Environment Variables**
For production use, consider storing the key path in environment variables:
```bash
export SNOWFLAKE_PRIVATE_KEY_PATH="/secure/path/to/snowflake_private_key.pem"
```

## 🛠️ Connection Parameters

When connecting to Snowflake, you'll need:

- **Account Identifier**: `<orgname>-<account_name>` or legacy format
- **Username**: Your Snowflake username
- **Private Key File**: Path to `snowflake_private_key.pem`
- **Warehouse**: (optional) Default warehouse
- **Database**: (optional) Default database
- **Schema**: (optional) Default schema

## 🔧 Troubleshooting

### Common Issues:

1. **"Invalid private key" error**
   - Ensure the private key file path is correct
   - Check file permissions (should be readable by the application)

2. **"JWT token invalid" error**
   - Verify the public key was correctly set in Snowflake
   - Check that the username matches exactly

3. **"Authentication failed" error**
   - Confirm the user has the necessary privileges
   - Verify the account identifier is correct

### Verify Public Key Setup:
```sql
DESC USER <your_username>;
```
Look for the `RSA_PUBLIC_KEY` property to confirm it's set.

## 📝 Next Steps

1. ✅ **Generated key pair**
2. ⏳ **Configure public key in Snowflake** (run the ALTER USER command)
3. ⏳ **Test connection** using one of the methods above
4. ⏳ **Update your applications** to use key-based authentication
5. ⏳ **Secure the private key** following best practices

---

**Generated on:** $(date)
**Key Length:** 2048 bits RSA
**Format:** PKCS#1 (PEM)


