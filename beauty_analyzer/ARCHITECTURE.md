# Beauty Analyzer - Architecture Documentation

> AI-Powered Beauty Advisor with Face Recognition, Skin Analysis, and Product Matching
> 
> Powered by Snowflake Cortex Agent + Snowpark Container Services

---

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Cortex Agent Design](#cortex-agent-design)
- [Tool Catalog](#tool-catalog)
- [Data Layer](#data-layer)
- [Chatbot Widget Design](#chatbot-widget-design)
- [Customization System](#customization-system)
- [Module Structure](#module-structure)
- [User Flow](#user-flow)
- [Deployment Guide](#deployment-guide)

---

## Overview

### What This App Does

1. **Face Recognition** — Identifies returning customers using face embeddings (dlib + Cortex Vector Search)
2. **Skin Tone Analysis** — Detects skin color, Fitzpatrick type, Monk scale, undertone
3. **Lip Color Analysis** — Detects lip color with makeup detection
4. **Product Matching** — Recommends cosmetics using CIEDE2000 color distance
5. **Social Proof** — Surfaces reviews, influencer mentions, trending products
6. **Agentic Checkout** — Complete checkout flow with OpenAI spec compatibility

### Technology Stack

| Component | Technology |
|-----------|------------|
| **AI Brain** | Snowflake Cortex Agent |
| **Frontend** | React.js Chatbot Widget (embeddable) |
| **Backend** | FastAPI (Python) in SPCS |
| **Face Detection** | MediaPipe Face Mesh (468 landmarks) |
| **Face Recognition** | dlib ResNet (128-dim embeddings) |
| **Customer Identification** | Cortex Vector Search (ANN) |
| **Product/Social Search** | Cortex Search (semantic) |
| **Structured Queries** | Cortex Analyst + Semantic Views |
| **Label Extraction** | AI_EXTRACT |
| **Color Distance** | CIEDE2000 (ΔE00) |
| **Deployment** | Snowpark Container Services (SPCS) |

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              USER LAYER                                          │
│  ┌─────────────────────┐      ┌─────────────────────────────────────────────┐   │
│  │  Retailer Website   │ ──── │  Chatbot Widget (React.js)                  │   │
│  └─────────────────────┘      └─────────────────────────────────────────────┘   │
└───────────────────────────────────────────┬─────────────────────────────────────┘
                                            │
                                            ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           SNOWFLAKE ACCOUNT                                      │
│                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                         SPCS CONTAINER                                     │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐   │  │
│  │  │  FastAPI        │  │  ML Models      │  │  React Static Files     │   │  │
│  │  │  Backend        │  │  MediaPipe      │  │                         │   │  │
│  │  │                 │  │  dlib + OpenCV  │  │                         │   │  │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                            │
│                                     ▼                                            │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                         CORTEX SERVICES                                    │  │
│  │                                                                            │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │ Cortex Agent │  │ Vector Search│  │ Cortex Search│  │ Cortex       │  │  │
│  │  │ Orchestrator │  │ (Embeddings) │  │ (Semantic)   │  │ Analyst      │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │  │
│  │                                                                            │  │
│  │  ┌──────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                         AI_EXTRACT (Label Processing)                 │ │  │
│  │  └──────────────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                            │
│                                     ▼                                            │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                           DATA LAYER (Schemas)                             │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │  │
│  │  │CUSTOMERS │ │PRODUCTS  │ │INVENTORY │ │ SOCIAL   │ │CHECKOUT  │        │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘        │  │
│  │  ┌──────────────────────────────────────┐  ┌──────────────────────────┐  │  │
│  │  │ UTIL (SPCS, shared UDFs)             │  │ DEMO_CONFIG (settings)   │  │  │
│  │  └──────────────────────────────────────┘  └──────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Tool Hosting Strategy

```
                              ┌─────────────────────┐
                              │    CORTEX AGENT     │
                              │    (Orchestrator)   │
                              └─────────┬───────────┘
                                        │
          ┌─────────────────────────────┼─────────────────────────────┐
          │                             │                             │
          ▼                             ▼                             ▼
┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐
│   SPCS CONTAINER    │   │  CORTEX VECTOR      │   │   CORTEX SEARCH     │
│                     │   │  SEARCH             │   │                     │
│ • analyze_face      │   │                     │   │ • search_products   │
│ • detect_makeup     │   │ • identify_customer │   │ • search_labels     │
│ • match_products    │   │   (ANN lookup)      │   │ • search_social     │
└─────────────────────┘   └─────────────────────┘   └─────────────────────┘
          │                             │                             │
          └─────────────────────────────┼─────────────────────────────┘
                                        │
          ┌─────────────────────────────┼─────────────────────────────┐
          │                             │                             │
          ▼                             ▼                             ▼
┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐
│   CORTEX ANALYST    │   │   SQL/PYTHON UDFs   │   │    AI_EXTRACT       │
│                     │   │                     │   │                     │
│ • query_products    │   │ • calculate_ciede   │   │ • Label processing  │
│ • query_inventory   │   │ • checkout_tools    │   │ • Ingredient extract│
│ • query_customer    │   │ • redeem_points     │   │                     │
│ • query_social      │   │                     │   │                     │
└─────────────────────┘   └─────────────────────┘   └─────────────────────┘
```

### Request Flow

```
┌──────┐      ┌──────────┐      ┌─────────┐      ┌───────────┐      ┌──────────┐
│ User │      │  Widget  │      │ FastAPI │      │  Cortex   │      │ Snowflake│
│      │      │          │      │         │      │  Agent    │      │  Tables  │
└──┬───┘      └────┬─────┘      └────┬────┘      └─────┬─────┘      └────┬─────┘
   │               │                 │                 │                 │
   │ Upload Image  │                 │                 │                 │
   │──────────────>│                 │                 │                 │
   │               │                 │                 │                 │
   │               │ POST /api/chat  │                 │                 │
   │               │────────────────>│                 │                 │
   │               │                 │                 │                 │
   │               │                 │ Process Request │                 │
   │               │                 │────────────────>│                 │
   │               │                 │                 │                 │
   │               │                 │                 │ analyze_face()  │
   │               │                 │                 │──────┐          │
   │               │                 │                 │      │ ML       │
   │               │                 │                 │<─────┘          │
   │               │                 │                 │                 │
   │               │                 │                 │ identify_customer
   │               │                 │                 │────────────────>│
   │               │                 │                 │   ANN Search    │
   │               │                 │                 │<────────────────│
   │               │                 │                 │                 │
   │               │                 │                 │ search_products │
   │               │                 │                 │────────────────>│
   │               │                 │                 │  Semantic Match │
   │               │                 │                 │<────────────────│
   │               │                 │                 │                 │
   │               │                 │  JSON Response  │                 │
   │               │                 │<────────────────│                 │
   │               │                 │                 │                 │
   │               │  Display Results│                 │                 │
   │               │<────────────────│                 │                 │
   │               │                 │                 │                 │
   │  View Results │                 │                 │                 │
   │<──────────────│                 │                 │                 │
   │               │                 │                 │                 │
```

---

## Cortex Agent Design

### Agent Configuration

```yaml
name: beauty_advisor
model: claude-3-5-sonnet
description: |
  AI Beauty Advisor that helps customers find perfect cosmetic matches
  based on skin tone analysis and personal preferences.

system_prompt: |
  You are a friendly and knowledgeable Beauty Advisor for {retailer_name}.
  
  Your capabilities:
  - Analyze face images for skin tone, lip color, and undertone
  - Identify returning customers via face recognition
  - Recommend products using scientific color matching (CIEDE2000)
  - Answer questions about products, ingredients, and reviews
  - Help with checkout and loyalty points
  
  Guidelines:
  - Always confirm customer identity before accessing personal data
  - Explain color science in simple terms
  - Provide honest product recommendations
  - Respect privacy - never store images without consent

tools:
  - analyze_face
  - identify_customer
  - match_products
  - query_products
  - search_products
  - search_product_labels
  - query_inventory
  - query_customer
  - query_social_proof
  - search_social_proof
  - create_checkout_session
  - add_to_checkout
  - submit_checkout
  # ... (see full tool catalog)
```

### Conversation Flow

```
                                    ┌─────────────┐
                                    │   START     │
                                    └──────┬──────┘
                                           │
                                           ▼
                                    ┌─────────────┐
                                    │   WELCOME   │
                                    └──────┬──────┘
                                           │
              ┌────────────────────────────┼────────────────────────────┐
              │                            │                            │
              ▼                            ▼                            ▼
       ┌─────────────┐              ┌─────────────┐              ┌─────────────┐
       │Take Selfie  │              │Upload Photo │              │ Text Chat   │
       └──────┬──────┘              └──────┬──────┘              └──────┬──────┘
              │                            │                            │
              └────────────┬───────────────┘                            │
                           │                                            │
                           ▼                                            ▼
                    ┌─────────────┐                              ┌─────────────┐
                    │Face Analysis│                              │Agent Response
                    └──────┬──────┘                              └──────┬──────┘
                           │                                            │
                           ▼                                            │
                    ┌─────────────┐                                     │
                    │Identity     │                                     │
                    │Check        │                                     │
                    └──────┬──────┘                                     │
                           │                                            │
              ┌────────────┴────────────┐                               │
              │ Match?                  │                               │
              ▼                         ▼                               │
       ┌─────────────┐           ┌─────────────┐                        │
       │"Is this you │           │New Customer │                        │
       │ Sarah?"     │           │Flow         │                        │
       └──────┬──────┘           └──────┬──────┘                        │
              │                         │                               │
       ┌──────┴──────┐                  │                               │
       │Yes    │No   │                  │                               │
       ▼       ▼     │                  │                               │
    ┌─────┐ ┌─────┐  │                  │                               │
    │Login│ │New  │──┴──────────────────┤                               │
    └──┬──┘ └─────┘                     │                               │
       │                                │                               │
       └────────────────┬───────────────┘                               │
                        │                                               │
                        ▼                                               │
                 ┌─────────────┐                                        │
                 │Show Analysis│◄───────────────────────────────────────┘
                 │Results      │
                 └──────┬──────┘
                        │
                        ▼
                 ┌─────────────┐
                 │Category     │◄────────────────┐
                 │Select       │                 │
                 └──────┬──────┘                 │
                        │                        │
                        ▼                        │
                 ┌─────────────┐                 │
                 │Product      │                 │
                 │Matching     │                 │
                 └──────┬──────┘                 │
                        │                        │
                        ▼                        │
                 ┌─────────────┐                 │
                 │Show Products│─────────────────┘
                 └──────┬──────┘    (Try another)
                        │
                        ▼
                 ┌─────────────┐
                 │Add to Cart  │
                 └──────┬──────┘
                        │
                        ▼
                 ┌─────────────┐
                 │  CHECKOUT   │
                 └──────┬──────┘
                        │
                        ▼
                 ┌─────────────┐
                 │    END      │
                 └─────────────┘
```

---

## Tool Catalog

### Beauty Analysis Tools (SPCS)

| Tool | Description | Parameters | Returns |
|------|-------------|------------|---------|
| `analyze_face` | Full face analysis | `image: base64` | skin_tone, lip_color, embedding, undertone, fitzpatrick, monk |
| `detect_makeup` | Check for makeup | `image: base64` | is_wearing_makeup, detected_products, estimated_natural_colors |
| `match_products` | CIEDE2000 matching | `skin_lab, category, limit` | products with delta_e scores |

### Customer Tools

| Tool | Type | Description |
|------|------|-------------|
| `identify_customer` | Cortex Vector Search | Match face embedding to known customers |
| `query_customer` | Cortex Analyst | Profile, history, loyalty points, preferences |
| `update_customer_profile` | SQL UDF | Update skin profile, preferences |
| `redeem_points` | SQL UDF | Apply loyalty points to checkout |

### Product Tools

| Tool | Type | Description |
|------|------|-------------|
| `query_products` | Cortex Analyst | Structured queries: pricing, variants, promotions |
| `search_products` | Cortex Search | Semantic product discovery |
| `analyze_product_image` | CORTEX.COMPLETE | Answer questions about product images |
| `search_product_labels` | Cortex Search | Find by ingredients, warnings, claims |
| `query_inventory` | Cortex Analyst | Stock levels, availability by location |

### Social Proof Tools

| Tool | Type | Description |
|------|------|-------------|
| `query_social_proof` | Cortex Analyst | Ratings, review counts, trends, influencer stats |
| `search_social_proof` | Cortex Search | Semantic search across reviews/mentions |

### Agentic Checkout Tools (OpenAI Spec)

| Tool | Description |
|------|-------------|
| `create_checkout_session` | Create session from current selections |
| `get_checkout_session` | Get session state with items and pricing |
| `add_to_checkout` | Add product to session |
| `update_checkout_item` | Update item quantity |
| `remove_from_checkout` | Remove item from session |
| `get_fulfillment_options` | Get shipping/pickup options |
| `set_fulfillment` | Set address and shipping method |
| `get_payment_methods` | Get customer's saved payment methods |
| `submit_checkout` | Finalize and process payment |

---

## Data Layer

### Schema Organization

| Schema | Purpose | Cortex Services |
|--------|---------|-----------------|
| **CUSTOMERS** | Profiles, embeddings, analysis history | Vector Search (face embeddings), Analyst |
| **PRODUCTS** | Catalog, variants, media, labels | Search (products, labels), Analyst |
| **INVENTORY** | Locations, stock levels, transactions | Analyst |
| **SOCIAL** | Reviews, mentions, influencers, trends | Search (social content), Analyst |
| **CHECKOUT** | Sessions, payments, orders | Analyst |
| **UTIL** | SPCS services, shared UDFs, integrations | — |
| **DEMO_CONFIG** | Retailer settings, themes, branding | — |

> **Design Principle:** Each domain schema contains its own Cortex Search services, Cortex Analyst semantic views, and domain-specific UDFs. This keeps related objects together and simplifies access control.

### Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              ENTITY RELATIONSHIPS                                │
└─────────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │   CUSTOMERS     │
    │─────────────────│
    │ customer_id (PK)│
    │ email           │
    │ first_name      │
    │ loyalty_tier    │
    │ points_balance  │
    │ skin_profile    │
    └────────┬────────┘
             │
    ┌────────┼────────┬────────────────┬─────────────────┐
    │        │        │                │                 │
    ▼        ▼        ▼                ▼                 ▼
┌────────┐┌────────┐┌────────┐   ┌──────────┐    ┌───────────┐
│FACE    ││ANALYSIS││CHECKOUT│   │ PAYMENT  │    │ PRODUCT   │
│EMBED-  ││HISTORY ││SESSIONS│   │ METHODS  │    │ REVIEWS   │
│DINGS   ││        ││        │   │          │    │(optional) │
└────────┘└────────┘└───┬────┘   └──────────┘    └───────────┘
                        │
           ┌────────────┼────────────┐
           │            │            │
           ▼            ▼            ▼
      ┌─────────┐ ┌──────────┐ ┌──────────┐
      │ LINE    │ │ PAYMENT  │ │FULFILLMENT
      │ ITEMS   │ │ TRANS-   │ │ OPTIONS  │
      │         │ │ ACTIONS  │ │          │
      └────┬────┘ └──────────┘ └──────────┘
           │
           ▼
    ┌─────────────────┐
    │    PRODUCTS     │
    │─────────────────│
    │ product_id (PK) │
    │ name, brand     │
    │ category        │
    │ color_hex/lab   │
    │ price           │
    └────────┬────────┘
             │
    ┌────────┼────────┬──────────┬──────────┬──────────┬──────────┐
    │        │        │          │          │          │          │
    ▼        ▼        ▼          ▼          ▼          ▼          ▼
┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐
│VARIANTS││ MEDIA  ││ LABELS ││REVIEWS ││SOCIAL  ││INFLUEN-││TRENDING│
│        ││        ││        ││        ││MENTIONS││CER     ││PRODUCTS│
└────────┘└────────┘└───┬────┘└────────┘└────────┘└────────┘└────────┘
                        │
              ┌─────────┴─────────┐
              │                   │
              ▼                   ▼
         ┌─────────┐         ┌─────────┐
         │INGREDI- │         │WARNINGS │
         │ENTS     │         │         │
         └─────────┘         └─────────┘

    ┌─────────────────────────────────────────────────────────────────────────┐
    │                    INVENTORY SCHEMA                                      │
    │                                                                          │
    │  ┌─────────────────┐           ┌─────────────────┐                      │
    │  │  STOCK_LEVELS   │──────────▶│    LOCATIONS    │                      │
    │  │─────────────────│           │─────────────────│                      │
    │  │ product_id (FK) │           │ location_id (PK)│                      │
    │  │ variant_id (FK) │           │ name, type      │                      │
    │  │ quantity        │           │ address         │                      │
    │  └────────┬────────┘           └─────────────────┘                      │
    │           │                                                              │
    │           ▼                                                              │
    │  ┌─────────────────┐                                                    │
    │  │  INVENTORY      │                                                    │
    │  │  TRANSACTIONS   │  (audit trail)                                     │
    │  └─────────────────┘                                                    │
    └─────────────────────────────────────────────────────────────────────────┘
```

### Customer & Identity Tables

```sql
-- Core customer profile
CREATE TABLE CUSTOMERS (
    customer_id VARCHAR PRIMARY KEY,
    email VARCHAR UNIQUE,
    first_name VARCHAR,
    last_name VARCHAR,
    loyalty_tier VARCHAR,          -- 'Bronze', 'Silver', 'Gold', 'Platinum'
    points_balance INTEGER DEFAULT 0,
    skin_profile OBJECT,           -- {skin_tone, undertone, fitzpatrick, monk}
    preferences OBJECT,            -- {favorite_brands, allergies, etc.}
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP
);

-- Face embeddings for recognition
CREATE TABLE CUSTOMER_FACE_EMBEDDINGS (
    embedding_id VARCHAR PRIMARY KEY,
    customer_id VARCHAR REFERENCES CUSTOMERS(customer_id),
    embedding VECTOR(FLOAT, 128),  -- dlib 128-dim embedding
    quality_score FLOAT,
    lighting_condition VARCHAR,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Analysis history
CREATE TABLE SKIN_ANALYSIS_HISTORY (
    analysis_id VARCHAR PRIMARY KEY,
    customer_id VARCHAR REFERENCES CUSTOMERS(customer_id),
    image_stage_path VARCHAR,
    skin_hex VARCHAR,
    skin_lab ARRAY,
    lip_hex VARCHAR,
    lip_lab ARRAY,
    fitzpatrick_type INTEGER,
    monk_shade INTEGER,
    undertone VARCHAR,
    makeup_detected BOOLEAN,
    confidence_score FLOAT,
    analyzed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
```

### Product Tables

```sql
-- Core products
CREATE TABLE PRODUCTS (
    product_id VARCHAR PRIMARY KEY,
    name VARCHAR,
    brand VARCHAR,
    category VARCHAR,              -- 'foundation', 'lipstick', 'blush', etc.
    subcategory VARCHAR,
    description TEXT,
    base_price DECIMAL(10,2),
    current_price DECIMAL(10,2),
    color_hex VARCHAR,
    color_lab ARRAY,               -- [L, a, b] values
    finish VARCHAR,                -- 'matte', 'satin', 'glossy', 'shimmer'
    skin_tone_compatibility ARRAY, -- ['fair', 'light', 'medium', 'tan', 'deep']
    undertone_compatibility ARRAY, -- ['warm', 'cool', 'neutral']
    is_active BOOLEAN DEFAULT TRUE,
    launch_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Product variants (shades/sizes)
CREATE TABLE PRODUCT_VARIANTS (
    variant_id VARCHAR PRIMARY KEY,
    product_id VARCHAR REFERENCES PRODUCTS(product_id),
    sku VARCHAR UNIQUE,
    shade_name VARCHAR,
    color_hex VARCHAR,
    color_lab ARRAY,
    size VARCHAR,
    price_modifier DECIMAL(10,2) DEFAULT 0,
    is_available BOOLEAN DEFAULT TRUE
);

-- Product media (images/videos)
CREATE TABLE PRODUCT_MEDIA (
    media_id VARCHAR PRIMARY KEY,
    product_id VARCHAR REFERENCES PRODUCTS(product_id),
    url VARCHAR,
    media_type VARCHAR,            -- 'image', 'video'
    media_subtype VARCHAR,         -- 'hero', 'swatch', 'label', 'ingredients', 'lifestyle'
    alt_text VARCHAR,
    display_order INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Extracted label data (from AI_EXTRACT)
CREATE TABLE PRODUCT_LABELS (
    label_id VARCHAR PRIMARY KEY,
    product_id VARCHAR REFERENCES PRODUCTS(product_id),
    label_type VARCHAR,            -- 'ingredients', 'warnings', 'claims'
    extracted_text TEXT,
    structured_data VARIANT,       -- Full JSON from AI_EXTRACT
    source_image_url VARCHAR,      -- Traceability
    source_media_id VARCHAR REFERENCES PRODUCT_MEDIA(media_id),
    extraction_model VARCHAR,
    extraction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Individual ingredients (flattened for search)
CREATE TABLE PRODUCT_INGREDIENTS (
    ingredient_id VARCHAR PRIMARY KEY,
    product_id VARCHAR REFERENCES PRODUCTS(product_id),
    label_id VARCHAR REFERENCES PRODUCT_LABELS(label_id),
    ingredient_name VARCHAR,
    position INTEGER,              -- Order of concentration
    source_image_url VARCHAR
);

-- Warnings (flattened for search)
CREATE TABLE PRODUCT_WARNINGS (
    warning_id VARCHAR PRIMARY KEY,
    product_id VARCHAR REFERENCES PRODUCTS(product_id),
    label_id VARCHAR REFERENCES PRODUCT_LABELS(label_id),
    warning_text VARCHAR,
    source_image_url VARCHAR
);

-- Price history
CREATE TABLE PRICE_HISTORY (
    history_id VARCHAR PRIMARY KEY,
    product_id VARCHAR REFERENCES PRODUCTS(product_id),
    price DECIMAL(10,2),
    effective_date DATE,
    end_date DATE,
    change_reason VARCHAR
);

-- Promotions
CREATE TABLE PROMOTIONS (
    promotion_id VARCHAR PRIMARY KEY,
    name VARCHAR,
    type VARCHAR,                  -- 'percentage', 'fixed', 'bogo'
    discount_value DECIMAL(10,2),
    product_ids ARRAY,
    category_ids ARRAY,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);
```

### Inventory Tables

```sql
CREATE TABLE LOCATIONS (
    location_id VARCHAR PRIMARY KEY,
    name VARCHAR,
    type VARCHAR,                  -- 'warehouse', 'store'
    address OBJECT,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE STOCK_LEVELS (
    stock_id VARCHAR PRIMARY KEY,
    product_id VARCHAR,              -- References PRODUCTS.PRODUCTS
    variant_id VARCHAR,              -- References PRODUCTS.PRODUCT_VARIANTS
    location_id VARCHAR REFERENCES LOCATIONS(location_id),
    quantity_on_hand INTEGER,
    quantity_reserved INTEGER,
    quantity_available INTEGER AS (quantity_on_hand - quantity_reserved),
    reorder_point INTEGER,
    reorder_quantity INTEGER,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE INVENTORY_TRANSACTIONS (
    transaction_id VARCHAR PRIMARY KEY,
    stock_id VARCHAR REFERENCES STOCK_LEVELS(stock_id),
    transaction_type VARCHAR,        -- received, sold, reserved, released, adjusted
    quantity INTEGER,
    reference_type VARCHAR,          -- order, purchase_order, adjustment
    reference_id VARCHAR,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
```

### Social Proof Tables

```sql
-- Customer reviews (retailer's platform)
CREATE TABLE PRODUCT_REVIEWS (
    review_id VARCHAR PRIMARY KEY,
    product_id VARCHAR REFERENCES PRODUCTS(product_id),
    customer_id VARCHAR,           -- Nullable for anonymous
    platform VARCHAR,              -- 'website', 'app', 'bazaarvoice'
    rating INTEGER,                -- 1-5
    title VARCHAR,
    review_text TEXT,
    review_url VARCHAR,            -- Direct link to review
    helpful_votes INTEGER DEFAULT 0,
    verified_purchase BOOLEAN DEFAULT FALSE,
    -- Reviewer demographics (from profile)
    reviewer_skin_tone VARCHAR,
    reviewer_skin_type VARCHAR,
    reviewer_undertone VARCHAR,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Social media mentions
CREATE TABLE SOCIAL_MENTIONS (
    mention_id VARCHAR PRIMARY KEY,
    product_id VARCHAR REFERENCES PRODUCTS(product_id),
    platform VARCHAR,              -- 'instagram', 'tiktok', 'youtube', 'twitter'
    post_url VARCHAR,
    content_text TEXT,
    media_url VARCHAR,             -- Image/video thumbnail
    author_handle VARCHAR,
    likes INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    sentiment_score FLOAT,         -- -1 to 1
    posted_at TIMESTAMP,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Influencer mentions
CREATE TABLE INFLUENCER_MENTIONS (
    mention_id VARCHAR PRIMARY KEY,
    product_id VARCHAR REFERENCES PRODUCTS(product_id),
    influencer_id VARCHAR,
    influencer_handle VARCHAR,
    influencer_name VARCHAR,
    platform VARCHAR,
    post_url VARCHAR,
    content_text TEXT,
    media_url VARCHAR,
    likes INTEGER,
    comments INTEGER,
    shares INTEGER,
    -- Influencer attributes (from Viral Nation/CreatorIQ or manual curation)
    influencer_skin_tone VARCHAR,  -- 'Fair', 'Light', 'Medium', 'Tan', 'Deep'
    influencer_skin_type VARCHAR,  -- 'Oily', 'Dry', 'Combination', 'Normal'
    influencer_undertone VARCHAR,  -- 'Warm', 'Cool', 'Neutral'
    follower_count INTEGER,
    engagement_rate FLOAT,
    audience_demographics OBJECT,  -- {age_ranges, gender_split, top_locations}
    posted_at TIMESTAMP,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Trending products (calculated)
CREATE TABLE TRENDING_PRODUCTS (
    trend_id VARCHAR PRIMARY KEY,
    product_id VARCHAR REFERENCES PRODUCTS(product_id),
    trend_rank INTEGER,
    trend_score FLOAT,
    mention_velocity FLOAT,        -- Mentions per hour
    is_viral BOOLEAN DEFAULT FALSE,
    trending_platforms ARRAY,      -- Where it's trending
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
```

### Agentic Checkout Tables (OpenAI Spec)

```sql
-- Checkout sessions
CREATE TABLE CHECKOUT_SESSIONS (
    session_id VARCHAR PRIMARY KEY,
    customer_id VARCHAR REFERENCES CUSTOMERS(customer_id),
    status VARCHAR,                -- 'active', 'pending_payment', 'completed', 'expired', 'cancelled'
    
    -- Pricing (amounts in cents for precision)
    subtotal_cents INTEGER,
    tax_cents INTEGER,
    shipping_cents INTEGER,
    discount_cents INTEGER,
    total_cents INTEGER,
    currency VARCHAR DEFAULT 'USD',
    
    -- Fulfillment
    fulfillment_type VARCHAR,      -- 'shipping', 'pickup'
    shipping_address OBJECT,
    shipping_method_id VARCHAR,
    
    -- Gift options (session level)
    is_gift BOOLEAN DEFAULT FALSE,
    gift_message VARCHAR,
    
    -- Validation (simple for OpenAI spec)
    is_valid BOOLEAN DEFAULT TRUE,
    validation_message VARCHAR,
    
    -- Idempotency
    idempotency_key VARCHAR UNIQUE,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP,
    expires_at TIMESTAMP
);

-- Line items
CREATE TABLE LINE_ITEMS (
    line_item_id VARCHAR PRIMARY KEY,
    session_id VARCHAR REFERENCES CHECKOUT_SESSIONS(session_id),
    product_id VARCHAR REFERENCES PRODUCTS(product_id),
    variant_id VARCHAR,
    quantity INTEGER,
    unit_price_cents INTEGER,
    subtotal_cents INTEGER,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Fulfillment options
CREATE TABLE FULFILLMENT_OPTIONS (
    option_id VARCHAR PRIMARY KEY,
    name VARCHAR,                  -- 'Standard Shipping', 'Express', 'Store Pickup'
    type VARCHAR,                  -- 'shipping', 'pickup'
    price_cents INTEGER,
    estimated_days INTEGER,
    is_available BOOLEAN DEFAULT TRUE
);

-- Saved payment methods
CREATE TABLE PAYMENT_METHODS (
    payment_method_id VARCHAR PRIMARY KEY,
    customer_id VARCHAR REFERENCES CUSTOMERS(customer_id),
    type VARCHAR,                  -- 'card', 'paypal', 'apple_pay'
    token VARCHAR,                 -- PSP token (never store raw card data)
    display_name VARCHAR,          -- 'Visa ****4242'
    is_default BOOLEAN DEFAULT FALSE,
    expires_at DATE
);

-- Payment transactions
CREATE TABLE PAYMENT_TRANSACTIONS (
    transaction_id VARCHAR PRIMARY KEY,
    session_id VARCHAR REFERENCES CHECKOUT_SESSIONS(session_id),
    payment_method_id VARCHAR,
    amount_cents INTEGER,
    currency VARCHAR,
    status VARCHAR,                -- 'pending', 'authorized', 'captured', 'failed', 'refunded'
    psp_reference VARCHAR,         -- External PSP transaction ID
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
```

### Cortex Search Services

> **Note:** Each Cortex Search service is created in its respective domain schema.

```sql
-- ============================================================================
-- PRODUCTS SCHEMA: Product and label search
-- ============================================================================
USE SCHEMA PRODUCTS;

-- Product search service
CREATE CORTEX SEARCH SERVICE product_search
  ON products
  WAREHOUSE = agent_commerce_wh
  TARGET_LAG = '1 hour'
  AS (
    SELECT 
      product_id,
      name,
      brand,
      category,
      description,
      color_hex,
      current_price
    FROM products
    WHERE is_active = TRUE
  );

-- Label search service (with source traceability)
CREATE CORTEX SEARCH SERVICE label_search
  ON product_labels
  WAREHOUSE = agent_commerce_wh
  TARGET_LAG = '1 hour'
  AS (
    SELECT
      label_id,
      product_id,
      label_type,
      extracted_text,
      source_image_url
    FROM product_labels
  );

-- ============================================================================
-- SOCIAL SCHEMA: Social proof search
-- ============================================================================
USE SCHEMA SOCIAL;

-- Social proof search service
CREATE CORTEX SEARCH SERVICE social_proof_search
  WAREHOUSE = compute_wh
  TARGET_LAG = '1 hour'
  AS (
    SELECT 
      'review' AS source_type,
      review_id AS source_id,
      product_id,
      review_text AS content,
      review_url AS source_url,
      rating,
      reviewer_skin_tone,
      created_at
    FROM product_reviews
    
    UNION ALL
    
    SELECT
      'social' AS source_type,
      mention_id AS source_id,
      product_id,
      content_text AS content,
      post_url AS source_url,
      NULL AS rating,
      NULL AS reviewer_skin_tone,
      posted_at AS created_at
    FROM social_mentions
    
    UNION ALL
    
    SELECT
      'influencer' AS source_type,
      mention_id AS source_id,
      product_id,
      content_text AS content,
      post_url AS source_url,
      NULL AS rating,
      influencer_skin_tone AS reviewer_skin_tone,
      posted_at AS created_at
    FROM influencer_mentions
  );
```

### Cortex Vector Search Index

```sql
-- ============================================================================
-- CUSTOMERS SCHEMA: Face embedding vector search
-- ============================================================================
USE SCHEMA CUSTOMERS;

-- Face embedding index for customer identification
CREATE CORTEX VECTOR INDEX face_embedding_index
  ON customer_face_embeddings(embedding)
  USING L2_DISTANCE
  WITH (
    TARGET_RECALL = 0.95,
    EF_CONSTRUCTION = 200
  );
```

---

## Chatbot Widget Design

### Widget States

```
                              ┌─────────────┐
                              │  Page Load  │
                              └──────┬──────┘
                                     │
                                     ▼
                              ┌─────────────┐
                   ┌─────────▶│  COLLAPSED  │◀─────────┐
                   │          │  (Button)   │          │
                   │          └──────┬──────┘          │
                   │                 │ Click           │
                   │                 ▼                 │
                   │          ┌─────────────┐          │
                   │          │  EXPANDED   │──────────┘
                   │          │  (Chat UI)  │  Click ✕
                   │          └──────┬──────┘
                   │                 │
                   │    ┌────────────┼────────────┐
                   │    │            │            │
                   │    ▼            ▼            ▼
                   │ ┌────────┐ ┌────────┐ ┌────────┐
                   │ │Camera  │ │Upload  │ │Text    │
                   │ │Capture │ │Photo   │ │Chat    │
                   │ └───┬────┘ └───┬────┘ └───┬────┘
                   │     │          │          │
                   │     └────┬─────┘          │
                   │          │                │
                   │          ▼                ▼
                   │   ┌─────────────┐  ┌─────────────┐
                   │   │ PROCESSING  │  │   AGENT     │
                   │   └──────┬──────┘  │  RESPONSE   │
                   │          │         └─────────────┘
                   │   ┌──────┴──────┐
                   │   │             │
                   │   ▼             ▼
                   │ ┌────────┐ ┌────────────┐
                   │ │Identity│ │ Analysis   │
                   │ │Confirm │ │ Results    │
                   │ └───┬────┘ └─────┬──────┘
                   │     │            │
                   │     └─────┬──────┘
                   │           │
                   │           ▼
                   │    ┌─────────────┐
                   │    │  CATEGORY   │◀──────────┐
                   │    │  SELECT     │           │
                   │    └──────┬──────┘           │
                   │           │                  │
                   │           ▼                  │
                   │    ┌─────────────┐           │
                   │    │  PRODUCT    │───────────┘
                   │    │  MATCHES    │  Try Another
                   │    └──────┬──────┘
                   │           │
                   │           ▼
                   │    ┌─────────────┐
                   │    │  CHECKOUT   │
                   │    └──────┬──────┘
                   │           │
                   └───────────┘ (New Photo)
```

### Widget Layout

```
┌─────────────────────────────────────────┐
│  HEADER                                 │
│  ┌────────────────────────────────────┐ │
│  │ [LOGO]  Beauty Advisor          ✕  │ │
│  │         by [RETAILER NAME]         │ │
│  └────────────────────────────────────┘ │
│                                         │
│  CHAT AREA                              │
│  ┌────────────────────────────────────┐ │
│  │                                    │ │
│  │  💬 Message bubbles appear here    │ │
│  │                                    │ │
│  │  ┌──────────────────────────────┐  │ │
│  │  │  Bot: Hi! I'm your Beauty    │  │ │
│  │  │  Advisor. Ready to find your │  │ │
│  │  │  perfect shade?              │  │ │
│  │  └──────────────────────────────┘  │ │
│  │                                    │ │
│  └────────────────────────────────────┘ │
│                                         │
│  ACTIONS                                │
│  ┌────────────────────────────────────┐ │
│  │  📸 Take a Selfie                  │ │
│  └────────────────────────────────────┘ │
│  ┌────────────────────────────────────┐ │
│  │  📁 Upload a Photo                 │ │
│  └────────────────────────────────────┘ │
│                                         │
│  INPUT                                  │
│  ┌────────────────────────────────────┐ │
│  │  Type a message...            📎 ➤ │ │
│  └────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### Analysis Results Display

```
┌─────────────────────────────────────────┐
│                                         │
│  ✨ Your Beauty Profile                 │
│                                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ SKIN     │ │ LIP      │ │ UNDER-   │ │
│  │ TONE     │ │ COLOR    │ │ TONE     │ │
│  │          │ │          │ │          │ │
│  │   ████   │ │   ████   │ │    🌞    │ │
│  │ #C68642  │ │ #B56B72  │ │   WARM   │ │
│  │          │ │          │ │          │ │
│  │ Monk: 5  │ │ Natural  │ │          │ │
│  │ Fitz: IV │ │          │ │          │ │
│  └──────────┘ └──────────┘ └──────────┘ │
│                                         │
│  ⚠️ Lipstick detected                   │
│  (showing estimated natural color)      │
│                                         │
└─────────────────────────────────────────┘
```

---

## Customization System

### Configuration Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                 CONFIG SOURCES (Priority Order)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐                                           │
│  │ 1. Environment   │ ──────┐                                   │
│  │    Variables     │       │                                   │
│  └──────────────────┘       │                                   │
│                             │                                   │
│  ┌──────────────────┐       │    ┌──────────────────┐          │
│  │ 2. Admin UI      │ ──────┼───▶│  CONFIG MERGER   │          │
│  │    Changes       │       │    │                  │          │
│  └──────────────────┘       │    └────────┬─────────┘          │
│                             │             │                     │
│  ┌──────────────────┐       │             │                     │
│  │ 3. retailer.json │ ──────┤             ▼                     │
│  │    File          │       │    ┌──────────────────┐          │
│  └──────────────────┘       │    │ FINAL CONFIG     │          │
│                             │    └────────┬─────────┘          │
│  ┌──────────────────┐       │             │                     │
│  │ 4. Default       │ ──────┘             │                     │
│  │    Values        │                     │                     │
│  └──────────────────┘            ┌────────┼────────┐           │
│                                  │        │        │           │
│                                  ▼        ▼        ▼           │
│                           ┌───────┐ ┌───────┐ ┌───────┐        │
│                           │Widget │ │Theme  │ │Message│        │
│                           │Render │ │CSS    │ │Templa-│        │
│                           │       │ │Vars   │ │tes    │        │
│                           └───────┘ └───────┘ └───────┘        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Configuration Schema

```json
{
  "retailer_name": "Sephora",
  "tagline": "Beauty Advisor",
  "logo_url": null,
  
  "theme": {
    "primary_color": "#000000",
    "secondary_color": "#E60023",
    "background_color": "#FFFFFF",
    "text_color": "#333333",
    "accent_color": "#C9A050",
    "border_radius": "12px",
    "font_family": "Helvetica Neue, Arial"
  },
  
  "widget": {
    "position": "bottom-right",
    "button_text": "Find My Shade",
    "button_icon": "💄",
    "width": "380px",
    "height": "600px"
  },
  
  "messages": {
    "welcome": "Hi! I'm your personal Beauty Advisor.",
    "identity_prompt": "Is this you, {name}?",
    "analysis_complete": "✨ Your Beauty Profile"
  },
  
  "categories": {
    "foundation": { "enabled": true, "label": "Foundation" },
    "lipstick": { "enabled": true, "label": "Lipstick" },
    "blush": { "enabled": true, "label": "Blush" }
  }
}
```

### Pre-built Themes

| Theme | Primary | Secondary | Background | Accent |
|-------|---------|-----------|------------|--------|
| **Sephora** | #000000 | #E60023 | #FFFFFF | #C9A050 |
| **Ulta** | #FF6900 | #FF1493 | #FFF5EE | #FFD700 |
| **MAC** | #000000 | #000000 | #FFFFFF | #808080 |
| **Glossier** | #FFB6C1 | #FF69B4 | #FFF0F5 | #FF1493 |

---

## Module Structure

### Project Directory

```
beauty_analyzer/
│
├── backend/
│   ├── src/
│   │   ├── __init__.py
│   │   ├── app.py                    # FastAPI application
│   │   │
│   │   ├── # ─────────── COLOR SCIENCE ───────────
│   │   ├── color_utils.py            # LAB, CIEDE2000, ITA, undertone
│   │   │
│   │   ├── # ─────────── FACE PROCESSING ─────────
│   │   ├── face_detector.py          # MediaPipe face detection
│   │   ├── face_recognizer.py        # dlib embeddings
│   │   ├── makeup_detector.py        # Makeup detection
│   │   │
│   │   ├── # ─────────── ANALYSIS ────────────────
│   │   ├── skin_analyzer.py          # Skin tone analysis
│   │   ├── lip_analyzer.py           # Lip color analysis
│   │   ├── face_analyzer.py          # Main orchestrator
│   │   │
│   │   ├── # ─────────── MATCHING ────────────────
│   │   ├── product_matcher.py        # CIEDE2000 matching
│   │   │
│   │   ├── # ─────────── SERVICES ────────────────
│   │   ├── customer_service.py       # Customer CRUD
│   │   ├── checkout_service.py       # Checkout operations
│   │   ├── config_service.py         # Config loading
│   │   ├── database.py               # Snowflake connection
│   │   │
│   │   └── # ─────────── MODELS ──────────────────
│   │       └── schemas.py            # Pydantic models
│   │
│   ├── Dockerfile
│   └── requirements.txt
│
├── frontend/
│   ├── src/
│   │   ├── App.tsx
│   │   ├── main.tsx
│   │   ├── embed.tsx                 # Widget entry point
│   │   │
│   │   ├── components/
│   │   │   ├── ChatWidget.tsx
│   │   │   ├── WidgetButton.tsx
│   │   │   ├── CameraCapture.tsx
│   │   │   ├── AnalysisResults.tsx
│   │   │   ├── ProductMatches.tsx
│   │   │   └── ...
│   │   │
│   │   ├── admin/
│   │   │   ├── AdminPanel.tsx
│   │   │   ├── ColorPicker.tsx
│   │   │   └── ThemePresets.tsx
│   │   │
│   │   ├── hooks/
│   │   │   ├── useCamera.ts
│   │   │   ├── useAnalysis.ts
│   │   │   └── useConfig.ts
│   │   │
│   │   └── services/
│   │       └── api.ts
│   │
│   ├── package.json
│   └── vite.config.ts
│
├── config/
│   ├── retailer.json                 # ← EDIT: Name, colors
│   ├── logo.png                      # ← REPLACE: Your logo
│   └── themes/
│       ├── sephora.json
│       ├── ulta.json
│       └── glossier.json
│
├── sql/
│   ├── 01_setup_database.sql         # Database, schemas, warehouse, stages
│   ├── 02_create_tables.sql          # All domain tables
│   ├── 03_create_cortex_services.sql # Vector Search, Cortex Search (in domain schemas)
│   ├── 04_create_semantic_views.sql  # Cortex Analyst models (in domain schemas)
│   ├── 05_create_udfs.sql            # CIEDE2000, shared UDFs (in UTIL schema)
│   ├── 06_create_spcs_service.sql    # Compute pool, SPCS service
│   ├── 07_sample_data.sql            # Products, customers, reviews
│   └── 08_label_extraction_task.sql  # AI_EXTRACT scheduled task
│
├── semantic_views/                    # Cortex Analyst YAML definitions
│   ├── customers.yaml                 # → CUSTOMERS schema
│   ├── products.yaml                  # → PRODUCTS schema
│   ├── inventory.yaml                 # → INVENTORY schema
│   ├── social_proof.yaml              # → SOCIAL schema
│   └── checkout.yaml                  # → CHECKOUT schema
│
├── scripts/
│   ├── build.sh
│   ├── push.sh
│   ├── deploy.sh
│   └── local_dev.sh
│
├── demo/
│   ├── index.html                    # Mock retailer site
│   └── embed-snippet.html
│
├── Dockerfile                        # Multi-stage build
├── docker-compose.yml
└── README.md
```

### Key Module Details

#### Color Distance (CIEDE2000)

```
┌─────────────┐                                    ┌─────────────┐
│  COLOR 1    │                                    │   OUTPUT    │
│  (L,a,b)    │──┐                                 │             │
└─────────────┘  │    ┌────────────────────────┐   │    ΔE00     │
                 ├───▶│      CIEDE2000         │──▶│ Perceptual  │
┌─────────────┐  │    │                        │   │  Distance   │
│  COLOR 2    │──┘    │  ┌────┐ ┌────┐ ┌────┐ │   │             │
│  (L,a,b)    │       │  │ΔL' │ │ΔC' │ │ΔH' │ │   └─────────────┘
└─────────────┘       │  │Light│ │Chro│ │Hue │ │
                      │  └──┬─┘ └──┬─┘ └──┬─┘ │
                      │     │      │      │   │
                      │     └──────┼──────┘   │
                      │            │          │
                      │       ┌────┴────┐     │
                      │       │Rotation │     │
                      │       │  Term   │     │
                      │       └─────────┘     │
                      └────────────────────────┘
```

| ΔE00 Range | Quality | Description |
|------------|---------|-------------|
| < 1.0 | Imperceptible | Identical to human eye |
| 1.0 - 2.0 | Excellent | Near-perfect match |
| 2.0 - 3.5 | Great | Very good match |
| 3.5 - 5.0 | Good | Acceptable match |
| ≥ 5.0 | Fair | Noticeable difference |

#### Face Recognition Flow

```
┌─────────────────┐
│   Input Image   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Face Detection  │
│ (MediaPipe)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Face Crop       │
│ (Aligned)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Embedding Gen   │
│ (dlib ResNet)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 128-dim Vector  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Cortex Vector   │
│ Search (ANN)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Top 10          │
│ Candidates      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Exact Distance  │
│ Verification    │
└────────┬────────┘
         │
         ▼
    ┌────┴────┐
    │distance │
    │< 0.4 ?  │
    └────┬────┘
    Yes  │  No
    ┌────┴────┐
    │         │
    ▼         ▼
┌───────┐ ┌───────────┐
│ HIGH  │ │distance   │
│CONFID.│ │< 0.55 ?   │
│ Show  │ └─────┬─────┘
│Confirm│  Yes  │  No
└───────┘  ┌────┴────┐
           │         │
           ▼         ▼
       ┌───────┐ ┌───────┐
       │MEDIUM │ │NO     │
       │CONFID.│ │MATCH  │
       │Show   │ │New    │
       │Confirm│ │Customer
       └───────┘ └───────┘
```

---

## User Flow

### Complete Journey

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     CUSTOMER JOURNEY WITH BEAUTY ADVISOR                         │
└─────────────────────────────────────────────────────────────────────────────────┘

  DISCOVERY                ANALYSIS                 IDENTITY
  ─────────               ─────────                ─────────
      │                       │                        │
      ▼                       ▼                        ▼
  ┌───────────┐          ┌───────────┐           ┌───────────┐
  │ Browse    │          │ Widget    │           │"Is this   │
  │ Website   │          │ Expands   │           │you Sarah?"│
  │    ⭐⭐⭐   │          │   ⭐⭐⭐⭐⭐  │           │   ⭐⭐⭐⭐   │
  └─────┬─────┘          └─────┬─────┘           └─────┬─────┘
        │                      │                       │
        ▼                      ▼                       ▼
  ┌───────────┐          ┌───────────┐           ┌───────────┐
  │ Notice    │          │ Take      │           │ Confirm   │
  │ Widget    │          │ Selfie    │           │ Identity  │
  │   ⭐⭐⭐⭐   │          │   ⭐⭐⭐⭐   │           │   ⭐⭐⭐⭐⭐  │
  └─────┬─────┘          └─────┬─────┘           └─────┬─────┘
        │                      │                       │
        ▼                      ▼                       ▼
  ┌───────────┐          ┌───────────┐           ┌───────────┐
  │ Click     │          │ Face      │           │ Load      │
  │ "Find My  │          │ Analysis  │           │ Personal  │
  │  Shade"   │          │ Process   │           │ Data      │
  │  ⭐⭐⭐⭐⭐   │          │  ⭐⭐⭐⭐⭐   │           │  ⭐⭐⭐⭐⭐   │
  └───────────┘          └───────────┘           └───────────┘


  RESULTS                  PURCHASE
  ───────                  ────────
      │                        │
      ▼                        ▼
  ┌───────────┐          ┌───────────┐
  │ View      │          │ Add to    │
  │ Analysis  │          │ Cart      │
  │  ⭐⭐⭐⭐⭐   │          │  ⭐⭐⭐⭐⭐   │
  └─────┬─────┘          └─────┬─────┘
        │                      │
        ▼                      ▼
  ┌───────────┐          ┌───────────┐
  │ Select    │          │ Apply     │
  │ Category  │          │ Loyalty   │
  │   ⭐⭐⭐⭐   │          │ Points    │
  └─────┬─────┘          │   ⭐⭐⭐⭐   │
        │                └─────┬─────┘
        ▼                      │
  ┌───────────┐                ▼
  │ View      │          ┌───────────┐
  │ Matched   │          │ Complete  │
  │ Products  │          │ Checkout  │
  │  ⭐⭐⭐⭐⭐   │          │  ⭐⭐⭐⭐⭐   │
  └───────────┘          └───────────┘
```

### Identity Confirmation Logic

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         IDENTITY CONFIRMATION STRATEGY                           │
└─────────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────┐
                    │ Face Embedding  │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  Vector Search  │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Check Distance  │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
    < 0.40              0.40 - 0.55           ≥ 0.55
         │                   │                   │
         ▼                   ▼                   ▼
   ┌───────────┐       ┌───────────┐       ┌───────────┐
   │   HIGH    │       │  MEDIUM   │       │    NO     │
   │CONFIDENCE │       │CONFIDENCE │       │   MATCH   │
   └─────┬─────┘       └─────┬─────┘       └─────┬─────┘
         │                   │                   │
         └─────────┬─────────┘                   │
                   │                             │
                   ▼                             │
          ┌───────────────────┐                  │
          │ "Is this you,     │                  │
          │  {Name}?"         │                  │
          │                   │                  │
          │ [Yes]      [No]   │                  │
          └───┬─────────┬─────┘                  │
              │         │                        │
         Yes  │         │  No                    │
              │         │                        │
              ▼         └────────────────────────┤
         ┌─────────┐                             │
         │ Load    │                             │
         │ Profile │                             │
         │Personal-│                             │
         │ized     │                             │
         └────┬────┘                             │
              │                                  │
              │         ┌────────────────────────┘
              │         │
              │         ▼
              │    ┌─────────┐
              │    │   New   │
              │    │Customer │
              │    │  Flow   │
              │    └────┬────┘
              │         │
              └────┬────┘
                   │
                   ▼
          ┌───────────────────┐
          │ Show Analysis     │
          │ Results           │
          └───────────────────┘
```

---

## Deployment Guide

### Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DEPLOYMENT ARCHITECTURE                                │
└─────────────────────────────────────────────────────────────────────────────────┘

   DEVELOPER MACHINE                    SNOWFLAKE REGISTRY
  ┌───────────────────┐                ┌───────────────────┐
  │                   │                │                   │
  │  ┌─────────────┐  │                │  Container Image  │
  │  │Source Code  │  │                │  (~350MB)         │
  │  └──────┬──────┘  │                │                   │
  │         │         │   docker push  │  - Python 3.10    │
  │         ▼         │  ───────────▶  │  - FastAPI        │
  │  ┌─────────────┐  │                │  - ML Models      │
  │  │Docker Build │  │                │  - React Build    │
  │  └─────────────┘  │                │                   │
  │                   │                └─────────┬─────────┘
  └───────────────────┘                          │
                                                 │ deployed to
                                                 ▼
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                           SNOWFLAKE ACCOUNT                                  │
  │                                                                              │
  │  ┌────────────────────────────────────────────────────────────────────────┐ │
  │  │                         COMPUTE POOL                                    │ │
  │  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
  │  │  │                     SPCS SERVICE                                  │  │ │
  │  │  │                    (1-5 instances)                                │  │ │
  │  │  │                                                                   │  │ │
  │  │  │  Endpoints:                                                       │  │ │
  │  │  │  • /        → Widget                                              │  │ │
  │  │  │  • /demo    → Mock retailer site                                  │  │ │
  │  │  │  • /admin   → Configuration panel                                 │  │ │
  │  │  │  • /api/*   → Backend APIs                                        │  │ │
  │  │  └──────────────────────────────────────────────────────────────────┘  │ │
  │  └────────────────────────────────────────────────────────────────────────┘ │
  │                                      │                                       │
  │          ┌───────────────────────────┼───────────────────────────┐          │
  │          │                           │                           │          │
  │          ▼                           ▼                           ▼          │
  │  ┌───────────────┐           ┌───────────────┐           ┌───────────────┐  │
  │  │   STORAGE     │           │    CORTEX     │           │   CONFIG      │  │
  │  │               │           │               │           │               │  │
  │  │ • Database    │           │ • Agent       │           │ • Stage       │  │
  │  │ • Vector Index│           │ • Search      │           │ • retailer.json│ │
  │  │ • Tables      │           │ • Analyst     │           │ • logo.png    │  │
  │  └───────────────┘           └───────────────┘           └───────────────┘  │
  │                                                                              │
  └─────────────────────────────────────────────────────────────────────────────┘
                                         │
          ┌──────────────────────────────┼──────────────────────────────┐
          │                              │                              │
          ▼                              ▼                              ▼
    ┌───────────┐                  ┌───────────┐                  ┌───────────┐
    │  END      │                  │  ADMIN    │                  │  DEMO     │
    │ CUSTOMER  │                  │  USER     │                  │ PRESENTER │
    │           │                  │           │                  │           │
    │  /demo    │                  │  /admin   │                  │ /demo +   │
    │           │                  │           │                  │ /admin    │
    └───────────┘                  └───────────┘                  └───────────┘
```

### Deployment Steps

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              DEPLOYMENT STEPS                                    │
└─────────────────────────────────────────────────────────────────────────────────┘

  1. INFRASTRUCTURE              2. CONTAINER
  ──────────────────            ─────────────────
  ┌───────────────┐             ┌───────────────┐
  │Create Database│             │Build Docker   │
  └───────┬───────┘             │Image          │
          │                     └───────┬───────┘
          ▼                             │
  ┌───────────────┐                     ▼
  │Create Tables  │             ┌───────────────┐
  └───────┬───────┘             │Push to        │
          │                     │Registry       │
          ▼                     └───────┬───────┘
  ┌───────────────┐                     │
  │Create Vector  │                     ▼
  │Index          │             ┌───────────────┐
  └───────┬───────┘             │Create Compute │
          │                     │Pool           │
          ▼                     └───────┬───────┘
  ┌───────────────┐                     │
  │Create Search  │                     ▼
  │Services       │─────────────┌───────────────┐
  └───────────────┘             │Deploy Service │
                                └───────┬───────┘
                                        │
          ┌─────────────────────────────┘
          │
          ▼
  3. DATA                        4. CONFIGURE
  ───────                        ────────────
  ┌───────────────┐             ┌───────────────┐
  │Load Sample    │             │Set Retailer   │
  │Products       │             │Name           │
  └───────┬───────┘             └───────┬───────┘
          │                             │
          ▼                             ▼
  ┌───────────────┐             ┌───────────────┐
  │Run Label      │             │Set Brand      │
  │Extraction     │             │Colors         │
  └───────┬───────┘             └───────┬───────┘
          │                             │
          ▼                             ▼
  ┌───────────────┐             ┌───────────────┐
  │Load Sample    │─────────────│Upload Logo    │
  │Reviews        │             │               │
  └───────────────┘             └───────────────┘
                                        │
                                        ▼
                                ┌───────────────┐
                                │   ✓ DONE!     │
                                └───────────────┘
```

### SQL Execution Order

```bash
# 1. Infrastructure
snowsql -f sql/01_setup_database.sql   # Database, schemas, warehouse, stages
snowsql -f sql/02_create_tables.sql    # All tables in domain schemas

# 2. Cortex Services (created in their respective domain schemas)
snowsql -f sql/03_create_cortex_services.sql  # Vector Search, Cortex Search
snowsql -f sql/04_create_semantic_views.sql   # Cortex Analyst models

# 3. UDFs & SPCS
snowsql -f sql/05_create_udfs.sql             # CIEDE2000, shared UDFs (UTIL schema)
snowsql -f sql/06_create_spcs_service.sql     # Compute pool, SPCS service

# 4. Sample Data & Tasks
snowsql -f sql/07_sample_data.sql             # Products, customers, reviews
snowsql -f sql/08_label_extraction_task.sql   # AI_EXTRACT scheduled task
```

### Docker Build

```bash
# Set registry variables
export REGISTRY="sfsenorthamerica-demo61.registry.snowflakecomputing.com"
export REPO="agent_commerce/util/agent_commerce_repo"
export IMAGE="agent-commerce:latest"

# Build multi-stage image
docker build --platform linux/amd64 -t ${IMAGE} .

# Tag and push
docker tag ${IMAGE} ${REGISTRY}/${REPO}/${IMAGE}
docker login ${REGISTRY} -u <username>
docker push ${REGISTRY}/${REPO}/${IMAGE}
```

### Service Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/` | Widget standalone view |
| `/demo` | Mock retailer website + embedded widget |
| `/admin` | Admin configuration panel |
| `/api/*` | Backend API endpoints |
| `/widget.js` | Embeddable script for external sites |

---

## Implementation Notes

### External Data Sources

| Data | Best Source |
|------|-------------|
| Influencer profile + audience demographics | Viral Nation, CreatorIQ, or HypeAuditor (external API) |
| Influencer skin tone/type/undertone | Manual curation or AI extraction from bio |
| Social mentions + posts | Bright Data (Snowflake Marketplace) |

### AI_EXTRACT Task for Label Processing

```sql
CREATE OR REPLACE TASK extract_product_labels
  WAREHOUSE = 'COMPUTE_WH'
  SCHEDULE = 'USING CRON 0 2 * * * UTC'
AS
BEGIN
  FOR record IN (
    SELECT m.media_id, m.product_id, m.url AS image_url, m.media_subtype
    FROM PRODUCT_MEDIA m
    LEFT JOIN PRODUCT_LABELS l ON m.media_id = l.source_media_id
    WHERE m.media_subtype IN ('label', 'ingredients', 'warnings')
      AND l.label_id IS NULL
  )
  DO
    LET extraction := (
      SELECT AI_EXTRACT(
        file => TO_FILE('@product_labels', record.image_url),
        responseFormat => {
          'schema': {
            'type': 'object',
            'properties': {
              'ingredients': {'type': 'array'},
              'warnings': {'type': 'array'},
              'claims': {'type': 'array'},
              'spf': {'type': 'string'},
              'certifications': {'type': 'array'}
            }
          }
        }
      )
    );
    
    INSERT INTO PRODUCT_LABELS (...) VALUES (...);
    -- Flatten to PRODUCT_INGREDIENTS and PRODUCT_WARNINGS
  END FOR;
END;
```

---

## Quick Reference

### Key Thresholds

| Threshold | Value | Meaning |
|-----------|-------|---------|
| High confidence identity | < 0.4 | Very likely same person |
| Medium confidence identity | 0.4 - 0.55 | Probably same person |
| No match threshold | ≥ 0.55 | Treat as new customer |
| Excellent color match | ΔE00 < 2.0 | Near-perfect |
| Good color match | ΔE00 < 5.0 | Acceptable |

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health` | GET | Health check |
| `/api/chat` | POST | Main agent conversation |
| `/api/analyze` | POST | Face analysis only |
| `/api/identify` | POST | Face recognition only |
| `/api/match/{category}` | POST | Product matching |

---

*Document Version: 2.0*  
*Last Updated: December 2024*
