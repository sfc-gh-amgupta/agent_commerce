# Beauty Analyzer - Project Documentation

**AI-Powered Beauty Advisor with Face Recognition, Skin Analysis, and Product Matching**

*Powered by Snowflake Cortex Agent + Snowpark Container Services*

---

## Table of Contents

1. Overview
2. System Architecture
3. Cortex Agent Design
4. Tool Catalog
5. Data Layer
6. Chatbot Widget Design
7. Customization System
8. Module Structure
9. User Flow
10. Deployment Guide

---

## 1. Overview

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
| AI Brain | Snowflake Cortex Agent |
| Frontend | React.js Chatbot Widget (embeddable) |
| Backend | FastAPI (Python) in SPCS |
| Face Detection | MediaPipe Face Mesh (468 landmarks) |
| Face Recognition | dlib ResNet (128-dim embeddings) |
| Customer Identification | Cortex Vector Search (ANN) |
| Product/Social Search | Cortex Search (semantic) |
| Structured Queries | Cortex Analyst + Semantic Views |
| Label Extraction | AI_EXTRACT |
| Color Distance | CIEDE2000 (ΔE00) |
| Deployment | Snowpark Container Services (SPCS) |

---

## 2. System Architecture

### High-Level Architecture

**[DIAGRAM: System Architecture]**

The system consists of three main layers:

**User Layer:**
- Retailer Website → Chatbot Widget (React.js)

**Snowflake Account Layer:**
- SPCS Container containing:
  - FastAPI Backend
  - ML Models (MediaPipe, dlib + OpenCV)
  - React Static Files

- Cortex Services:
  - Cortex Agent (Orchestrator)
  - Vector Search (Embeddings)
  - Cortex Search (Semantic)
  - Cortex Analyst
  - AI_EXTRACT (Label Processing)

- Data Layer (Schemas):
  - CUSTOMERS
  - PRODUCTS
  - INVENTORY
  - SOCIAL
  - CHECKOUT
  - UTIL (SPCS, shared UDFs)
  - DEMO_CONFIG (settings)

### Tool Hosting Strategy

**Cortex Agent (Orchestrator)** connects to three service categories:

1. **SPCS Container**
   - analyze_face
   - detect_makeup
   - match_products

2. **Cortex Vector Search**
   - identify_customer (ANN lookup)

3. **Cortex Search**
   - search_products
   - search_labels
   - search_social

4. **Cortex Analyst**
   - query_products
   - query_inventory
   - query_customer
   - query_social

5. **SQL/Python UDFs**
   - calculate_ciede
   - checkout_tools
   - redeem_points

6. **AI_EXTRACT**
   - Label processing
   - Ingredient extraction

### Request Flow

1. User uploads image to Widget
2. Widget sends POST /api/chat to FastAPI
3. FastAPI forwards request to Cortex Agent
4. Cortex Agent calls analyze_face() for ML processing
5. Cortex Agent calls identify_customer via ANN Search
6. Cortex Agent calls search_products via Semantic Match
7. JSON Response returned to FastAPI
8. Results displayed in Widget to User

---

## 3. Cortex Agent Design

### Agent Configuration

```
Name: beauty_advisor
Model: claude-3-5-sonnet

Description:
AI Beauty Advisor that helps customers find perfect cosmetic matches
based on skin tone analysis and personal preferences.

System Prompt:
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

Available Tools:
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
```

### Conversation Flow

**[DIAGRAM: Conversation Flow]**

1. **START** → **WELCOME**
2. User chooses: Take Selfie | Upload Photo | Text Chat
3. If photo provided → **Face Analysis** → **Identity Check**
4. Identity Check results:
   - Match found → "Is this you, Sarah?" → Yes (Login) or No (New Customer)
   - No match → New Customer Flow
5. **Show Analysis Results**
6. **Category Select** → **Product Matching** → **Show Products**
7. User can: Try Another Category OR Add to Cart
8. **CHECKOUT** → **END**

---

## 4. Tool Catalog

### Beauty Analysis Tools (SPCS)

| Tool | Description | Parameters | Returns |
|------|-------------|------------|---------|
| analyze_face | Full face analysis | image: base64 | skin_tone, lip_color, embedding, undertone, fitzpatrick, monk |
| detect_makeup | Check for makeup | image: base64 | is_wearing_makeup, detected_products, estimated_natural_colors |
| match_products | CIEDE2000 matching | skin_lab, category, limit | products with delta_e scores |

### Customer Tools

| Tool | Type | Description |
|------|------|-------------|
| identify_customer | Cortex Vector Search | Match face embedding to known customers |
| query_customer | Cortex Analyst | Profile, history, loyalty points, preferences |
| update_customer_profile | SQL UDF | Update skin profile, preferences |
| redeem_points | SQL UDF | Apply loyalty points to checkout |

### Product Tools

| Tool | Type | Description |
|------|------|-------------|
| query_products | Cortex Analyst | Structured queries: pricing, variants, promotions |
| search_products | Cortex Search | Semantic product discovery |
| analyze_product_image | CORTEX.COMPLETE | Answer questions about product images |
| search_product_labels | Cortex Search | Find by ingredients, warnings, claims |
| query_inventory | Cortex Analyst | Stock levels, availability by location |

### Social Proof Tools

| Tool | Type | Description |
|------|------|-------------|
| query_social_proof | Cortex Analyst | Ratings, review counts, trends, influencer stats |
| search_social_proof | Cortex Search | Semantic search across reviews/mentions |

### Agentic Checkout Tools (OpenAI Spec)

| Tool | Description |
|------|-------------|
| create_checkout_session | Create session from current selections |
| get_checkout_session | Get session state with items and pricing |
| add_to_checkout | Add product to session |
| update_checkout_item | Update item quantity |
| remove_from_checkout | Remove item from session |
| get_fulfillment_options | Get shipping/pickup options |
| set_fulfillment | Set address and shipping method |
| get_payment_methods | Get customer's saved payment methods |
| submit_checkout | Finalize and process payment |

---

## 5. Data Layer

### Schema Organization

| Schema | Purpose | Cortex Services |
|--------|---------|-----------------|
| CUSTOMERS | Profiles, embeddings, analysis history | Vector Search (face embeddings), Analyst |
| PRODUCTS | Catalog, variants, media, labels | Search (products, labels), Analyst |
| INVENTORY | Locations, stock levels, transactions | Analyst |
| SOCIAL | Reviews, mentions, influencers, trends | Search (social content), Analyst |
| CHECKOUT | Sessions, payments, orders | Analyst |
| UTIL | SPCS services, shared UDFs, integrations | — |
| DEMO_CONFIG | Retailer settings, themes, branding | — |

**Design Principle:** Each domain schema contains its own Cortex Search services, Cortex Analyst semantic views, and domain-specific UDFs. This keeps related objects together and simplifies access control.

### Entity Relationships

**CUSTOMERS Schema:**
- CUSTOMERS (customer_id PK) → links to:
  - FACE_EMBEDDINGS
  - ANALYSIS_HISTORY
  - CHECKOUT_SESSIONS
  - PAYMENT_METHODS
  - PRODUCT_REVIEWS (optional)

**PRODUCTS Schema:**
- PRODUCTS (product_id PK) → links to:
  - VARIANTS
  - MEDIA
  - LABELS → INGREDIENTS, WARNINGS
  - REVIEWS
  - SOCIAL_MENTIONS
  - INFLUENCER_MENTIONS
  - TRENDING_PRODUCTS

**INVENTORY Schema:**
- STOCK_LEVELS → LOCATIONS
- INVENTORY_TRANSACTIONS (audit trail)

**CHECKOUT Schema:**
- CHECKOUT_SESSIONS → LINE_ITEMS → PRODUCTS
- PAYMENT_TRANSACTIONS
- FULFILLMENT_OPTIONS

### Key Tables

#### Customer & Identity Tables

**CUSTOMERS**
- customer_id (PK)
- email (UNIQUE)
- first_name, last_name
- loyalty_tier ('Bronze', 'Silver', 'Gold', 'Platinum')
- points_balance
- skin_profile (OBJECT: skin_tone, undertone, fitzpatrick, monk)
- preferences (OBJECT: favorite_brands, allergies, etc.)
- created_at, updated_at

**CUSTOMER_FACE_EMBEDDINGS**
- embedding_id (PK)
- customer_id (FK)
- embedding VECTOR(FLOAT, 128) — dlib 128-dim embedding
- quality_score
- lighting_condition
- is_active
- created_at

**SKIN_ANALYSIS_HISTORY**
- analysis_id (PK)
- customer_id (FK)
- image_stage_path
- skin_hex, skin_lab
- lip_hex, lip_lab
- fitzpatrick_type, monk_shade
- undertone
- makeup_detected
- confidence_score
- analyzed_at

#### Product Tables

**PRODUCTS**
- product_id (PK)
- name, brand, category, subcategory
- description
- base_price, current_price
- color_hex, color_lab [L, a, b]
- finish ('matte', 'satin', 'glossy', 'shimmer')
- skin_tone_compatibility (ARRAY)
- undertone_compatibility (ARRAY)
- is_active, launch_date, created_at

**PRODUCT_VARIANTS**
- variant_id (PK), product_id (FK)
- sku (UNIQUE), shade_name
- color_hex, color_lab, size
- price_modifier, is_available

**PRODUCT_MEDIA**
- media_id (PK), product_id (FK)
- url, media_type, media_subtype
- alt_text, display_order, created_at

**PRODUCT_LABELS**
- label_id (PK), product_id (FK)
- label_type ('ingredients', 'warnings', 'claims')
- extracted_text, structured_data (VARIANT)
- source_image_url, source_media_id (FK)
- extraction_model, extraction_date

#### Inventory Tables

**LOCATIONS**
- location_id (PK)
- name, type ('warehouse', 'store')
- address, is_active

**STOCK_LEVELS**
- stock_id (PK)
- product_id, variant_id, location_id (FK)
- quantity_on_hand, quantity_reserved
- quantity_available (computed)
- reorder_point, reorder_quantity
- last_updated

#### Social Proof Tables

**PRODUCT_REVIEWS**
- review_id (PK), product_id (FK)
- customer_id, platform
- rating (1-5), title, review_text, review_url
- helpful_votes, verified_purchase
- reviewer_skin_tone, reviewer_skin_type, reviewer_undertone
- created_at

**SOCIAL_MENTIONS**
- mention_id (PK), product_id (FK)
- platform, post_url, content_text, media_url
- author_handle
- likes, comments, shares
- sentiment_score (-1 to 1)
- posted_at, ingested_at

**INFLUENCER_MENTIONS**
- mention_id (PK), product_id (FK)
- influencer_id, influencer_handle, influencer_name
- platform, post_url, content_text, media_url
- likes, comments, shares
- influencer_skin_tone, influencer_skin_type, influencer_undertone
- follower_count, engagement_rate
- audience_demographics (OBJECT)
- posted_at, ingested_at

**TRENDING_PRODUCTS**
- trend_id (PK), product_id (FK)
- trend_rank, trend_score
- mention_velocity (mentions per hour)
- is_viral, trending_platforms (ARRAY)
- calculated_at

#### Checkout Tables

**CHECKOUT_SESSIONS**
- session_id (PK), customer_id (FK)
- status ('active', 'pending_payment', 'completed', 'expired', 'cancelled')
- subtotal_cents, tax_cents, shipping_cents, discount_cents, total_cents
- currency, fulfillment_type
- shipping_address, shipping_method_id
- is_gift, gift_message
- is_valid, validation_message
- idempotency_key (UNIQUE)
- created_at, updated_at, expires_at

**LINE_ITEMS**
- line_item_id (PK), session_id (FK)
- product_id (FK), variant_id
- quantity, unit_price_cents, subtotal_cents
- added_at

### Cortex Search Services

**PRODUCTS Schema:**
- product_search — Semantic product discovery
- label_search — Find by ingredients, warnings, claims (with source traceability)

**SOCIAL Schema:**
- social_proof_search — Unified search across reviews, social mentions, and influencer mentions

### Cortex Vector Search Index

**CUSTOMERS Schema:**
- face_embedding_index on customer_face_embeddings(embedding)
- Using L2_DISTANCE
- TARGET_RECALL = 0.95

---

## 6. Chatbot Widget Design

### Widget States

1. **COLLAPSED (Button)** — Initial state on page load
2. **EXPANDED (Chat UI)** — User clicks button to expand
3. **Input Options:**
   - Camera Capture
   - Upload Photo
   - Text Chat
4. **PROCESSING** — Face analysis in progress
5. **Identity Confirm** — "Is this you, Sarah?"
6. **Analysis Results** — Display skin/lip analysis
7. **Category Select** — Choose product category
8. **Product Matches** — Show matched products
9. **CHECKOUT** — Complete purchase

### Widget Layout

**HEADER**
- Logo + "Beauty Advisor" + Close button
- Retailer name subtitle

**CHAT AREA**
- Message bubbles
- Bot welcome message
- Analysis results cards
- Product recommendations

**ACTIONS**
- 📸 Take a Selfie button
- 📁 Upload a Photo button

**INPUT**
- Text input field
- Attachment button
- Send button

### Analysis Results Display

**Your Beauty Profile Card:**

| SKIN TONE | LIP COLOR | UNDERTONE |
|-----------|-----------|-----------|
| [Color swatch] | [Color swatch] | ☀️ |
| #C68642 | #B56B72 | WARM |
| Monk: 5 | Natural | |
| Fitz: IV | | |

*⚠️ Lipstick detected (showing estimated natural color)*

---

## 7. Customization System

### Configuration Priority (Highest to Lowest)

1. Environment Variables
2. Admin UI Changes
3. retailer.json File
4. Default Values

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
| Sephora | #000000 | #E60023 | #FFFFFF | #C9A050 |
| Ulta | #FF6900 | #FF1493 | #FFF5EE | #FFD700 |
| MAC | #000000 | #000000 | #FFFFFF | #808080 |
| Glossier | #FFB6C1 | #FF69B4 | #FFF0F5 | #FF1493 |

---

## 8. Module Structure

### Project Directory

```
beauty_analyzer/
│
├── backend/
│   ├── src/
│   │   ├── app.py                    # FastAPI application
│   │   │
│   │   ├── # COLOR SCIENCE
│   │   ├── color_utils.py            # LAB, CIEDE2000, ITA, undertone
│   │   │
│   │   ├── # FACE PROCESSING
│   │   ├── face_detector.py          # MediaPipe face detection
│   │   ├── face_recognizer.py        # dlib embeddings
│   │   ├── makeup_detector.py        # Makeup detection
│   │   │
│   │   ├── # ANALYSIS
│   │   ├── skin_analyzer.py          # Skin tone analysis
│   │   ├── lip_analyzer.py           # Lip color analysis
│   │   ├── face_analyzer.py          # Main orchestrator
│   │   │
│   │   ├── # MATCHING
│   │   ├── product_matcher.py        # CIEDE2000 matching
│   │   │
│   │   ├── # SERVICES
│   │   ├── customer_service.py       # Customer CRUD
│   │   ├── checkout_service.py       # Checkout operations
│   │   ├── config_service.py         # Config loading
│   │   ├── database.py               # Snowflake connection
│   │   │
│   │   └── # MODELS
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
│
├── sql/
│   ├── 01_setup_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_create_cortex_services.sql
│   ├── 04_create_semantic_views.sql
│   ├── 05_create_udfs.sql
│   ├── 06_create_spcs_service.sql
│   ├── 07_sample_data.sql
│   └── 08_label_extraction_task.sql
│
├── semantic_views/
│   ├── customers.yaml
│   ├── products.yaml
│   ├── inventory.yaml
│   ├── social_proof.yaml
│   └── checkout.yaml
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
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### Key Module Details

#### Color Distance (CIEDE2000)

CIEDE2000 calculates perceptual color distance between two LAB colors using:
- ΔL' (Lightness difference)
- ΔC' (Chroma difference)
- ΔH' (Hue difference)
- Rotation Term (for blue region correction)

**Match Quality by ΔE00 Score:**

| ΔE00 Range | Quality | Description |
|------------|---------|-------------|
| < 1.0 | Imperceptible | Identical to human eye |
| 1.0 - 2.0 | Excellent | Near-perfect match |
| 2.0 - 3.5 | Great | Very good match |
| 3.5 - 5.0 | Good | Acceptable match |
| ≥ 5.0 | Fair | Noticeable difference |

#### Face Recognition Flow

1. **Input Image** → Face Detection (MediaPipe)
2. Face Crop (Aligned)
3. Embedding Generation (dlib ResNet)
4. 128-dim Vector output
5. Cortex Vector Search (ANN)
6. Top 10 Candidates returned
7. Exact Distance Verification
8. **Decision Logic:**
   - distance < 0.4 → HIGH CONFIDENCE (Show Confirm)
   - distance 0.4-0.55 → MEDIUM CONFIDENCE (Show Confirm)
   - distance ≥ 0.55 → NO MATCH (New Customer)

---

## 9. User Flow

### Complete Customer Journey

**DISCOVERY PHASE:**
1. Browse Website ⭐⭐⭐
2. Notice Widget ⭐⭐⭐⭐
3. Click "Find My Shade" ⭐⭐⭐⭐⭐

**ANALYSIS PHASE:**
4. Widget Expands ⭐⭐⭐⭐⭐
5. Take Selfie ⭐⭐⭐⭐
6. Face Analysis Process ⭐⭐⭐⭐⭐

**IDENTITY PHASE:**
7. "Is this you Sarah?" ⭐⭐⭐⭐
8. Confirm Identity ⭐⭐⭐⭐⭐
9. Load Personal Data ⭐⭐⭐⭐⭐

**RESULTS PHASE:**
10. View Analysis ⭐⭐⭐⭐⭐
11. Select Category ⭐⭐⭐⭐
12. View Matched Products ⭐⭐⭐⭐⭐

**PURCHASE PHASE:**
13. Add to Cart ⭐⭐⭐⭐⭐
14. Apply Loyalty Points ⭐⭐⭐⭐
15. Complete Checkout ⭐⭐⭐⭐⭐

### Identity Confirmation Logic

**Face Embedding → Vector Search → Check Distance**

| Distance | Confidence | Action |
|----------|------------|--------|
| < 0.40 | HIGH | Show "Is this you, {Name}?" |
| 0.40 - 0.55 | MEDIUM | Show "Is this you, {Name}?" |
| ≥ 0.55 | NO MATCH | New Customer Flow |

**If user confirms YES:** Load Profile → Personalized Experience
**If user says NO:** New Customer Flow

---

## 10. Deployment Guide

### Deployment Architecture

**Developer Machine:**
- Source Code → Docker Build → Container Image (~350MB)

**Snowflake Registry:**
- Python 3.10
- FastAPI
- ML Models
- React Build

**Snowflake Account:**
- Compute Pool containing SPCS Service (1-5 instances)
- Endpoints: /, /demo, /admin, /api/*
- Storage: Database, Vector Index, Tables
- Cortex: Agent, Search, Analyst
- Config: Stage, retailer.json, logo.png

**Access Points:**
- End Customer → /demo
- Admin User → /admin
- Demo Presenter → /demo + /admin

### Deployment Steps

**Step 1: Infrastructure**
1. Create Database
2. Create Tables
3. Create Vector Index
4. Create Search Services

**Step 2: Container**
1. Build Docker Image
2. Push to Registry
3. Create Compute Pool
4. Deploy Service

**Step 3: Data**
1. Load Sample Products
2. Run Label Extraction
3. Load Sample Reviews

**Step 4: Configure**
1. Set Retailer Name
2. Set Brand Colors
3. Upload Logo
4. ✓ DONE!

### SQL Execution Order

```bash
# 1. Infrastructure
snowsql -f sql/01_setup_database.sql
snowsql -f sql/02_create_tables.sql

# 2. Cortex Services
snowsql -f sql/03_create_cortex_services.sql
snowsql -f sql/04_create_semantic_views.sql

# 3. UDFs & SPCS
snowsql -f sql/05_create_udfs.sql
snowsql -f sql/06_create_spcs_service.sql

# 4. Sample Data & Tasks
snowsql -f sql/07_sample_data.sql
snowsql -f sql/08_label_extraction_task.sql
```

### Docker Build Commands

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
| / | Widget standalone view |
| /demo | Mock retailer website + embedded widget |
| /admin | Admin configuration panel |
| /api/* | Backend API endpoints |
| /widget.js | Embeddable script for external sites |

---

## Implementation Notes

### External Data Sources

| Data | Best Source |
|------|-------------|
| Influencer profile + audience demographics | Viral Nation, CreatorIQ, or HypeAuditor (external API) |
| Influencer skin tone/type/undertone | Manual curation or AI extraction from bio |
| Social mentions + posts | Bright Data (Snowflake Marketplace) |

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
| /api/health | GET | Health check |
| /api/chat | POST | Main agent conversation |
| /api/analyze | POST | Face analysis only |
| /api/identify | POST | Face recognition only |
| /api/match/{category} | POST | Product matching |

---

*Document Version: 2.0*
*Last Updated: December 2024*

---

## How to Use This Document in Google Docs

1. **Copy this entire document** and paste into Google Docs
2. **Format headers:** Select each section header and apply Heading 1, 2, or 3 styles
3. **Create tables:** For each table, use Insert → Table and manually format
4. **Add diagrams:** Replace [DIAGRAM] placeholders with Google Drawings or imported images
5. **Apply branding:** Update fonts and colors to match your organization's style

**Suggested Google Docs Formatting:**
- Title: 24pt, Bold
- Heading 1: 18pt, Bold
- Heading 2: 14pt, Bold
- Body: 11pt, Normal
- Code blocks: Use Courier New font with light gray background

