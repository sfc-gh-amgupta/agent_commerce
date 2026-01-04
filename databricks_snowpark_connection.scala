/*
================================================================================
DATABRICKS TO SNOWFLAKE CONNECTION USING SNOWPARK (SCALA)
================================================================================
This notebook demonstrates how to connect from Databricks to Snowflake using
Snowpark for Scala. It includes authentication methods and common data operations.

Prerequisites:
1. Install Snowpark Scala library in Databricks cluster
2. Configure authentication credentials (secrets recommended)
3. Ensure network connectivity between Databricks and Snowflake

Author: Snowflake Solutions Engineering
Last Updated: January 2025
================================================================================
*/

// COMMAND ----------
// MAGIC %md
// MAGIC # Databricks to Snowflake Connection with Snowpark (Scala)
// MAGIC 
// MAGIC This notebook demonstrates connecting from Databricks to Snowflake using Snowpark for Scala.
// MAGIC 
// MAGIC ## Setup Requirements
// MAGIC 1. **Install Snowpark**: Add Snowpark Scala library to your cluster
// MAGIC 2. **Configure Secrets**: Store credentials in Databricks secrets
// MAGIC 3. **Network Access**: Ensure Databricks can reach Snowflake endpoints

// COMMAND ----------
// MAGIC %md
// MAGIC ## 1. Import Required Libraries

// COMMAND ----------

import com.snowflake.snowpark._
import com.snowflake.snowpark.functions._
import com.snowflake.snowpark.types._
import scala.util.{Try, Success, Failure}
import java.util.Properties
import java.io.FileInputStream
import java.security.PrivateKey
import java.security.spec.PKCS8EncodedKeySpec
import java.security.KeyFactory
import java.util.Base64
import javax.crypto.EncryptedPrivateKeyInfo
import javax.crypto.Cipher
import javax.crypto.spec.PBEKeySpec
import javax.crypto.SecretKeyFactory

// COMMAND ----------
// MAGIC %md
// MAGIC ## 2. Authentication Methods
// MAGIC 
// MAGIC ### Method 1: Username/Password Authentication

// COMMAND ----------

def createSnowflakeSessionPassword(): Option[Session] = {
  /**
   * Create Snowflake session using username/password authentication
   * Credentials should be stored in Databricks secrets for security
   */
  
  try {
    // Retrieve credentials from Databricks secrets (recommended approach)
    val connectionProperties = Map(
      "URL" -> s"https://${dbutils.secrets.get("snowflake-secrets", "account")}.snowflakecomputing.com",
      "USER" -> dbutils.secrets.get("snowflake-secrets", "username"),
      "PASSWORD" -> dbutils.secrets.get("snowflake-secrets", "password"),
      "ROLE" -> dbutils.secrets.get("snowflake-secrets", "role"),
      "WAREHOUSE" -> dbutils.secrets.get("snowflake-secrets", "warehouse"),
      "DB" -> dbutils.secrets.get("snowflake-secrets", "database"),
      "SCHEMA" -> dbutils.secrets.get("snowflake-secrets", "schema")
    )
    
    // Create Snowpark session
    val session = Session.builder.configs(connectionProperties).create
    
    println("✅ Successfully connected to Snowflake using username/password")
    println(s"Current role: ${session.getCurrentRole}")
    println(s"Current warehouse: ${session.getCurrentWarehouse}")
    println(s"Current database: ${session.getCurrentDatabase}")
    println(s"Current schema: ${session.getCurrentSchema}")
    
    Some(session)
    
  } catch {
    case e: Exception =>
      println(s"❌ Error creating session with password auth: ${e.getMessage}")
      
      // Fallback to hardcoded values (NOT RECOMMENDED for production)
      println("Using hardcoded values for demo (NOT RECOMMENDED for production)")
      
      val fallbackProperties = Map(
        "URL" -> "https://your_account_identifier.snowflakecomputing.com",
        "USER" -> "your_username",
        "PASSWORD" -> "your_password",
        "ROLE" -> "your_role",
        "WAREHOUSE" -> "your_warehouse",
        "DB" -> "your_database",
        "SCHEMA" -> "your_schema"
      )
      
      try {
        val session = Session.builder.configs(fallbackProperties).create
        Some(session)
      } catch {
        case ex: Exception =>
          println(s"❌ Fallback connection also failed: ${ex.getMessage}")
          None
      }
  }
}

// COMMAND ----------
// MAGIC %md
// MAGIC ### Method 2: Key Pair Authentication (Recommended for Production)

// COMMAND ----------

def createSnowflakeSessionKeyPair(): Option[Session] = {
  /**
   * Create Snowflake session using RSA key pair authentication
   * This is the recommended method for production environments
   */
  
  try {
    // Read private key from Databricks secrets
    val privateKeyContent = dbutils.secrets.get("snowflake-secrets", "private-key")
    
    // Parse the private key
    val privateKey = parsePrivateKey(privateKeyContent)
    
    val connectionProperties = Map(
      "URL" -> s"https://${dbutils.secrets.get("snowflake-secrets", "account")}.snowflakecomputing.com",
      "USER" -> dbutils.secrets.get("snowflake-secrets", "username"),
      "PRIVATE_KEY" -> privateKey,
      "ROLE" -> dbutils.secrets.get("snowflake-secrets", "role"),
      "WAREHOUSE" -> dbutils.secrets.get("snowflake-secrets", "warehouse"),
      "DB" -> dbutils.secrets.get("snowflake-secrets", "database"),
      "SCHEMA" -> dbutils.secrets.get("snowflake-secrets", "schema")
    )
    
    val session = Session.builder.configs(connectionProperties).create
    
    println("✅ Successfully connected to Snowflake using key pair authentication")
    println(s"Current role: ${session.getCurrentRole}")
    println(s"Current warehouse: ${session.getCurrentWarehouse}")
    
    Some(session)
    
  } catch {
    case e: Exception =>
      println(s"❌ Error creating session with key pair auth: ${e.getMessage}")
      None
  }
}

def parsePrivateKey(privateKeyContent: String): PrivateKey = {
  /**
   * Parse private key from PEM format string
   */
  
  // Remove PEM headers and whitespace
  val privateKeyPEM = privateKeyContent
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace("-----BEGIN RSA PRIVATE KEY-----", "")
    .replace("-----END RSA PRIVATE KEY-----", "")
    .replaceAll("\\s", "")
  
  // Decode base64
  val decoded = Base64.getDecoder.decode(privateKeyPEM)
  
  // Create private key
  val keySpec = new PKCS8EncodedKeySpec(decoded)
  val keyFactory = KeyFactory.getInstance("RSA")
  keyFactory.generatePrivate(keySpec)
}

// COMMAND ----------
// MAGIC %md
// MAGIC ## 3. Establish Connection

// COMMAND ----------

// Create Snowflake session (choose your preferred method)
val snowflakeSession: Option[Session] = createSnowflakeSessionPassword()

// Alternative: Use key pair authentication
// val snowflakeSession: Option[Session] = createSnowflakeSessionKeyPair()

// COMMAND ----------
// MAGIC %md
// MAGIC ## 4. Basic Snowpark Operations

// COMMAND ----------

def testSnowflakeConnection(sessionOpt: Option[Session]): Unit = {
  /**
   * Test the Snowflake connection with basic operations
   */
  
  sessionOpt match {
    case Some(session) =>
      try {
        // Test 1: Get current session information
        println("=== Session Information ===")
        println(s"Account: ${session.getCurrentAccount}")
        println(s"User: ${session.getCurrentUser}")
        println(s"Role: ${session.getCurrentRole}")
        println(s"Warehouse: ${session.getCurrentWarehouse}")
        println(s"Database: ${session.getCurrentDatabase}")
        println(s"Schema: ${session.getCurrentSchema}")
        
        // Test 2: Simple query
        println("\n=== Simple Query Test ===")
        val result = session.sql("SELECT CURRENT_TIMESTAMP() as current_time").collect()
        println(s"Current Snowflake time: ${result.head.getString(0)}")
        
        // Test 3: Show tables in current schema
        println("\n=== Available Tables ===")
        val tablesResult = session.sql("SHOW TABLES").collect()
        if (tablesResult.nonEmpty) {
          tablesResult.take(5).foreach { row =>
            println(s"- ${row.getString("name")}")
          }
        } else {
          println("No tables found in current schema")
        }
        
        println("\n✅ Connection test completed successfully!")
        
      } catch {
        case e: Exception =>
          println(s"❌ Connection test failed: ${e.getMessage}")
      }
      
    case None =>
      println("❌ No valid session available")
  }
}

// Run connection test
testSnowflakeConnection(snowflakeSession)

// COMMAND ----------
// MAGIC %md
// MAGIC ## 5. Data Operations Examples

// COMMAND ----------

def demonstrateSnowparkOperations(sessionOpt: Option[Session]): Unit = {
  /**
   * Demonstrate common Snowpark operations for data analysis
   */
  
  sessionOpt match {
    case Some(session) =>
      try {
        // Example 1: Create a sample DataFrame
        println("=== Creating Sample Data ===")
        
        // Create sample data
        val sampleData = Seq(
          Row("Alice", "Engineering", 75000, "2020-01-15"),
          Row("Bob", "Marketing", 65000, "2019-03-20"),
          Row("Charlie", "Sales", 70000, "2021-06-10"),
          Row("Diana", "Engineering", 80000, "2018-11-05"),
          Row("Eve", "Marketing", 68000, "2022-02-28")
        )
        
        // Define schema
        val schema = StructType(Seq(
          StructField("name", StringType),
          StructField("department", StringType),
          StructField("salary", IntegerType),
          StructField("hire_date", StringType)
        ))
        
        // Create Snowpark DataFrame
        val df = session.createDataFrame(sampleData, schema)
        
        // Show the data
        println("Sample employee data:")
        df.show()
        
        // Example 2: Data transformations
        println("\n=== Data Transformations ===")
        
        // Filter and select
        val highEarners = df.filter(col("salary") > lit(70000))
          .select(col("name"), col("department"), col("salary"))
        
        println("Employees earning > $70,000:")
        highEarners.show()
        
        // Group by and aggregate
        val deptStats = df.groupBy(col("department"))
          .agg(
            sum(col("salary")).as("total_salary"),
            count(col("salary")).as("employee_count")
          )
        
        println("Department statistics:")
        deptStats.show()
        
        // Example 3: Advanced transformations
        println("\n=== Advanced Transformations ===")
        
        // Add calculated columns
        val enrichedDf = df.select(
          col("*"),
          when(col("salary") > lit(70000), lit("High"))
            .when(col("salary") > lit(60000), lit("Medium"))
            .otherwise(lit("Low")).as("salary_band"),
          year(to_date(col("hire_date"), "yyyy-MM-dd")).as("hire_year")
        )
        
        println("Enriched employee data:")
        enrichedDf.show()
        
        // Example 4: Write to Snowflake table (optional)
        println("\n=== Writing to Snowflake ===")
        
        // Uncomment to actually write data
        // val tableName = "SAMPLE_EMPLOYEES"
        // df.write.mode(SaveMode.Overwrite).saveAsTable(tableName)
        // println(s"Data written to table: $tableName")
        
        println("✅ Snowpark operations completed successfully!")
        
      } catch {
        case e: Exception =>
          println(s"❌ Snowpark operations failed: ${e.getMessage}")
      }
      
    case None =>
      println("❌ No valid session available")
  }
}

// Run Snowpark operations demo
demonstrateSnowparkOperations(snowflakeSession)

// COMMAND ----------
// MAGIC %md
// MAGIC ## 6. Reading Data from Snowflake Tables

// COMMAND ----------

def readSnowflakeData(sessionOpt: Option[Session], tableName: String): Option[DataFrame] = {
  /**
   * Read data from a Snowflake table
   */
  
  sessionOpt match {
    case Some(session) =>
      try {
        println(s"=== Reading data from $tableName ===")
        
        // Method 1: Using table() function
        val snowparkDf = session.table(tableName)
        
        // Show basic info
        println("Table schema:")
        snowparkDf.schema.printTreeString()
        
        println("\nFirst 10 rows:")
        snowparkDf.limit(10).show()
        
        // Method 2: Using SQL
        val sqlDf = session.sql(s"SELECT * FROM $tableName LIMIT 100")
        
        println(s"\nDataFrame count: ${sqlDf.count()}")
        println(s"Columns: ${sqlDf.schema.fields.map(_.name).mkString(", ")}")
        
        Some(sqlDf)
        
      } catch {
        case e: Exception =>
          println(s"❌ Error reading data from $tableName: ${e.getMessage}")
          None
      }
      
    case None =>
      println("❌ No valid session available")
      None
  }
}

// Example usage (replace with your actual table name)
// val df = readSnowflakeData(snowflakeSession, "YOUR_TABLE_NAME")

// COMMAND ----------
// MAGIC %md
// MAGIC ## 7. Advanced Snowpark Features

// COMMAND ----------

def advancedSnowparkFeatures(sessionOpt: Option[Session]): Unit = {
  /**
   * Demonstrate advanced Snowpark features
   */
  
  sessionOpt match {
    case Some(session) =>
      try {
        println("=== Advanced Snowpark Features ===")
        
        // Feature 1: User Defined Functions (UDFs)
        import session.implicits._
        
        // Register a UDF
        val squareUdf = session.udf.registerTemporary("square_udf", (x: Int) => x * x)
        
        // Create sample data to test UDF
        val sampleNumbers = Seq(1, 2, 3, 4, 5).toDF("number")
        val numbersDf = session.createDataFrame(sampleNumbers.rdd, 
          StructType(Seq(StructField("number", IntegerType))))
        
        // Apply UDF
        val result = numbersDf.select(
          col("number"),
          callUDF("square_udf", col("number")).as("squared")
        )
        
        println("UDF Example - Square function:")
        result.show()
        
        // Feature 2: Window functions
        import com.snowflake.snowpark.Window
        
        // Create sample sales data
        val salesData = Seq(
          Row("Alice", "Q1", 1000),
          Row("Bob", "Q1", 1200),
          Row("Alice", "Q2", 1100),
          Row("Bob", "Q2", 1300),
          Row("Charlie", "Q1", 900),
          Row("Charlie", "Q2", 1050)
        )
        
        val salesSchema = StructType(Seq(
          StructField("salesperson", StringType),
          StructField("quarter", StringType),
          StructField("sales_amount", IntegerType)
        ))
        
        val salesDf = session.createDataFrame(salesData, salesSchema)
        
        // Define window specification
        val windowSpec = Window.partitionBy(col("quarter")).orderBy(col("sales_amount").desc)
        
        // Apply window functions
        val rankedSales = salesDf.select(
          col("*"),
          row_number().over(windowSpec).as("row_num"),
          rank().over(windowSpec).as("rank")
        )
        
        println("\nWindow Function Example - Sales Ranking:")
        rankedSales.show()
        
        // Feature 3: Joins between DataFrames
        // Create department data
        val deptData = Seq(
          Row("Alice", "Engineering"),
          Row("Bob", "Sales"),
          Row("Charlie", "Marketing")
        )
        
        val deptSchema = StructType(Seq(
          StructField("salesperson", StringType),
          StructField("department", StringType)
        ))
        
        val deptDf = session.createDataFrame(deptData, deptSchema)
        
        // Join sales and department data
        val joinedDf = salesDf.join(deptDf, 
          salesDf.col("salesperson") === deptDf.col("salesperson"))
          .select(
            salesDf.col("salesperson"),
            deptDf.col("department"),
            salesDf.col("quarter"),
            salesDf.col("sales_amount")
          )
        
        println("\nJoin Example - Sales with Departments:")
        joinedDf.show()
        
        println("✅ Advanced features demonstration completed!")
        
      } catch {
        case e: Exception =>
          println(s"❌ Advanced features demonstration failed: ${e.getMessage}")
      }
      
    case None =>
      println("❌ No valid session available")
  }
}

// Run advanced features demo
advancedSnowparkFeatures(snowflakeSession)

// COMMAND ----------
// MAGIC %md
// MAGIC ## 8. Integration with Databricks DataFrames

// COMMAND ----------

def integrateWithDatabricks(sessionOpt: Option[Session]): Unit = {
  /**
   * Demonstrate integration between Snowpark and Databricks Spark DataFrames
   */
  
  sessionOpt match {
    case Some(session) =>
      try {
        println("=== Databricks Integration ===")
        
        // Create a Databricks DataFrame
        val databricksData = Seq(
          ("Product A", 100, 25.50),
          ("Product B", 150, 30.00),
          ("Product C", 75, 45.25),
          ("Product D", 200, 15.75)
        )
        
        val databricksDf = spark.createDataFrame(databricksData)
          .toDF("product_name", "quantity", "price")
        
        println("Databricks DataFrame:")
        databricksDf.show()
        
        // Convert Databricks DataFrame to Snowpark DataFrame
        // Note: This requires converting through RDD or collecting data
        val collectedData = databricksDf.collect().map { row =>
          Row(row.getString(0), row.getInt(1), row.getDouble(2))
        }
        
        val schema = StructType(Seq(
          StructField("product_name", StringType),
          StructField("quantity", IntegerType),
          StructField("price", DoubleType)
        ))
        
        val snowparkDf = session.createDataFrame(collectedData, schema)
        
        println("Converted to Snowpark DataFrame:")
        snowparkDf.show()
        
        // Perform calculations in Snowpark
        val enrichedDf = snowparkDf.select(
          col("*"),
          (col("quantity") * col("price")).as("total_value")
        )
        
        println("Enriched with calculations:")
        enrichedDf.show()
        
        println("✅ Databricks integration completed successfully!")
        
      } catch {
        case e: Exception =>
          println(s"❌ Databricks integration failed: ${e.getMessage}")
      }
      
    case None =>
      println("❌ No valid session available")
  }
}

// Run Databricks integration demo
integrateWithDatabricks(snowflakeSession)

// COMMAND ----------
// MAGIC %md
// MAGIC ## 9. Cleanup and Best Practices

// COMMAND ----------

def cleanupSession(sessionOpt: Option[Session]): Unit = {
  /**
   * Properly close Snowflake session and cleanup resources
   */
  
  sessionOpt match {
    case Some(session) =>
      try {
        session.close()
        println("✅ Snowflake session closed successfully")
      } catch {
        case e: Exception =>
          println(s"⚠️  Error closing session: ${e.getMessage}")
      }
      
    case None =>
      println("ℹ️  No session to close")
  }
}

// Best Practices Summary
println("""
=== BEST PRACTICES FOR DATABRICKS-SNOWFLAKE INTEGRATION (SCALA) ===

1. 🔐 SECURITY
   - Use Databricks secrets for credentials
   - Prefer key-pair authentication over passwords
   - Implement proper error handling with Try/Success/Failure
   - Never hardcode credentials in notebooks

2. 📊 PERFORMANCE
   - Use lazy evaluation with DataFrames
   - Leverage Snowpark's pushdown optimizations
   - Consider data locality and transfer costs
   - Use appropriate data types and schemas

3. 🔄 DATA MANAGEMENT
   - Use Option types for null safety
   - Implement proper pattern matching for error handling
   - Use case classes for structured data
   - Document data transformations clearly

4. 💰 COST OPTIMIZATION
   - Auto-suspend warehouses when not in use
   - Right-size compute resources based on workload
   - Use result caching effectively
   - Monitor and optimize query performance

5. 🛠️ OPERATIONAL
   - Use immutable data structures
   - Implement proper logging with structured output
   - Use version control for notebooks
   - Test thoroughly in development environments
""")

// Cleanup (uncomment when done)
// cleanupSession(snowflakeSession)

// COMMAND ----------
// MAGIC %md
// MAGIC ## 10. Error Handling and Utilities

// COMMAND ----------

// Utility functions for better error handling
object SnowflakeUtils {
  
  def safeExecute[T](operation: => T): Try[T] = {
    Try(operation)
  }
  
  def executeWithRetry[T](operation: => T, maxRetries: Int = 3): Try[T] = {
    def retry(attempt: Int): Try[T] = {
      safeExecute(operation) match {
        case Success(result) => Success(result)
        case Failure(exception) if attempt < maxRetries =>
          println(s"Attempt $attempt failed, retrying... Error: ${exception.getMessage}")
          Thread.sleep(1000 * attempt) // Exponential backoff
          retry(attempt + 1)
        case Failure(exception) =>
          Failure(exception)
      }
    }
    retry(1)
  }
  
  def validateConnection(session: Session): Boolean = {
    safeExecute {
      session.sql("SELECT 1").collect()
      true
    }.getOrElse(false)
  }
}

// Example usage of utility functions
snowflakeSession.foreach { session =>
  SnowflakeUtils.executeWithRetry {
    val result = session.sql("SELECT CURRENT_TIMESTAMP()").collect()
    println(s"Retry example result: ${result.head.getString(0)}")
  } match {
    case Success(_) => println("✅ Operation succeeded")
    case Failure(e) => println(s"❌ Operation failed after retries: ${e.getMessage}")
  }
}

println("""
=== TROUBLESHOOTING COMMON ISSUES (SCALA) ===

❌ COMPILATION ISSUES:
   - Ensure Snowpark Scala library is properly installed
   - Check Scala version compatibility
   - Verify import statements are correct
   - Use proper type annotations

❌ RUNTIME ERRORS:
   - Use Try/Success/Failure for error handling
   - Check Option types for null safety
   - Validate DataFrame schemas before operations
   - Monitor memory usage with large datasets

❌ PERFORMANCE ISSUES:
   - Use lazy evaluation appropriately
   - Avoid collecting large DataFrames
   - Leverage Snowpark pushdown optimizations
   - Profile query execution plans

📞 SUPPORT RESOURCES:
   - Snowflake Scala Documentation
   - Databricks Scala Guides
   - Snowpark API Reference
   - Community Forums and Stack Overflow
""")


