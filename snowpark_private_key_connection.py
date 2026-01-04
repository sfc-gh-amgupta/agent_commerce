"""
================================================================================
SNOWPARK CONNECTION WITH PRIVATE KEY AUTHENTICATION (macOS)
================================================================================
This script demonstrates how to connect to Snowflake using Snowpark with
RSA private key authentication. The private key is stored locally on macOS.

Features:
- Secure private key loading from local file system
- Multiple key format support (PEM, DER)
- Encrypted private key support (with passphrase)
- Connection validation and testing
- Error handling and troubleshooting

Prerequisites:
1. RSA private key file stored on your Mac
2. Corresponding public key configured in Snowflake
3. Snowpark library installed: pip install snowflake-snowpark-python

Author: Snowflake Solutions Engineering
Last Updated: January 2025
================================================================================
"""

import os
import sys
from pathlib import Path
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, current_timestamp
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import load_pem_private_key, load_der_private_key
from cryptography.hazmat.backends import default_backend
import getpass
from typing import Optional
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============================================================================
# CONFIGURATION SECTION
# ============================================================================

class SnowflakeConfig:
    """
    Configuration class for Snowflake connection parameters
    """
    
    def __init__(self):
        # Snowflake connection parameters
        # Update these values according to your Snowflake account
        self.account = "your_account_identifier"  # e.g., "abc123.us-east-1"
        self.user = "your_username"
        self.role = "your_role"  # Optional
        self.warehouse = "your_warehouse"  # Optional
        self.database = "your_database"  # Optional
        self.schema = "your_schema"  # Optional
        
        # Private key file paths (update these to your actual paths)
        self.private_key_paths = [
            "/Users/amgupta/Documents/Snowflake/Demo/Interoperability Demo/snowflake_private_key.pem",
            "~/snowflake_keys/private_key.pem",
            "~/.ssh/snowflake_rsa",
            "~/Documents/keys/snowflake_private_key.pem"
        ]
        
        # Environment variables (alternative to hardcoded values)
        self.load_from_environment()
    
    def load_from_environment(self):
        """Load configuration from environment variables if available"""
        self.account = os.getenv("SNOWFLAKE_ACCOUNT", self.account)
        self.user = os.getenv("SNOWFLAKE_USER", self.user)
        self.role = os.getenv("SNOWFLAKE_ROLE", self.role)
        self.warehouse = os.getenv("SNOWFLAKE_WAREHOUSE", self.warehouse)
        self.database = os.getenv("SNOWFLAKE_DATABASE", self.database)
        self.schema = os.getenv("SNOWFLAKE_SCHEMA", self.schema)
        
        # Add environment variable path if specified
        env_key_path = os.getenv("SNOWFLAKE_PRIVATE_KEY_PATH")
        if env_key_path:
            self.private_key_paths.insert(0, env_key_path)

# ============================================================================
# PRIVATE KEY HANDLING FUNCTIONS
# ============================================================================

def find_private_key_file(key_paths: list) -> Optional[str]:
    """
    Find the first existing private key file from the list of paths
    
    Args:
        key_paths: List of potential private key file paths
        
    Returns:
        Path to the first existing private key file, or None if not found
    """
    
    for key_path in key_paths:
        # Expand user home directory (~)
        expanded_path = os.path.expanduser(key_path)
        
        if os.path.exists(expanded_path):
            logger.info(f"Found private key file: {expanded_path}")
            return expanded_path
    
    logger.error("No private key file found in the specified paths")
    return None

def load_private_key_from_file(key_file_path: str, passphrase: Optional[str] = None) -> Optional[bytes]:
    """
    Load private key from file and return in the format expected by Snowpark
    
    Args:
        key_file_path: Path to the private key file
        passphrase: Optional passphrase for encrypted keys
        
    Returns:
        Private key in DER format (bytes), or None if loading failed
    """
    
    try:
        with open(key_file_path, 'rb') as key_file:
            key_data = key_file.read()
        
        # Convert passphrase to bytes if provided
        passphrase_bytes = passphrase.encode() if passphrase else None
        
        # Try to load as PEM first (most common format)
        try:
            private_key = load_pem_private_key(
                key_data,
                password=passphrase_bytes,
                backend=default_backend()
            )
            logger.info("Successfully loaded PEM private key")
            
        except ValueError:
            # If PEM loading fails, try DER format
            try:
                private_key = load_der_private_key(
                    key_data,
                    password=passphrase_bytes,
                    backend=default_backend()
                )
                logger.info("Successfully loaded DER private key")
                
            except ValueError as e:
                logger.error(f"Failed to load private key: {e}")
                return None
        
        # Convert to DER format for Snowpark
        private_key_der = private_key.private_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        )
        
        logger.info("Private key converted to DER format successfully")
        return private_key_der
        
    except FileNotFoundError:
        logger.error(f"Private key file not found: {key_file_path}")
        return None
    except PermissionError:
        logger.error(f"Permission denied accessing private key file: {key_file_path}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error loading private key: {e}")
        return None

def prompt_for_passphrase() -> Optional[str]:
    """
    Securely prompt user for private key passphrase
    
    Returns:
        Passphrase string or None if user cancels
    """
    
    try:
        passphrase = getpass.getpass("Enter private key passphrase (press Enter if none): ")
        return passphrase if passphrase.strip() else None
    except KeyboardInterrupt:
        logger.info("User cancelled passphrase entry")
        return None

# ============================================================================
# SNOWFLAKE CONNECTION FUNCTIONS
# ============================================================================

def create_snowpark_session_with_private_key(config: SnowflakeConfig) -> Optional[Session]:
    """
    Create Snowpark session using private key authentication
    
    Args:
        config: SnowflakeConfig object with connection parameters
        
    Returns:
        Snowpark Session object or None if connection failed
    """
    
    logger.info("Starting Snowpark session creation with private key authentication")
    
    # Find private key file
    private_key_path = find_private_key_file(config.private_key_paths)
    if not private_key_path:
        logger.error("Cannot proceed without private key file")
        return None
    
    # Load private key
    private_key_der = None
    max_attempts = 3
    
    for attempt in range(max_attempts):
        if attempt == 0:
            # First attempt without passphrase
            private_key_der = load_private_key_from_file(private_key_path)
        else:
            # Subsequent attempts with passphrase
            logger.info(f"Attempt {attempt + 1}: Private key may be encrypted")
            passphrase = prompt_for_passphrase()
            if passphrase is None:
                logger.info("User cancelled passphrase entry")
                break
            private_key_der = load_private_key_from_file(private_key_path, passphrase)
        
        if private_key_der:
            break
    
    if not private_key_der:
        logger.error("Failed to load private key after all attempts")
        return None
    
    # Build connection parameters
    connection_parameters = {
        "account": config.account,
        "user": config.user,
        "private_key": private_key_der,
    }
    
    # Add optional parameters if specified
    if config.role:
        connection_parameters["role"] = config.role
    if config.warehouse:
        connection_parameters["warehouse"] = config.warehouse
    if config.database:
        connection_parameters["database"] = config.database
    if config.schema:
        connection_parameters["schema"] = config.schema
    
    # Create Snowpark session
    try:
        logger.info("Creating Snowpark session...")
        session = Session.builder.configs(connection_parameters).create()
        
        logger.info("✅ Successfully connected to Snowflake using private key authentication")
        return session
        
    except Exception as e:
        logger.error(f"❌ Failed to create Snowpark session: {e}")
        return None

def test_snowflake_connection(session: Session) -> bool:
    """
    Test the Snowflake connection with basic operations
    
    Args:
        session: Snowpark Session object
        
    Returns:
        True if connection test passed, False otherwise
    """
    
    if not session:
        logger.error("No session provided for testing")
        return False
    
    try:
        logger.info("Testing Snowflake connection...")
        
        # Test 1: Get current session information
        logger.info("=== Session Information ===")
        logger.info(f"Account: {session.get_current_account()}")
        logger.info(f"User: {session.get_current_user()}")
        logger.info(f"Role: {session.get_current_role()}")
        logger.info(f"Warehouse: {session.get_current_warehouse()}")
        logger.info(f"Database: {session.get_current_database()}")
        logger.info(f"Schema: {session.get_current_schema()}")
        
        # Test 2: Simple query
        logger.info("\n=== Simple Query Test ===")
        result = session.sql("SELECT CURRENT_TIMESTAMP() as current_time, CURRENT_USER() as current_user").collect()
        logger.info(f"Current Snowflake time: {result[0]['CURRENT_TIME']}")
        logger.info(f"Current user: {result[0]['CURRENT_USER']}")
        
        # Test 3: Check available warehouses
        logger.info("\n=== Available Warehouses ===")
        try:
            warehouses = session.sql("SHOW WAREHOUSES").collect()
            if warehouses:
                for wh in warehouses[:3]:  # Show first 3 warehouses
                    logger.info(f"- {wh['name']} (Size: {wh['size']}, State: {wh['state']})")
            else:
                logger.info("No warehouses visible to current user")
        except Exception as e:
            logger.warning(f"Could not retrieve warehouses: {e}")
        
        # Test 4: Check available databases
        logger.info("\n=== Available Databases ===")
        try:
            databases = session.sql("SHOW DATABASES").collect()
            if databases:
                for db in databases[:5]:  # Show first 5 databases
                    logger.info(f"- {db['name']}")
            else:
                logger.info("No databases visible to current user")
        except Exception as e:
            logger.warning(f"Could not retrieve databases: {e}")
        
        logger.info("\n✅ Connection test completed successfully!")
        return True
        
    except Exception as e:
        logger.error(f"❌ Connection test failed: {e}")
        return False

# ============================================================================
# SAMPLE DATA OPERATIONS
# ============================================================================

def demonstrate_basic_operations(session: Session):
    """
    Demonstrate basic Snowpark operations
    
    Args:
        session: Snowpark Session object
    """
    
    if not session:
        logger.error("No session available for operations")
        return
    
    try:
        logger.info("\n=== Basic Snowpark Operations ===")
        
        # Create a simple DataFrame
        sample_data = [
            ("Alice", 25, "Engineer"),
            ("Bob", 30, "Manager"),
            ("Charlie", 35, "Analyst"),
            ("Diana", 28, "Developer")
        ]
        
        df = session.create_dataframe(
            sample_data,
            schema=["name", "age", "role"]
        )
        
        logger.info("Created sample DataFrame:")
        df.show()
        
        # Perform some transformations
        logger.info("\nFiltered data (age > 27):")
        filtered_df = df.filter(col("age") > 27)
        filtered_df.show()
        
        # Aggregation
        logger.info("\nAggregation - Average age:")
        avg_age = df.agg({"age": "avg"}).collect()[0][0]
        logger.info(f"Average age: {avg_age:.1f}")
        
        logger.info("✅ Basic operations completed successfully!")
        
    except Exception as e:
        logger.error(f"❌ Error in basic operations: {e}")

# ============================================================================
# MAIN EXECUTION FUNCTION
# ============================================================================

def main():
    """
    Main function to demonstrate Snowpark connection with private key
    """
    
    print("🚀 Snowpark Private Key Authentication Demo")
    print("=" * 60)
    
    # Load configuration
    config = SnowflakeConfig()
    
    # Display configuration (without sensitive data)
    logger.info("Configuration loaded:")
    logger.info(f"Account: {config.account}")
    logger.info(f"User: {config.user}")
    logger.info(f"Role: {config.role}")
    logger.info(f"Warehouse: {config.warehouse}")
    logger.info(f"Database: {config.database}")
    logger.info(f"Schema: {config.schema}")
    logger.info(f"Private key search paths: {len(config.private_key_paths)} paths configured")
    
    # Create Snowpark session
    session = create_snowpark_session_with_private_key(config)
    
    if session:
        try:
            # Test connection
            if test_snowflake_connection(session):
                # Demonstrate basic operations
                demonstrate_basic_operations(session)
            else:
                logger.error("Connection test failed")
                
        except Exception as e:
            logger.error(f"Error during operations: {e}")
            
        finally:
            # Clean up session
            try:
                session.close()
                logger.info("✅ Snowpark session closed successfully")
            except Exception as e:
                logger.warning(f"Error closing session: {e}")
    else:
        logger.error("❌ Could not establish Snowpark session")

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def check_prerequisites():
    """
    Check if all prerequisites are met
    """
    
    logger.info("Checking prerequisites...")
    
    # Check if Snowpark is installed
    try:
        import snowflake.snowpark
        logger.info("✅ Snowpark library is installed")
    except ImportError:
        logger.error("❌ Snowpark library not found. Install with: pip install snowflake-snowpark-python")
        return False
    
    # Check if cryptography is installed
    try:
        import cryptography
        logger.info("✅ Cryptography library is installed")
    except ImportError:
        logger.error("❌ Cryptography library not found. Install with: pip install cryptography")
        return False
    
    return True

def print_setup_instructions():
    """
    Print setup instructions for users
    """
    
    print("""
=== SETUP INSTRUCTIONS ===

1. 🔑 GENERATE RSA KEY PAIR (if not already done):
   openssl genrsa -out snowflake_private_key.pem 2048
   openssl rsa -in snowflake_private_key.pem -pubout -out snowflake_public_key.pem

2. 📋 CONFIGURE PUBLIC KEY IN SNOWFLAKE:
   ALTER USER your_username SET RSA_PUBLIC_KEY='<public_key_content>';

3. 🔧 UPDATE CONFIGURATION:
   - Edit the SnowflakeConfig class in this script
   - Set your account identifier, username, and other parameters
   - Update private key file paths

4. 🔐 SECURE YOUR PRIVATE KEY:
   chmod 600 /path/to/your/snowflake_private_key.pem

5. 🌍 ENVIRONMENT VARIABLES (optional):
   export SNOWFLAKE_ACCOUNT="your_account"
   export SNOWFLAKE_USER="your_username"
   export SNOWFLAKE_PRIVATE_KEY_PATH="/path/to/private_key.pem"

6. 🚀 RUN THE SCRIPT:
   python snowpark_private_key_connection.py
""")

def print_troubleshooting_guide():
    """
    Print troubleshooting guide
    """
    
    print("""
=== TROUBLESHOOTING GUIDE ===

❌ "Private key file not found":
   - Check file paths in SnowflakeConfig.private_key_paths
   - Ensure file exists and is readable
   - Use absolute paths or proper ~ expansion

❌ "Failed to load private key":
   - Check if key is encrypted (requires passphrase)
   - Verify key format (PEM or DER)
   - Ensure key was generated correctly

❌ "Authentication failed":
   - Verify public key is set in Snowflake user profile
   - Check that username matches exactly
   - Confirm account identifier is correct

❌ "Permission denied":
   - Check file permissions: chmod 600 private_key.pem
   - Ensure you own the private key file
   - Verify directory permissions

❌ "Connection timeout":
   - Check network connectivity
   - Verify account identifier format
   - Confirm Snowflake service is accessible

📞 SUPPORT RESOURCES:
   - Snowflake Documentation: docs.snowflake.com
   - Snowpark Python Guide: docs.snowflake.com/en/developer-guide/snowpark/python
   - Community Forums: community.snowflake.com
""")

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Snowpark Private Key Authentication Demo")
    parser.add_argument("--setup", action="store_true", help="Show setup instructions")
    parser.add_argument("--troubleshoot", action="store_true", help="Show troubleshooting guide")
    parser.add_argument("--check", action="store_true", help="Check prerequisites only")
    
    args = parser.parse_args()
    
    if args.setup:
        print_setup_instructions()
    elif args.troubleshoot:
        print_troubleshooting_guide()
    elif args.check:
        check_prerequisites()
    else:
        if check_prerequisites():
            main()
        else:
            logger.error("Prerequisites not met. Please install required libraries.")
            print_setup_instructions()


