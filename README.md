# Snowflake Agent Commerce

> AI-Powered Commerce Assistant with Face Recognition, Skin Analysis, Product Matching, and ACP-Compliant Checkout
> 
> Powered by Snowflake Cortex Agent + Snowpark Container Services

## Overview

> A fully agentic shopping experience where a Cortex Agent orchestrates 16 tools — from customer identification to product discovery to checkout — demonstrating Snowflake as an end-to-end AI commerce platform with open API interoperability.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      SNOWFLAKE AGENT COMMERCE                                │
└─────────────────────────────────────────────────────────────────────────────┘

     📱 Any Frontend                    🤖 Cortex Agent                    ❄️ Snowflake
    ─────────────────                  ─────────────────                  ─────────────────
    
    ┌─────────────┐                   ┌─────────────────┐                ┌─────────────────┐
    │ Web App     │                   │                 │                │ Image           │
    │ Mobile App  │    REST API       │   Orchestrates  │    16 Tools    │   Vectors       │
    │ Voice Agent │──────────────────▶│   16 Tools      │ ─────────────▶ │ Cortex Search   │
    │ OpenAI SDK  │      MCP          │   Autonomously  │                │ Cortex Analyst  │
    │ Claude      │                   │                 │                │ Hybrid Tables   │
    │             │                   │                 │                │ Model Serving   │
    └─────────────┘                   └─────────────────┘                └─────────────────┘
                                              │
                          ┌───────────────────┼───────────────────┐
                          │                   │                   │
                          ▼                   ▼                   ▼
                    ┌──────────┐        ┌──────────┐        ┌──────────┐
                    │ 🔐 AUTH  │        │ 🎨 DISCO-│        │ 🛒 TRANS-│
                    │          │        │   VER    │        │   ACT    │
                    │ Face     │        │ Search   │        │ ACP Cart │
                    │ Match    │        │ Match    │        │ Checkout │
                    │ Loyalty  │        │ Color    │        │ Orders   │
                    │ History  │        │ Reviews  │        │          │
                    └──────────┘        └──────────┘        └──────────┘
```

### Brief Description

Snowflake Agent Commerce showcases how enterprises can build **agentic commerce experiences entirely within Snowflake** — where an AI agent autonomously handles the complete customer journey from recognition to purchase.

**The Cortex Agent orchestrates:**

- **Customer Intelligence** → Identity recognition, loyalty data, purchase history (Vector Search + Analyst)
- **Product Discovery** → Semantic search, personalized recommendations, inventory checks (Cortex Search + Analyst)
- **Social Proof** → Reviews, influencer mentions, trending products (Cortex Search)
- **Transaction Processing** → Cart management, checkout, order creation (Hybrid Tables with ACID guarantees)

### Why It Matters for Agent Commerce

| | |
|---|---|
| 🤖 **True agentic orchestration** | Agent decides which tools to call, not hardcoded workflows |
| 🛒 **ACP-compliant** | Implements OpenAI's Agentic Commerce Protocol (ACP_CreateCart, ACP_AddItem, ACP_Checkout) |
| ⚡ **Real-time transactions** | Hybrid Tables enable 10-50ms cart operations with row-level locking |
| 🔒 **Data stays in Snowflake** | No external AI calls; customer data never leaves the platform |
| 🧩 **16 tools, one agent** | Analyst, Search, Vector Search, and custom UDFs unified under one orchestrator |

### Interoperability & Integration

| | |
|---|---|
| 🔌 **REST API** | Standard REST API enables any frontend (web, mobile, voice, embeddable widget) or existing commerce platform to invoke the agent |
| 🔗 **MCP & OpenAI SDK Ready** | Deploy as a Model Context Protocol (MCP) server for Claude Desktop, VS Code Copilot, and MCP-compatible clients; also integrates with OpenAI SDK for seamless adoption in existing AI workflows |

### The Vision

**Agent Commerce is the future of retail** — where AI agents act on behalf of customers to browse, compare, and purchase. This demo proves Snowflake can power that entire stack: **data + AI + transactions in one platform**, with open standards for interoperability across the agentic ecosystem.

### Technology Stack

| Component | Technology |
|-----------|------------|
| **AI Brain** | Snowflake Cortex Agent |
| **Frontend** | React.js Chatbot Widget (embeddable) |
| **Backend** | FastAPI (Python) in SPCS |
| **Face Detection** | MediaPipe Face Mesh (468 landmarks) |
| **Face Recognition** | dlib ResNet (128-dim embeddings) |
| **Customer Identification** | Image Vector Embeddings (ANN) |
| **Product/Social Search** | Cortex Search (semantic) |
| **Structured Queries** | Cortex Analyst + Semantic Views |
| **Label Extraction** | AI_EXTRACT |
| **Color Distance** | CIEDE2000 (ΔE00) |
| **Deployment** | Snowpark Container Services (SPCS) |

---

## Salient & Differentiated Capabilities

> **Why this demo stands out:** Snowflake Agent Commerce showcases capabilities that are unique to the Snowflake platform and differentiated from typical commerce demos.

### 🌟 Key Differentiators

#### 1. Visual AI Commerce Experience
Unlike typical chatbots that start with text, this demo leads with **visual AI**:
- **Instant Face Recognition** → Identifies returning customers from a selfie (dlib 128-dim embeddings + Image Vector Embeddings)
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
| Face matching | Image Vector Embeddings |
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
🔍 Identity Check (Image Vector Embeddings → "Are you Sarah?")
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

## Quick Start

```bash
# One-step deployment
export SNOWFLAKE_USER="your_user" && export SNOWFLAKE_PASSWORD="your_pass"
./deploy.sh
```

## Documentation

For detailed architecture, tool catalog, data layer, and deployment guides, see [ARCHITECTURE.md](./ARCHITECTURE.md).

