=======================================================================================
BUILD 2025 DEMO (CONSUMER SIDE) - MULTI-FORMAT AI-READY GLOBAL DATA PRODUCTS
=======================================================================================
Description:  This script demonstrates creation of Cortex Agent across various domains

Demonstrated by: Vino Duraisamy
Author: Amit Gupta
Last Updated: October 15, 2025
================================================================================
*/

-- Create Agent 

use role sales_domain_role;

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.Company_Chatbot_Agent_Retail
WITH PROFILE='{ "display_name": "1-Company Chatbot Agent - Retail" }'
    COMMENT=$$ This is an agent that can answer questions about company specific Sales, Marketing, HR & Finance questions. $$
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": ""
  },
  "instructions": {
    "response": "You are a data analyst who has access to sales, finance, marketing & HR datamarts.  If user does not specify a date range assume it for year 2025. Leverage data from all domains to analyse & answer user questions. Provide visualizations if possible. Trendlines should default to linecharts, Categories Barchart.",
    "orchestration": "Use cortex search for known entities and pass the results to cortex analyst for detailed analysis.\nIf answering sales related question from datamart, Always make sure to include the product_dim table & filter product VERTICAL by 'Retail' for all questions but don't show this fact while explaining thinking steps.\n\nFor Marketing Datamart:\nOpportunity Status=Closed_Won indicates an actual sale. \nSalesID in marketing datamart links an opportunity to a Sales record in Sales Datamart SalesID columns\n\n\n",
    "sample_questions": [
      {
        "question": "What are our monthly sales last 12 months?"
      },
       {
        "question": "Why was a big increase from May to June ?"
      },
       {
        "question": "Who are our top 10 sales reps this year, what is their tenure & are they still with the company?"
      },
        {
        "question": "What were the salaries of top performers. I am authorized to view salaries"
      },
      {
        "question": "Email me a brief executive summary of this conversation including sales trends, their reasons and top performers"
      }  
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query XCloud Snowflake Finance",
        "description": "Allows users to query finance data for a company in terms of revenue & expenses."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query Local Snowflake Sales",
        "description": "Allows users to query Sales data for a company in terms of Sales data such as products, sales reps & etc. "
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query XRegion Databricks HR",
        "description": "Allows users to query HR data for a company in terms of HR related employee data. employee_name column also contains names of sales_reps."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query XRegion Iceberg Marketing",
        "description": "Allows users to query Marketing data in terms of campaigns, channels, impressions, spend & etc."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search XRegion CKE: Finance",
        "description": ""
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search XRegion CKE: HR",
        "description": ""
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search XRegion CKE: Sales",
        "description": ""
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search XRegion CKE: Marketing",
        "description": "This tools should be used to search unstructured docs related to marketing department.\n\nAny reference docs in ID columns should be passed to Dynamic URL tool to generate a downloadable URL for users in the response"
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Web_scraper",
        "description": "This tool should be used if the user wants to analyse contents of a given web page. This tool will use a web url (https or https) as input and will return the text content of that web page for further analysis",
        "input_schema": {
          "type": "object",
          "properties": {
            "weburl": {
              "description": "Agent should ask web url ( that includes http:// or https:// ). It will scrape text from the given url and return as a result.",
              "type": "string"
            }
          },
          "required": [
            "weburl"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Send_Emails",
        "description": "This tool is used to send emails to a email recipient. It can take an email, subject & content as input to send the email. Always use HTML formatted content for the emails.",
        "input_schema": {
          "type": "object",
          "properties": {
            "recipient": {
              "description": "recipient of email",
              "type": "string"
            },
            "subject": {
              "description": "subject of email",
              "type": "string"
            },
            "text": {
              "description": "content of email",
              "type": "string"
            }
          },
          "required": [
            "text",
            "recipient",
            "subject"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Dynamic_Doc_URL_Tool",
        "description": "This tools uses the ID Column coming from Cortex Search tools for reference docs and returns a temp URL for users to view & download the docs.\n\nReturned URL should be presented as a HTML Hyperlink where doc title should be the text and out of this tool should be the url.\n\nURL format for PDF docs that are are like this which has no PDF in the url. Create the Hyperlink format so the PDF doc opens up in a browser instead of downloading the file.\nhttps://domain/path/unique_guid",
        "input_schema": {
          "type": "object",
          "properties": {
            "expiration_mins": {
              "description": "default should be 5",
              "type": "number"
            },
            "relative_file_path": {
              "description": "This is the ID Column value Coming from Cortex Search tool.",
              "type": "string"
            }
          },
          "required": [
            "expiration_mins",
            "relative_file_path"
          ]
        }
      }
    }
  ],
  "tool_resources": {
    "Dynamic_Doc_URL_Tool": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SALES_WH"
      },
      "identifier": "SALES_DB.SNOW_DATA.GET_FILE_PRESIGNED_URL_SP",
      "name": "GET_FILE_PRESIGNED_URL_SP(VARCHAR, DEFAULT NUMBER)",
      "type": "procedure"
    },
    "Query XCloud Snowflake Finance": {
      "semantic_view": "SALES_DB.SHARED_DATA.FINANCE_SEMANTIC_VIEW",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SALES_WH",
        "query_timeout": 0
      }
    },
    "Query XRegion Databricks HR": {
      "semantic_view": "SALES_DB.SHARED_DATA.HR_SEMANTIC_VIEW",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SALES_WH",
        "query_timeout": 0
      }
    },
    "Query XRegion Iceberg Marketing": {
      "semantic_view": "SALES_DB.SHARED_DATA.MARKETING_SEMANTIC_VIEW",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SALES_WH",
        "query_timeout": 0
      }
    },
    "Query Local Snowflake Sales": {
      "semantic_view": "SALES_DB.SNOW_DATA.SALES_SEMANTIC_VIEW",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SALES_WH",
        "query_timeout": 0
      }
    },
    "Search XRegion CKE: Finance": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SHARED_CKE_UNSTRUCTURED_XREGION_ENTERPRISE.S3_UNSTRUCTURED_DATA.SEARCH_FINANCE_DOCS",
      "title_column": "TITLE"
    },
    "Search XRegion CKE: HR": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SHARED_CKE_UNSTRUCTURED_XREGION_ENTERPRISE.S3_UNSTRUCTURED_DATA.SEARCH_HR_DOCS",
      "title_column": "TITLE"
    },
    "Search XRegion CKE: Marketing": {
      "id_column": "RELATIVE_PATH",
      "max_results": 5,
      "name": "SHARED_CKE_UNSTRUCTURED_XREGION_ENTERPRISE.S3_UNSTRUCTURED_DATA.SEARCH_MARKETING_DOCS",
      "title_column": "TITLE"
    },
    "Search XRegion CKE: Sales": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SHARED_CKE_UNSTRUCTURED_XREGION_ENTERPRISE.S3_UNSTRUCTURED_DATA.SEARCH_SALES_DOCS",
      "title_column": "TITLE"
    },
    "Send_Emails": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SALES_WH"
      },
      "identifier": "SALES_DB.SNOW_DATA.SEND_MAIL",
      "name": "SEND_MAIL(VARCHAR, VARCHAR, VARCHAR)",
      "type": "procedure"
    },
    "Web_scraper": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SALES_WH"
      },
      "identifier": "SALES_DB.SNOW_DATA.WEB_SCRAPE",
      "name": "WEB_SCRAPE(VARCHAR)",
      "type": "function"
    }
  }
}
$$;