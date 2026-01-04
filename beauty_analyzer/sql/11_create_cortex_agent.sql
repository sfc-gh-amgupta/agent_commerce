-- ============================================================================
-- AGENT COMMERCE - Cortex Agent Definition
-- ============================================================================
-- This script creates the Cortex Agent using all pre-existing tools:
--
-- PREREQUISITES (must exist before running this script):
--   - Semantic Views (03_create_semantic_views.sql)
--   - Cortex Search Services (04_create_cortex_search.sql)
--   - Agent Tools UDFs/Procedures (10_create_agent_tools.sql)
--
-- TOOL SUMMARY (16 tools):
-- ┌─────────────────────────┬─────────────────────────┬────────────────────────────────────────────────┐
-- │ Tool Name               │ Tool Type               │ Object                                         │
-- ├─────────────────────────┼─────────────────────────┼────────────────────────────────────────────────┤
-- │ CustomerAnalyst         │ cortex_analyst          │ CUSTOMERS.CUSTOMER_SEMANTIC_VIEW               │
-- │ ProductAnalyst          │ cortex_analyst          │ PRODUCTS.PRODUCT_SEMANTIC_VIEW                 │
-- │ InventoryAnalyst        │ cortex_analyst          │ INVENTORY.INVENTORY_SEMANTIC_VIEW              │
-- │ SocialAnalyst           │ cortex_analyst          │ SOCIAL.SOCIAL_PROOF_SEMANTIC_VIEW              │
-- │ CheckoutAnalyst         │ cortex_analyst          │ CART_OLTP.CART_SEMANTIC_VIEW                   │
-- │ ProductSearch           │ cortex_search           │ PRODUCTS.PRODUCT_SEARCH_SERVICE                │
-- │ SocialSearch            │ cortex_search           │ SOCIAL.SOCIAL_SEARCH_SERVICE                   │
-- │ AnalyzeFace             │ generic (function)      │ CUSTOMERS.TOOL_ANALYZE_FACE                    │
-- │ IdentifyCustomer        │ generic (function)      │ CUSTOMERS.TOOL_IDENTIFY_CUSTOMER               │
-- │ MatchProducts           │ generic (function)      │ PRODUCTS.TOOL_MATCH_PRODUCTS                   │
-- │ ACP_CreateCart          │ generic (procedure)     │ CART_OLTP.TOOL_CREATE_CART_SESSION             │
-- │ ACP_GetCart             │ generic (function)      │ CART_OLTP.TOOL_GET_CART_SESSION                │
-- │ ACP_AddItem             │ generic (procedure)     │ CART_OLTP.TOOL_ADD_TO_CART                     │
-- │ ACP_UpdateItem          │ generic (procedure)     │ CART_OLTP.TOOL_UPDATE_CART_ITEM                │
-- │ ACP_RemoveItem          │ generic (procedure)     │ CART_OLTP.TOOL_REMOVE_FROM_CART                │
-- │ ACP_Checkout            │ generic (procedure)     │ CART_OLTP.TOOL_SUBMIT_ORDER                    │
-- └─────────────────────────┴─────────────────────────┴────────────────────────────────────────────────┘
--
-- Reference: https://docs.snowflake.com/en/sql-reference/sql/create-agent
-- Generic Tools: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-rest-api#toolresource
--
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;
USE SCHEMA UTIL;

-- ============================================================================
-- CREATE CORTEX AGENT
-- ============================================================================

CREATE OR REPLACE AGENT UTIL.AGENTIC_COMMERCE_ASSISTANT
  COMMENT = 'AI Commerce Assistant with face analysis, product matching, and ACP-compliant checkout'
  PROFILE = '{"display_name": "Commerce Assistant", "avatar": "commerce-icon.png", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-4-sonnet

  orchestration:
    budget:
      seconds: 60
      tokens: 32000

  instructions:
    response: |
      You are a friendly and knowledgeable Commerce Assistant. Provide personalized 
      product recommendations based on customer preferences, skin analysis, and 
      product reviews. Always be helpful, honest, and explain concepts in 
      simple terms.
    
    orchestration: |
      Tool Selection Guide:
      
      FACE ANALYSIS & CUSTOMER IDENTIFICATION:
      - When customer uploads a face image: use AnalyzeFace to get skin tone and embedding
      - To identify a returning customer: use IdentifyCustomer with the embedding from AnalyzeFace
        IMPORTANT: Pass the embedding as a JSON string (e.g., "[0.1, 0.2, ...]"), not as an array object
      
      PRODUCT DISCOVERY:
      - Natural language product search: use ProductSearch (e.g., "vegan mascara", "hydrating foundation")
      - Find products by color match: use MatchProducts with a hex color (e.g., skin_hex from AnalyzeFace)
      - Specific product queries (price, details): use ProductAnalyst
      
      CUSTOMER & SOCIAL:
      - Customer profile, loyalty, history: use CustomerAnalyst
      - Product reviews, ratings, influencers: use SocialSearch or SocialAnalyst
      
      INVENTORY:
      - Stock availability, store locations: use InventoryAnalyst
      
      CART & CHECKOUT FLOW (ACP-Compliant):
      1. ACP_CreateCart - Start a new cart for the customer
      2. ACP_AddItem - Add products to cart (requires session_id, product_id, quantity, variant_id)
      3. ACP_GetCart - Show cart contents
      4. ACP_UpdateItem / ACP_RemoveItem - Modify cart
      5. ACP_Checkout - Complete the order
    
    system: |
      You are the AI Commerce Assistant for an upscale cosmetics retailer.
      
      CAPABILITIES:
      - Analyze face images for skin tone, lip color, undertone, Fitzpatrick type, Monk shade
      - Identify returning customers by face recognition
      - Recommend products using scientific color matching
      - Search products by name, ingredients, or description
      - Query customer profiles, loyalty points, purchase history
      - Check inventory across store locations
      - Access reviews, ratings, and influencer mentions
      - Full shopping cart management: add, update, remove items
      - Complete checkout and order processing
      
      GUIDELINES:
      - Be warm, professional, and knowledgeable
      - When customer uploads a photo, use AnalyzeFace to understand their skin
      - Explain technical terms (undertones, Fitzpatrick scale) in simple language
      - Use MatchProducts to find products complementing their skin tone
      - Always mention relevant reviews or social proof when recommending products
      - Respect customer privacy - explain what face analysis does if asked
      - For checkout, guide customers through the process step by step
    
    sample_questions:
      - question: "What lipsticks would look good on me?"
        answer: "I'd love to help! Please share a photo of your face and I'll analyze your skin tone and undertone to suggest perfect lipstick shades."
      
      - question: "I'm looking for a foundation for oily skin"
        answer: "Let me search our catalog for foundations suitable for oily skin. I'll also check the reviews to find the most recommended options."
      
      - question: "Do you have any vegan mascaras?"
        answer: "Absolutely! Let me search our product catalog for vegan and cruelty-free mascaras."
      
      - question: "Is the NARS Orgasm blush in stock?"
        answer: "Let me check the inventory for NARS Orgasm blush across our store locations."
      
      - question: "Add this lipstick to my cart"
        answer: "I'll add that to your cart right away. Would you like to continue shopping or shall I show you what's in your cart?"
      
      - question: "I want to checkout"
        answer: "Let me show you your cart first, then we can proceed to complete your order."

  tools:
    # =========================================================================
    # CORTEX ANALYST TOOLS (5) - Semantic Views for structured queries
    # =========================================================================
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: CustomerAnalyst
        description: |
          Query customer data including profiles, loyalty tier and points, 
          purchase history, skin profiles, and preferences. Use for questions 
          about specific customers or customer segments.
    
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: ProductAnalyst
        description: |
          Query structured product data including pricing, categories, variants,
          ingredients, and promotions. Use for specific product lookups, 
          filtering by attributes, or getting product details.
    
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: InventoryAnalyst
        description: |
          Query inventory levels, stock availability, and store location data.
          Use to check if products are in stock at specific stores or find
          which stores have a product available.
    
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: SocialAnalyst
        description: |
          Query aggregated social data including average ratings, review counts,
          influencer mention statistics, and trending products. Use for 
          structured queries about ratings and review metrics.
    
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: CheckoutAnalyst
        description: |
          Query cart sessions, orders, and checkout data. Use to answer 
          questions about order history, cart contents, and purchase totals.
    
    # =========================================================================
    # CORTEX SEARCH TOOLS (2) - Semantic search for discovery
    # =========================================================================
    - tool_spec:
        type: cortex_search
        name: ProductSearch
        description: |
          Semantic search across products, labels, and ingredients. Use for 
          natural language product discovery like "gentle cleanser for sensitive 
          skin", "red lipstick for warm undertones", or "products with hyaluronic 
          acid". Best for open-ended product searches.
    
    - tool_spec:
        type: cortex_search
        name: SocialSearch
        description: |
          Semantic search across product reviews, influencer mentions, and 
          social content. Use to find products mentioned for specific concerns
          like "best foundation for oily skin according to reviews" or 
          "products influencers recommend for dry skin".
    
    # =========================================================================
    # GENERIC TOOLS - Beauty Analysis (3) - Custom UDFs
    # =========================================================================
    - tool_spec:
        type: generic
        name: AnalyzeFace
        description: |
          Analyze a face image to extract skin tone, lip color, undertone, 
          Fitzpatrick type (1-6), Monk shade (1-10), and 128-dimensional face 
          embedding for customer identification. Use when customer uploads a photo.
          Returns detailed skin analysis for personalized recommendations.
        input_schema:
          type: object
          properties:
            image_base64:
              type: string
              description: Base64 encoded image of the customer's face (JPEG or PNG)
          required:
            - image_base64
    
    - tool_spec:
        type: generic
        name: IdentifyCustomer
        description: |
          Match a face embedding against stored customer face embeddings to 
          identify a returning customer. Use after AnalyzeFace to find if the
          customer has shopped before. Returns matching customers with confidence.
        input_schema:
          type: object
          properties:
            query_embedding_json:
              type: string
              description: 128-dimensional face embedding as JSON string (e.g., "[0.1, 0.2, ...]") from AnalyzeFace result
            match_threshold:
              type: number
              description: Minimum match confidence threshold (default 0.6, range 0-1)
            max_results:
              type: integer
              description: Maximum number of matching customers to return (default 5)
          required:
            - query_embedding_json
    
    - tool_spec:
        type: generic
        name: MatchProducts
        description: |
          Find products that match a target color using color distance algorithm.
          Use to recommend products (lipstick, foundation, eyeshadow, blush) that 
          complement the customer's skin tone or lip color from AnalyzeFace.
        input_schema:
          type: object
          properties:
            target_hex:
              type: string
              description: Target color in hex format (e.g., "#E75480" or "#8B4513")
            category_filter:
              type: string
              description: Optional product category to filter (lipstick, foundation, eyeshadow, blush)
            limit_results:
              type: integer
              description: Maximum number of color matches to return (default 10)
          required:
            - target_hex
    
    # =========================================================================
    # GENERIC TOOLS - ACP Cart/Checkout (6) - Stored Procedures for transactions
    # ACP = Agentic Commerce Protocol (OpenAI standard)
    # =========================================================================
    - tool_spec:
        type: generic
        name: ACP_CreateCart
        description: |
          Create a new cart session for a customer. Call this first before 
          adding items. Returns a session_id for subsequent cart operations.
        input_schema:
          type: object
          properties:
            customer_id:
              type: string
              description: Customer ID to create the cart session for
          required:
            - customer_id
    
    - tool_spec:
        type: generic
        name: ACP_GetCart
        description: |
          Get current cart contents including all items, quantities, prices 
          (in cents), item count, and subtotal. Use to show the customer their cart.
        input_schema:
          type: object
          properties:
            session_id:
              type: string
              description: Cart session ID
          required:
            - session_id
    
    - tool_spec:
        type: generic
        name: ACP_AddItem
        description: |
          Add a product to the customer's cart. Returns the added item 
          details including price in cents.
        input_schema:
          type: object
          properties:
            session_id:
              type: string
              description: Cart session ID
            product_id:
              type: string
              description: Product ID to add to cart
            quantity:
              type: integer
              description: Quantity to add
            variant_id:
              type: string
              description: Optional variant ID if product has variants (pass null if not needed)
          required:
            - session_id
            - product_id
            - quantity
    
    - tool_spec:
        type: generic
        name: ACP_UpdateItem
        description: |
          Update the quantity of an item already in the cart.
        input_schema:
          type: object
          properties:
            item_id:
              type: string
              description: Cart item ID to update (from ACP_GetCart)
            new_quantity:
              type: integer
              description: New quantity for the item
          required:
            - item_id
            - new_quantity
    
    - tool_spec:
        type: generic
        name: ACP_RemoveItem
        description: |
          Remove an item from the cart completely.
        input_schema:
          type: object
          properties:
            item_id:
              type: string
              description: Cart item ID to remove (from ACP_GetCart)
          required:
            - item_id
    
    - tool_spec:
        type: generic
        name: ACP_Checkout
        description: |
          Finalize the checkout and create an order. Processes all cart items,
          creates the order record, and returns confirmation with order_id, 
          order_number, total in cents and dollars, and status.
        input_schema:
          type: object
          properties:
            session_id:
              type: string
              description: Cart session ID to submit as order
          required:
            - session_id

  # ===========================================================================
  # TOOL RESOURCES - Map tools to Snowflake objects
  # ===========================================================================
  tool_resources:
    # Cortex Analyst -> Semantic Views (require execution_environment with warehouse)
    CustomerAnalyst:
      semantic_view: AGENT_COMMERCE.CUSTOMERS.CUSTOMER_SEMANTIC_VIEW
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 60
    
    ProductAnalyst:
      semantic_view: AGENT_COMMERCE.PRODUCTS.PRODUCT_SEMANTIC_VIEW
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 60
    
    InventoryAnalyst:
      semantic_view: AGENT_COMMERCE.INVENTORY.INVENTORY_SEMANTIC_VIEW
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 60
    
    SocialAnalyst:
      semantic_view: AGENT_COMMERCE.SOCIAL.SOCIAL_PROOF_SEMANTIC_VIEW
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 60
    
    CheckoutAnalyst:
      semantic_view: AGENT_COMMERCE.CART_OLTP.CART_SEMANTIC_VIEW
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 60
    
    # Cortex Search -> Search Services
    ProductSearch:
      search_service: AGENT_COMMERCE.PRODUCTS.PRODUCT_SEARCH_SERVICE
      max_results: 10
      title_column: title
      id_column: id
    
    SocialSearch:
      search_service: AGENT_COMMERCE.SOCIAL.SOCIAL_SEARCH_SERVICE
      max_results: 10
      title_column: title
      id_column: id
    
    # Generic -> UDFs (type: function)
    AnalyzeFace:
      type: function
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 60
      identifier: AGENT_COMMERCE.CUSTOMERS.TOOL_ANALYZE_FACE
    
    IdentifyCustomer:
      type: function
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 30
      identifier: AGENT_COMMERCE.CUSTOMERS.TOOL_IDENTIFY_CUSTOMER
    
    MatchProducts:
      type: function
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 30
      identifier: AGENT_COMMERCE.PRODUCTS.TOOL_MATCH_PRODUCTS
    
    ACP_GetCart:
      type: function
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 30
      identifier: AGENT_COMMERCE.CART_OLTP.TOOL_GET_CART_SESSION
    
    # Generic -> ACP Stored Procedures (type: procedure)
    ACP_CreateCart:
      type: procedure
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 30
      identifier: AGENT_COMMERCE.CART_OLTP.TOOL_CREATE_CART_SESSION
    
    ACP_AddItem:
      type: procedure
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 30
      identifier: AGENT_COMMERCE.CART_OLTP.TOOL_ADD_TO_CART
    
    ACP_UpdateItem:
      type: procedure
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 30
      identifier: AGENT_COMMERCE.CART_OLTP.TOOL_UPDATE_CART_ITEM
    
    ACP_RemoveItem:
      type: procedure
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 30
      identifier: AGENT_COMMERCE.CART_OLTP.TOOL_REMOVE_FROM_CART
    
    ACP_Checkout:
      type: procedure
      execution_environment:
        type: warehouse
        warehouse: AGENT_COMMERCE_WH
        query_timeout: 60
      identifier: AGENT_COMMERCE.CART_OLTP.TOOL_SUBMIT_ORDER
  $$;

-- Grant usage on the agent
GRANT USAGE ON AGENT UTIL.AGENTIC_COMMERCE_ASSISTANT TO ROLE AGENT_COMMERCE_ROLE;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT '✅ Cortex Agent Created Successfully!' AS status;

-- Describe the agent
DESCRIBE AGENT UTIL.AGENTIC_COMMERCE_ASSISTANT;

-- Show all agents
SHOW AGENTS IN SCHEMA UTIL;

-- ============================================================================
-- USAGE EXAMPLE
-- ============================================================================
-- 
-- To interact with the agent, use the Cortex Agent REST API:
-- 
-- POST /api/v2/databases/AGENT_COMMERCE/schemas/UTIL/agents/AGENTIC_COMMERCE_ASSISTANT/runs
-- {
--   "messages": [
--     {"role": "user", "content": "What lipsticks do you recommend for warm undertones?"}
--   ]
-- }
--
-- Or use Snowsight's Cortex Agent UI if available.
--
-- ============================================================================
-- END
-- ============================================================================

