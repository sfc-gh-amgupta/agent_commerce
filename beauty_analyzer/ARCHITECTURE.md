# Agent Commerce - Architecture Documentation

> AI-Powered Commerce Assistant with Face Recognition, Skin Analysis, Product Matching, and ACP-Compliant Checkout
> 
> Powered by Snowflake Cortex Agent + Snowpark Container Services

## Quick Reference

| Component | Name | Status |
|-----------|------|--------|
| **Cortex Agent** | `UTIL.AGENTIC_COMMERCE_ASSISTANT` | ✅ Deployed |
| **SPCS Backend** | Face recognition, skin analysis | ✅ Running |
| **React Frontend** | Chatbot widget + Demo site | ✅ Deployed |
| **Cortex Analyst** | 5 Semantic Views | ✅ Connected |
| **Cortex Search** | 2 Search Services | ✅ Connected |
| **Beauty Tools** | AnalyzeFace, IdentifyCustomer, MatchProducts | ✅ 3 Tools |
| **ACP Cart Tools** | ACP_CreateCart, ACP_GetCart, ACP_AddItem, ACP_UpdateItem, ACP_RemoveItem, ACP_Checkout | ✅ 6 Tools |

### Deployment

```bash
# One-step deployment
export SNOWFLAKE_USER="your_user" && export SNOWFLAKE_PASSWORD="your_pass"
./deploy.sh
```

---

## Table of Contents

- [Salient & Differentiated Capabilities](#salient--differentiated-capabilities)
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

## Salient & Differentiated Capabilities

> **Why this demo stands out:** Snowflake Agent Commerce showcases capabilities that are unique to the Snowflake platform and differentiated from typical commerce demos.

### 🌟 Key Differentiators

#### 1. Face-First Commerce Experience
Unlike typical chatbots that start with text, this demo leads with **visual AI**:
- **Instant Face Recognition** → Identifies returning customers from a selfie (dlib 128-dim embeddings + Cortex Vector Search)
- **Scientific Skin Analysis** → Fitzpatrick type, Monk shade, undertone detection in seconds
- **Privacy-First Verification** → Agent asks "Are you [Name]?" before revealing any account details

> 💡 *Most commerce demos use email/login. This uses your face as the "password".*

#### 2. Color Science Product Matching (CIEDE2000)
Not just "similar products" but **perceptually accurate color matching**:
- Uses **CIEDE2000 (ΔE00)** — the gold standard for human color perception
- Matches products to detected skin tone in LAB color space
- ΔE00 < 2.0 = imperceptible difference to human eye

> 💡 *Generic demos use keyword search. This matches colors the way humans perceive them.*

#### 3. 16 Cortex Agent Tools in One Demo
A comprehensive showcase of **all Cortex capabilities** in a single orchestrated agent:

| Tool Type | Count | Examples |
|-----------|-------|----------|
| **Cortex Analyst** | 5 | CustomerAnalyst, ProductAnalyst, InventoryAnalyst, SocialAnalyst, CheckoutAnalyst |
| **Cortex Search** | 2 | ProductSearch, SocialSearch |
| **Custom UDFs** | 3 | AnalyzeFace, IdentifyCustomer, MatchProducts |
| **ACP Cart Tools** | 6 | ACP_CreateCart, ACP_AddItem, ACP_GetCart, ACP_UpdateItem, ACP_RemoveItem, ACP_Checkout |

> 💡 *Most demos show 1-2 tools. This orchestrates 16 tools in a single conversation.*

#### 4. ACP-Compliant Agentic Checkout
Implements **OpenAI's Agentic Commerce Protocol (ACP)** natively on Snowflake:
- `ACP_CreateCart` → `ACP_AddItem` → `ACP_GetCart` → `ACP_Checkout`
- Uses **Hybrid Tables** for ACID transactions (10-50ms latency)
- Full cart lifecycle managed by the agent, not hardcoded in frontend

> 💡 *This positions Snowflake as a platform for the emerging ACP standard.*

#### 5. Multi-Source Social Proof
Unified semantic search across **reviews + influencers + social mentions**:
- Customer reviews with skin tone/type metadata for personalized filtering
- Influencer mentions with audience demographics
- Trending products calculated from mention velocity

> 💡 *Shows Cortex Search unifying disparate content sources into one semantic index.*

#### 6. Embeddable Widget Architecture
Production-ready deployment pattern for real-world use:
- Single `<script>` tag embeds into any retailer website
- Admin UI for **no-code customization** (colors, logo, welcome messages)
- 12 pre-built industry themes (Sephora, Ulta, MAC, Glossier, etc.)

> 💡 *Not just a demo — this is a deployable SaaS architecture pattern.*

#### 7. Complete AI Stack in Snowflake
**Zero external AI services required** — everything runs in Snowflake:

| Capability | Snowflake Feature |
|------------|------------------|
| Face embeddings | SPCS + dlib ResNet |
| Face matching | Cortex Vector Search |
| Product discovery | Cortex Search |
| Structured queries | Cortex Analyst |
| Agent orchestration | Cortex Agent |
| Label extraction | AI_EXTRACT |
| Transactions | Hybrid Tables |

> 💡 *Demonstrates Snowflake as a complete AI platform, not just a data warehouse.*

### 📊 Demo Flow Summary

```
📸 Selfie Upload
    ↓
🔬 Face Analysis (skin tone, Monk shade, Fitzpatrick, undertone)
    ↓
🔍 Identity Check (Vector Search → "Are you Sarah?")
    ↓
✅ Email Verification (privacy-first, no data leak)
    ↓
🎨 Color-Matched Products (CIEDE2000 algorithm)
    ↓
⭐ Social Proof (reviews, influencer mentions)
    ↓
🛒 Agentic Checkout (ACP tools on Hybrid Tables)
```

### 🎯 Target Audience Positioning

| Audience | Key Message |
|----------|-------------|
| **Retail/CPG Executives** | "AI-powered personalization without leaving Snowflake" |
| **Solution Architects** | "16 Cortex tools orchestrated in one agent" |
| **Data Engineers** | "Unified data + AI + transactions in one platform" |
| **Product Leaders** | "From data warehouse to AI commerce platform" |

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
│  │  │CUSTOMERS │ │PRODUCTS  │ │INVENTORY │ │ SOCIAL   │ │CART_OLTP │        │  │
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
name: AGENTIC_COMMERCE_ASSISTANT
model: claude-4-sonnet
location: UTIL.AGENTIC_COMMERCE_ASSISTANT
description: |
  AI Commerce Assistant with face analysis, product matching, 
  and ACP-compliant checkout capabilities.

# Created via Cortex Agent GA syntax (CREATE AGENT)
# See sql/11_create_cortex_agent.sql for full specification

tools:
  # Cortex Analyst (5) - Semantic Views for structured queries
  - CustomerAnalyst        # CUSTOMERS.CUSTOMER_SEMANTIC_VIEW
  - ProductAnalyst         # PRODUCTS.PRODUCT_SEMANTIC_VIEW
  - InventoryAnalyst       # INVENTORY.INVENTORY_SEMANTIC_VIEW
  - SocialAnalyst          # SOCIAL.SOCIAL_PROOF_SEMANTIC_VIEW
  - CheckoutAnalyst        # CART_OLTP.CART_SEMANTIC_VIEW

  # Cortex Search (2) - Semantic search for discovery
  - ProductSearch          # PRODUCTS.PRODUCT_SEARCH_SERVICE
  - SocialSearch           # SOCIAL.SOCIAL_SEARCH_SERVICE

  # Beauty Analysis (3) - Custom UDFs
  - AnalyzeFace            # CUSTOMERS.TOOL_ANALYZE_FACE (Python UDF → SPCS)
  - IdentifyCustomer       # CUSTOMERS.TOOL_IDENTIFY_CUSTOMER (SQL UDTF)
  - MatchProducts          # PRODUCTS.TOOL_MATCH_PRODUCTS (SQL UDTF)

  # ACP Cart/Checkout (6) - Stored Procedures (Hybrid Tables)
  - ACP_CreateCart         # CART_OLTP.TOOL_CREATE_CART_SESSION
  - ACP_GetCart            # CART_OLTP.TOOL_GET_CART_SESSION
  - ACP_AddItem            # CART_OLTP.TOOL_ADD_TO_CART
  - ACP_UpdateItem         # CART_OLTP.TOOL_UPDATE_CART_ITEM
  - ACP_RemoveItem         # CART_OLTP.TOOL_REMOVE_FROM_CART
  - ACP_Checkout           # CART_OLTP.TOOL_SUBMIT_ORDER
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

### ACP Cart/Checkout Tools (OpenAI Agentic Commerce Protocol)

> **Note:** All cart tools use `ACP_` prefix to indicate ACP compliance.
> Uses Hybrid Tables for ACID transactions and low-latency operations.

| Tool | Type | Description |
|------|------|-------------|
| `ACP_CreateCart` | Procedure | Create new cart session for customer |
| `ACP_GetCart` | Function | Get cart contents with items and totals |
| `ACP_AddItem` | Procedure | Add product to cart |
| `ACP_UpdateItem` | Procedure | Update item quantity |
| `ACP_RemoveItem` | Procedure | Remove item from cart |
| `ACP_Checkout` | Procedure | Finalize order and process |

---

## Data Layer

### Schema Organization

| Schema | Purpose | Cortex Services |
|--------|---------|-----------------|
| **CUSTOMERS** | Profiles, embeddings, analysis history | Vector Search (face embeddings), Analyst |
| **PRODUCTS** | Catalog, variants, media, labels | Search (products, labels), Analyst |
| **INVENTORY** | Locations, stock levels, transactions | Analyst |
| **SOCIAL** | Reviews, mentions, influencers, trends | Search (social content), Analyst |
| **CART_OLTP** | Cart sessions, payments, orders (Hybrid Tables) | Analyst |
| **UTIL** | SPCS services, shared UDFs, Cortex Agent | — |
| **DEMO_CONFIG** | Retailer settings, themes, branding (Admin UI) | — |

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

### CART_OLTP Tables (Hybrid Tables for ACID Transactions)

> **Note:** All tables in CART_OLTP are Snowflake Hybrid Tables for:
> - ACID transactions (cart updates, payments)
> - Row-level locking (concurrent users)
> - Enforced foreign key constraints
> - Low-latency single-row operations (10-50ms)

```sql
-- Cart sessions (HYBRID TABLE)
CREATE OR REPLACE HYBRID TABLE CART_SESSIONS (
    session_id VARCHAR(36) PRIMARY KEY,
    customer_id VARCHAR(36),
    status VARCHAR(30) NOT NULL DEFAULT 'active',
    
    -- Pricing (amounts in cents for precision)
    subtotal_cents INTEGER DEFAULT 0,
    tax_cents INTEGER DEFAULT 0,
    shipping_cents INTEGER DEFAULT 0,
    discount_cents INTEGER DEFAULT 0,
    total_cents INTEGER DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Fulfillment
    fulfillment_type VARCHAR(20),
    shipping_address VARCHAR(2000),  -- JSON as string (HYBRID limitation)
    
    -- Timestamps
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ,
    expires_at TIMESTAMP_NTZ,
    
    INDEX idx_cart_customer (customer_id)
);

-- Cart items (HYBRID TABLE)
CREATE OR REPLACE HYBRID TABLE CART_ITEMS (
    item_id VARCHAR(36) PRIMARY KEY,
    session_id VARCHAR(36) NOT NULL,
    product_id VARCHAR(36) NOT NULL,
    variant_id VARCHAR(36),
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price_cents INTEGER NOT NULL,
    subtotal_cents INTEGER NOT NULL,
    product_name VARCHAR(255),
    added_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    FOREIGN KEY (session_id) REFERENCES CART_SESSIONS(session_id),
    INDEX idx_cart_items_session (session_id)
);

-- Orders (HYBRID TABLE - created after successful checkout)
CREATE OR REPLACE HYBRID TABLE ORDERS (
    order_id VARCHAR(36) PRIMARY KEY,
    order_number VARCHAR(20) NOT NULL,  -- Human-readable
    session_id VARCHAR(36),
    customer_id VARCHAR(36),
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    subtotal_cents INTEGER NOT NULL,
    tax_cents INTEGER NOT NULL,
    shipping_cents INTEGER NOT NULL,
    total_cents INTEGER NOT NULL,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    FOREIGN KEY (session_id) REFERENCES CART_SESSIONS(session_id),
    INDEX idx_order_customer (customer_id)
);

-- Order items (HYBRID TABLE)
CREATE OR REPLACE HYBRID TABLE ORDER_ITEMS (
    order_item_id VARCHAR(36) PRIMARY KEY,
    order_id VARCHAR(36) NOT NULL,
    product_id VARCHAR(36) NOT NULL,
    variant_id VARCHAR(36),
    quantity INTEGER NOT NULL,
    unit_price_cents INTEGER NOT NULL,
    subtotal_cents INTEGER NOT NULL,
    product_name VARCHAR(255),
    
    FOREIGN KEY (order_id) REFERENCES ORDERS(order_id),
    INDEX idx_order_items_order (order_id)
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

> **Note:** Text input is ALWAYS visible at the bottom - users can type anytime.

```
┌─────────────────────────────────────────┐
│  HEADER                                 │
│  ┌────────────────────────────────────┐ │
│  │ [LOGO]  Commerce Assistant      ✕  │ │
│  │         by [RETAILER NAME]         │ │
│  └────────────────────────────────────┘ │
│                                         │
│  CHAT AREA (scrollable)                 │
│  ┌────────────────────────────────────┐ │
│  │                                    │ │
│  │  💬 Message bubbles appear here    │ │
│  │                                    │ │
│  │  ┌──────────────────────────────┐  │ │
│  │  │  Bot: Hi! I'm your Commerce  │  │ │
│  │  │  Assistant. Ready to help?   │  │ │
│  │  └──────────────────────────────┘  │ │
│  │                                    │ │
│  │  [Analysis cards, products, etc.]  │ │
│  │                                    │ │
│  └────────────────────────────────────┘ │
│                                         │
│  QUICK ACTIONS (collapsible)            │
│  ┌────────────────────────────────────┐ │
│  │  📸 Selfie    📁 Upload            │ │
│  └────────────────────────────────────┘ │
│                                         │
│  INPUT (ALWAYS VISIBLE)                 │
│  ┌────────────────────────────────────┐ │
│  │  Type a message...            📎 ➤ │ │  ← Persistent
│  └────────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### Widget Features

| Feature | Description |
|---------|-------------|
| **Maximize Button** | Expands widget to full-screen ChatGPT-like interface (⊕/⊖ toggle) |
| **Cart Badge** | Shows real-time item count on main website header when ACP cart tools are used |
| **Face Analysis Card** | Visual rendering with color swatches, undertone badges, and Fitzpatrick/Monk scales |
| **Tool Badges** | Shows which Cortex Agent tools were used for each response |
| **Markdown Support** | Rich rendering of tables, code blocks, lists, and emphasis |
| **Image Upload** | Upload photos for face analysis with drag-and-drop or camera capture |
| **Theme Presets** | 12 industry themes (beauty, electronics, fashion, grocery, airlines, hotels) |

### Maximized Mode

```
┌─────────────────────────────────────────────────────────────────┐
│  HEADER                                              [⊖] [✕]  │
│  Commerce Assistant by [RETAILER NAME]                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                        CHAT AREA                                │
│         (Centered, max-width 800px, like ChatGPT)               │
│                                                                 │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │  Face Analysis Results                              ✨  │  │
│    │  ┌─────────┐  ┌─────────┐                               │  │
│    │  │  Skin   │  │  Lip    │  Undertone: [Warm]            │  │
│    │  │ #C68642 │  │ #E75480 │  Fitzpatrick: IV              │  │
│    │  └─────────┘  └─────────┘  Monk: 5/10                   │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│    ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐         │
│    │Product 1│  │Product 2│  │Product 3│  │Product 4│         │
│    └─────────┘  └─────────┘  └─────────┘  └─────────┘         │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  📷  [Type a message...                              ]    ➤    │
└─────────────────────────────────────────────────────────────────┘
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

### Admin Panel (No Code Required)

> **Key Feature:** All customizations are done via Admin UI (`/admin`) - no coding required.
> Demo presenters can customize the widget appearance in real-time during demos.

```
┌─────────────────────────────────────────────────────────────────────┐
│  ADMIN PANEL (/admin) - No Code Customization                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Retailer Name: [Sephora        ]                                   │
│                                                                      │
│  Logo: [Upload] [sephora-logo.png ✓]                                │
│                                                                      │
│  Theme Presets:                                                      │
│  [Sephora] [Ulta] [MAC] [Glossier] [Custom]                         │
│                                                                      │
│  Colors:                                                             │
│  Primary:    [■ #000000]   Secondary: [■ #E60023]                   │
│  Background: [■ #FFFFFF]   Accent:    [■ #C9A050]                   │
│                                                                      │
│  Widget Position: ○ Bottom-Left  ● Bottom-Right                     │
│                                                                      │
│  Welcome Message:                                                    │
│  [Hi! I'm your Commerce Assistant. Ready to help?                ]  │
│                                                                      │
│  [Save Changes]  ← Updates apply instantly to /demo                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Access Points

| User Type | Access | Purpose |
|-----------|--------|---------|
| End Customer | `/demo` | Widget experience only |
| Admin User | `/admin` | Configuration only |
| Demo Presenter | `/demo` + `/admin` | Full demo capabilities |

### Configuration Priority (Highest to Lowest)

```
1. Admin UI Changes  ← Live edits during demo (highest priority)
2. retailer.json file
3. Default values
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
│   ├── 00_deploy_from_github_complete.sql  # Master one-click deployment script
│   ├── 01_setup_database.sql         # Database, schemas, warehouse, stages
│   ├── 02_create_tables.sql          # All domain tables (includes Hybrid Tables)
│   ├── 03_create_semantic_views.sql  # Cortex Analyst semantic views
│   ├── 04_create_cortex_search.sql   # Cortex Search services
│   ├── 05_create_vector_search.sql   # Vector search for face embeddings
│   ├── 09_load_face_images_and_embeddings.sql  # Face image processing
│   ├── 10_create_agent_tools.sql     # Custom UDFs/Procedures for agent
│   └── 11_create_cortex_agent.sql    # Cortex Agent definition (GA syntax)
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

### One-Step Deployment

The easiest way to deploy the entire application is using the **1-step deploy script**:

```bash
# Set environment variables
export SNOWFLAKE_USER="your_username"
export SNOWFLAKE_PASSWORD="your_password"
export SNOWFLAKE_ACCOUNT="your-account.region"  # Optional - defaults provided

# Run the deployment
cd beauty_analyzer
./deploy.sh
```

This script handles everything:
1. ✅ Builds React frontend
2. ✅ Builds Docker image
3. ✅ Pushes to Snowflake Container Registry
4. ✅ Logs Face Analysis Model to Model Registry
5. ✅ Creates/updates Cortex Agent
6. ✅ Recreates SPCS backend service

### Manual SQL Execution (Alternative)

```bash
# Execute the complete deployment script from Snowsight or SnowSQL
EXECUTE IMMEDIATE FROM @AGENT_COMMERCE.UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/00_deploy_from_github_complete.sql;
```

### Docker Build (Manual)

```bash
# Set registry variables
export SNOWFLAKE_REGISTRY="${SNOWFLAKE_ACCOUNT}.registry.snowflakecomputing.com"
export REPO="agent_commerce/util/agent_commerce_repo"
export IMAGE="agent-commerce-backend:latest"

# Build multi-stage image
docker build --platform linux/amd64 -t ${REPO}/${IMAGE} backend/

# Tag and push
docker tag ${REPO}/${IMAGE} ${SNOWFLAKE_REGISTRY}/${REPO}/${IMAGE}
docker login ${SNOWFLAKE_REGISTRY} -u ${SNOWFLAKE_USER}
docker push ${SNOWFLAKE_REGISTRY}/${REPO}/${IMAGE}
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

### Test Customers with Real Face Embeddings

The following customers have **real 128-dimensional dlib face embeddings** extracted from actual face images. Use these for testing the identity recognition flow:

| # | Customer | Email | Tier | Points | Image Source |
|---|----------|-------|------|--------|--------------|
| 1 | **Priya Sharma** | priya.sharma@email.com | Silver | 4,287 | `25934.jpg` |
| 2 | **Olivia Martin** | olivia.martin407@email.com | Silver | 4,471 | `2903.jpg` |
| 3 | **Layla Lopez** | layla.lopez333@email.com | Gold | 913 | `6523.jpg` |
| 4 | **Riley Williams** | riley.williams943@email.com | Gold | 847 | `25213.jpg` |
| 5 | **Amara Okonkwo** | amara.okonkwo@email.com | Platinum | 1,752 | `4219.jpg` |
| 6 | **Amelia Johnson** | amelia.johnson710@email.com | Platinum | 4,285 | `2429.jpg` |
| 7 | **Emma Anderson** | emma.anderson@email.com | Bronze | 3,507 | `42247.jpg` |
| 8 | **Fatima Al-Hassan** | fatima.alhassan@email.com | Gold | 3,377 | `27370.jpg` |

> **Note:** Image files are located in `data/generated/images/faces/`. These embeddings were generated using the `ML_FACE_ANALYSIS_SERVICE` which uses dlib's ResNet model for 128-dimensional face embeddings.

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

*Document Version: 3.0*  
*Last Updated: January 2026*

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 3.0 | Jan 2026 | Renamed agent to AGENTIC_COMMERCE_ASSISTANT, ACP_ prefix for cart tools, Hybrid Tables for CART_OLTP, Admin UI no-code customization |
| 2.0 | Dec 2024 | Added Cortex Agent GA syntax, SPCS backend, face embedding pipeline |
| 1.0 | Nov 2024 | Initial architecture design |
