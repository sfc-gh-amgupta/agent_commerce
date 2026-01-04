# Agent Commerce - Diagrams

This folder contains draw.io diagrams for the Agent Commerce (Beauty Analyzer) architecture documentation.

**Document Version:** 3.0 | **Last Updated:** January 2026

## How to Use These Diagrams

### Option 1: Open in draw.io (diagrams.net)

1. Go to [app.diagrams.net](https://app.diagrams.net)
2. Click **File → Open from → Device**
3. Select any `.drawio` file from this folder
4. Edit as needed and export to your preferred format (PNG, SVG, PDF)

### Option 2: Import into Lucidchart

1. Go to [Lucidchart](https://www.lucidchart.com)
2. Create a new document
3. Click **File → Import**
4. Select "Visio or draw.io"
5. Upload the `.drawio` file

### Option 3: Embed in Google Docs

1. Open the diagram in draw.io
2. Export as PNG or SVG: **File → Export as → PNG/SVG**
3. In Google Docs: **Insert → Image → Upload from computer**

### Option 4: Use draw.io Google Docs Add-on

1. In Google Docs, go to **Extensions → Add-ons → Get add-ons**
2. Search for "diagrams.net" and install
3. Use **Extensions → diagrams.net → New Diagram** to create/edit directly

---

## Diagram List

| File | Description |
|------|-------------|
| `01_system_architecture.drawio` | High-level system architecture showing User Layer, SPCS Container, Cortex Services, and Data Layer |
| `02_tool_hosting_strategy.drawio` | How Cortex Agent connects to different tool types (SPCS, Vector Search, Cortex Search, Analyst, UDFs) |
| `03_request_flow.drawio` | Sequence diagram showing request flow from User → Widget → FastAPI → Cortex Agent → Snowflake |
| `04_conversation_flow.drawio` | State machine showing chatbot conversation flow from welcome to checkout |
| `05_face_recognition_flow.drawio` | Flowchart showing face recognition pipeline from image input to identity match |
| `06_entity_relationships.drawio` | Entity relationship diagram showing database schema relationships (includes CART_OLTP Hybrid Tables) |
| `07_deployment_architecture.drawio` | Deployment architecture showing build, registry, and Snowflake account structure |
| `08_widget_states.drawio` | Widget state machine showing UI states from collapsed to checkout |
| `09_ciede2000_color_matching.drawio` | CIEDE2000 color distance algorithm explanation with quality thresholds |

---

## Color Coding

All diagrams use consistent color coding:

| Color | Meaning |
|-------|---------|
| 🔵 Blue (`#dae8fc`) | User-facing / Input components |
| 🟢 Green (`#d5e8d4`) | Processing / Success states |
| 🟡 Yellow (`#fff2cc`) | Configuration / Options |
| 🟣 Purple (`#e1d5e7`) | ML / AI Processing |
| 🔴 Red (`#f8cecc`) | Decision points / Checkout |
| ⬜ Gray (`#f5f5f5`) | Containers / Boundaries |

---

## Exporting for Presentations

For high-quality exports:

1. Open in draw.io
2. **File → Export as → PNG**
3. Set **Zoom** to 200% or higher
4. Enable **Transparent Background** if needed
5. Click **Export**

For vector graphics (scalable):
1. **File → Export as → SVG**
2. Use in presentations or web pages

---

## Key Updates in v3.0

- Agent renamed to `AGENTIC_COMMERCE_ASSISTANT`
- Cart tools now use `ACP_` prefix (Agentic Commerce Protocol)
- CART_OLTP schema uses Snowflake Hybrid Tables for ACID transactions
- Admin UI supports no-code customization

---

*Last Updated: January 2026*

