# Agent Commerce - Demo Script

> Test all 16 tools available to the Cortex Agent

## Quick Access
```sql
-- Get the widget URL
SHOW ENDPOINTS IN SERVICE UTIL.AGENT_COMMERCE_BACKEND;
```

---

## 🎭 DEMO FLOW: Complete Customer Journey

### Scene 1: Face Analysis & Customer Identification

**Step 1: Upload a selfie** (via widget)

> 📷 Upload a photo of your face

Expected Agent Behavior:
- Agent uses **AnalyzeFace** → Gets skin tone, undertone, Fitzpatrick, Monk shade, embedding
- Agent uses **IdentifyCustomer** → Checks if returning customer
- Widget shows **Skin Analysis Card** with color swatches
- If match found: Widget shows **Customer Match Card** with loyalty info

**Sample prompts to try:**
```
[Upload photo - no text needed, just upload]
```

```
Analyze my face and tell me about my skin tone
```

---

### Scene 2: Product Discovery

**Step 2a: Color-Based Matching**

> "Find me a lipstick that matches my skin tone"

Expected Agent Behavior:
- Agent uses **MatchProducts** with skin_hex from face analysis
- Returns products ranked by color distance (CIEDE2000)
- Widget shows **Product Cards**

**Sample prompts:**
```
What lipsticks would complement my skin tone?
```

```
Find me a foundation that matches my skin
```

```
Show me blushes that would look good on me
```

---

**Step 2b: Semantic Product Search**

> Test **ProductSearch** (Cortex Search)

**Sample prompts:**
```
I'm looking for a vegan mascara
```

```
Do you have any hydrating foundations for dry skin?
```

```
Show me products with hyaluronic acid
```

```
I want a red lipstick for warm undertones
```

---

**Step 2c: Structured Product Queries**

> Test **ProductAnalyst** (Cortex Analyst)

**Sample prompts:**
```
What is the price of the NARS Orgasm blush?
```

```
Show me all foundations under $40
```

```
List all products from Charlotte Tilbury
```

```
What are the top 5 best-selling lipsticks?
```

---

### Scene 3: Social Proof & Reviews

**Step 3a: Review Search**

> Test **SocialSearch** (Cortex Search)

**Sample prompts:**
```
What do people say about the Fenty Beauty foundation?
```

```
Show me reviews mentioning oily skin
```

```
What products do influencers recommend for dry skin?
```

---

**Step 3b: Social Analytics**

> Test **SocialAnalyst** (Cortex Analyst)

**Sample prompts:**
```
What is the average rating for MAC lipsticks?
```

```
Which products have the most 5-star reviews?
```

```
Show me trending products this week
```

---

### Scene 4: Customer & Loyalty

**Step 4: Customer Profile**

> Test **CustomerAnalyst** (Cortex Analyst)

**Sample prompts:**
```
What is my loyalty status?
```

```
How many points do I have?
```

```
Show me my purchase history
```

```
What products have I bought before?
```

---

### Scene 5: Inventory Check

**Step 5: Stock Availability**

> Test **InventoryAnalyst** (Cortex Analyst)

**Sample prompts:**
```
Is the NARS Orgasm blush in stock?
```

```
Which stores have the Fenty Beauty foundation available?
```

```
What's the stock level for MAC Ruby Woo lipstick?
```

---

### Scene 6: Full Checkout Flow (ACP)

**Step 6: Shopping Cart & Checkout**

> Test all 6 ACP Cart Tools

**6a. Create Cart** → **ACP_CreateCart**
```
I'd like to start shopping
```

**6b. Add Items** → **ACP_AddItem**
```
Add the Fenty Beauty Pro Filt'r foundation to my cart
```

```
Add 2 of the MAC Ruby Woo lipsticks
```

**6c. View Cart** → **ACP_GetCart**
```
What's in my cart?
```

```
Show me my cart
```

**6d. Update Quantity** → **ACP_UpdateItem**
```
Change the lipstick quantity to 3
```

**6e. Remove Item** → **ACP_RemoveItem**
```
Remove the foundation from my cart
```

**6f. Checkout** → **ACP_Checkout**
```
I'm ready to checkout
```

```
Complete my order
```

---

## 🧪 TOOL-BY-TOOL TESTING CHECKLIST

### Beauty Analysis Tools (3)

| Tool | Test Prompt | Expected Output |
|------|-------------|-----------------|
| **AnalyzeFace** | [Upload photo] | Skin hex, lip hex, undertone, Fitzpatrick, Monk, embedding |
| **IdentifyCustomer** | [After photo upload] | Customer name, loyalty tier, confidence % |
| **MatchProducts** | "Find lipsticks for my skin tone" | Products with color distance scores |

### Cortex Search Tools (2)

| Tool | Test Prompt | Expected Output |
|------|-------------|-----------------|
| **ProductSearch** | "Vegan mascara" | Relevant products with descriptions |
| **SocialSearch** | "Reviews for oily skin" | Reviews mentioning oily skin |

### Cortex Analyst Tools (5)

| Tool | Test Prompt | Expected Output |
|------|-------------|-----------------|
| **CustomerAnalyst** | "What's my loyalty tier?" | Customer profile data |
| **ProductAnalyst** | "Price of NARS blush" | Specific product data |
| **InventoryAnalyst** | "Is Ruby Woo in stock?" | Stock levels by location |
| **SocialAnalyst** | "Average rating for MAC" | Aggregated review stats |
| **CheckoutAnalyst** | "Show my order history" | Past orders |

### ACP Cart Tools (6)

| Tool | Test Prompt | Expected Output |
|------|-------------|-----------------|
| **ACP_CreateCart** | "Start shopping" | Session ID created |
| **ACP_AddItem** | "Add foundation to cart" | Item added confirmation |
| **ACP_GetCart** | "Show my cart" | Cart items with totals |
| **ACP_UpdateItem** | "Change quantity to 3" | Updated confirmation |
| **ACP_RemoveItem** | "Remove lipstick" | Removed confirmation |
| **ACP_Checkout** | "Complete my order" | Order number, total |

---

## 🎬 3-MINUTE DEMO SCRIPT

### Opening (30 sec)
"This is our AI Commerce Assistant, powered by Snowflake Cortex Agent. It can analyze your skin, identify returning customers, recommend products, and complete checkout - all through natural conversation."

### Face Analysis (45 sec)
1. Click widget → Upload selfie
2. "Look - it analyzed my skin tone (#DC9E83), detected warm undertones, and classified me as Monk Shade 4"
3. "And it recognized me as a returning Gold member with 2,500 loyalty points!"

### Product Recommendations (45 sec)
1. "Find me a lipstick that matches my skin"
2. "Notice how it uses scientific color matching - these products are ranked by how well they complement my exact skin tone"
3. "Let me also check reviews - 'What do people say about this foundation?'"

### Checkout (45 sec)
1. "Add the first lipstick to my cart"
2. "Show me my cart" 
3. "Complete my order"
4. "Done! Order confirmed with order number."

### Closing (15 sec)
"All of this runs on Snowflake - Cortex Agent orchestrates 16 tools including face recognition, semantic search, and ACID-compliant checkout using Hybrid Tables."

---

## 🔧 TROUBLESHOOTING

### Agent not responding?
```sql
-- Check if agent exists
SHOW AGENTS IN SCHEMA UTIL;

-- Check service status
SHOW SERVICES IN COMPUTE POOL AGENT_COMMERCE_POOL;
```

### Face analysis failing?
- Ensure image is clear, well-lit
- Face should be fully visible
- Max image size: 5MB

### Cart operations failing?
```sql
-- Check Hybrid Tables
SELECT * FROM CART_OLTP.CART_SESSIONS LIMIT 5;
SELECT * FROM CART_OLTP.CART_ITEMS LIMIT 5;
```

### No products found?
```sql
-- Check product data
SELECT COUNT(*) FROM PRODUCTS.PRODUCTS;
SELECT * FROM PRODUCTS.PRODUCTS LIMIT 5;
```

---

## 📊 METRICS TO HIGHLIGHT

- **Response Time**: Typically 2-5 seconds per query
- **Tools Available**: 16 specialized tools
- **Face Analysis**: 128-dimensional embedding
- **Color Matching**: CIEDE2000 perceptual distance
- **Checkout**: ACID transactions via Hybrid Tables

---

*Last Updated: January 2026*

