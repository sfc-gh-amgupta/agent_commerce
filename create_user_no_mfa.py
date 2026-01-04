"""
Snowflake User Creation Script - No MFA Required
Creates a Snowflake user with password authentication and MFA disabled
"""

import snowflake.connector
import os
from getpass import getpass


def create_user_no_mfa(
    account,
    admin_user,
    admin_password,
    new_username,
    new_password,
    email,
    first_name="Demo",
    last_name="User",
    default_warehouse="COMPUTE_WH",
    default_role="PUBLIC"
):
    """
    Create a Snowflake user with password authentication and MFA disabled.
    
    Args:
        account: Snowflake account identifier
        admin_user: Admin username for connection
        admin_password: Admin password for connection
        new_username: Username for the new user
        new_password: Password for the new user
        email: Email address for the new user
        first_name: First name of the user
        last_name: Last name of the user
        default_warehouse: Default warehouse for the user
        default_role: Default role for the user
    
    Returns:
        bool: True if user created successfully
    """
    
    try:
        # Connect to Snowflake as admin
        print(f"Connecting to Snowflake account: {account}")
        conn = snowflake.connector.connect(
            user=admin_user,
            password=admin_password,
            account=account,
            role='ACCOUNTADMIN'  # or SECURITYADMIN
        )
        
        cursor = conn.cursor()
        
        # Create user with password and no MFA
        create_user_sql = f"""
        CREATE USER IF NOT EXISTS {new_username}
            PASSWORD = '{new_password}'
            LOGIN_NAME = '{new_username}'
            DISPLAY_NAME = '{first_name} {last_name}'
            FIRST_NAME = '{first_name}'
            LAST_NAME = '{last_name}'
            EMAIL = '{email}'
            MINS_TO_BYPASS_MFA = 0
            DISABLE_MFA = TRUE
            MUST_CHANGE_PASSWORD = FALSE
            DEFAULT_WAREHOUSE = '{default_warehouse}'
            DEFAULT_ROLE = '{default_role}'
            MINS_TO_UNLOCK = 15
            DAYS_TO_EXPIRY = 90
            COMMENT = 'User account with password authentication and no MFA requirement'
        """
        
        print(f"Creating user: {new_username}")
        cursor.execute(create_user_sql)
        print(f"✓ User {new_username} created successfully")
        
        # Grant default role
        grant_role_sql = f"GRANT ROLE {default_role} TO USER {new_username}"
        cursor.execute(grant_role_sql)
        print(f"✓ Granted role {default_role} to user {new_username}")
        
        # Grant warehouse usage if needed
        grant_warehouse_sql = f"GRANT USAGE ON WAREHOUSE {default_warehouse} TO ROLE {default_role}"
        try:
            cursor.execute(grant_warehouse_sql)
            print(f"✓ Granted warehouse usage on {default_warehouse}")
        except Exception as e:
            print(f"Note: Warehouse grant may already exist or require additional permissions")
        
        # Verify user creation
        verify_sql = f"SHOW USERS LIKE '{new_username}'"
        cursor.execute(verify_sql)
        user_info = cursor.fetchall()
        
        if user_info:
            print("\n" + "="*60)
            print("USER CREATED SUCCESSFULLY")
            print("="*60)
            print(f"Username: {new_username}")
            print(f"Email: {email}")
            print(f"MFA Disabled: Yes")
            print(f"Default Role: {default_role}")
            print(f"Default Warehouse: {default_warehouse}")
            print("="*60)
            
            # Show connection details
            print("\nConnection Information to Share:")
            print(f"  Account: {account}")
            print(f"  Username: {new_username}")
            print(f"  Password: {new_password}")
            print(f"  URL: https://{account}.snowflakecomputing.com")
            print("="*60 + "\n")
        
        cursor.close()
        conn.close()
        
        return True
        
    except snowflake.connector.errors.ProgrammingError as e:
        print(f"✗ Error creating user: {e}")
        return False
    except Exception as e:
        print(f"✗ Unexpected error: {e}")
        return False


def modify_existing_user_disable_mfa(
    account,
    admin_user,
    admin_password,
    username
):
    """
    Disable MFA for an existing Snowflake user.
    
    Args:
        account: Snowflake account identifier
        admin_user: Admin username for connection
        admin_password: Admin password for connection
        username: Username of the user to modify
    
    Returns:
        bool: True if user modified successfully
    """
    
    try:
        # Connect to Snowflake as admin
        print(f"Connecting to Snowflake account: {account}")
        conn = snowflake.connector.connect(
            user=admin_user,
            password=admin_password,
            account=account,
            role='ACCOUNTADMIN'
        )
        
        cursor = conn.cursor()
        
        # Disable MFA for existing user
        alter_user_sql = f"""
        ALTER USER {username} SET 
            DISABLE_MFA = TRUE
            MINS_TO_BYPASS_MFA = 0
        """
        
        print(f"Disabling MFA for user: {username}")
        cursor.execute(alter_user_sql)
        print(f"✓ MFA disabled successfully for user {username}")
        
        cursor.close()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"✗ Error modifying user: {e}")
        return False


def main():
    """
    Main function - Interactive user creation
    """
    print("="*60)
    print("Snowflake User Creation Tool (No MFA)")
    print("="*60)
    print()
    
    # Get connection details
    account = input("Snowflake Account Identifier: ").strip()
    admin_user = input("Admin Username: ").strip()
    admin_password = getpass("Admin Password: ")
    
    print()
    print("New User Details:")
    print("-"*60)
    
    new_username = input("New Username: ").strip()
    new_password = getpass("New User Password: ")
    confirm_password = getpass("Confirm Password: ")
    
    if new_password != confirm_password:
        print("✗ Passwords do not match!")
        return
    
    email = input("Email Address: ").strip()
    first_name = input("First Name (default: Demo): ").strip() or "Demo"
    last_name = input("Last Name (default: User): ").strip() or "User"
    default_warehouse = input("Default Warehouse (default: COMPUTE_WH): ").strip() or "COMPUTE_WH"
    default_role = input("Default Role (default: PUBLIC): ").strip() or "PUBLIC"
    
    print()
    
    # Create user
    success = create_user_no_mfa(
        account=account,
        admin_user=admin_user,
        admin_password=admin_password,
        new_username=new_username,
        new_password=new_password,
        email=email,
        first_name=first_name,
        last_name=last_name,
        default_warehouse=default_warehouse,
        default_role=default_role
    )
    
    if success:
        print("\n✓ User creation completed successfully!")
    else:
        print("\n✗ User creation failed. Please check the errors above.")


if __name__ == "__main__":
    main()

