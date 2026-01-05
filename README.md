# Agent Commerce Demo

AI-powered shopping assistant built on Snowflake, featuring:
- **Cortex Agent** - Conversational AI orchestration
- **Face Recognition** - Customer identification via face embeddings
- **Skin Analysis** - Color matching for cosmetics
- **SPCS Backend** - ML inference in Snowpark Container Services

## 🚀 One-Click Deployment

Deploy the entire demo using just Snowsight (no local tools required):

```sql
-- Run this in Snowsight:
-- beauty_analyzer/sql/00_deploy_from_github_complete.sql
```

This single script:
1. Creates database, schemas, warehouse
2. Clones this GitHub repo into Snowflake
3. Loads all sample data (products, customers, inventory, etc.)
4. Pulls Docker image from GitHub Container Registry
5. Starts the SPCS backend service
6. Creates Cortex services

## 📁 Project Structure

```
agent_commerce/
├── beauty_analyzer/
│   ├── sql/                          # SQL deployment scripts
│   │   ├── 00_deploy_from_github_complete.sql  ← ONE-CLICK DEPLOY
│   │   ├── 01_setup_database.sql
│   │   ├── 02_create_tables.sql
│   │   ├── 03_create_semantic_views.sql
│   │   ├── 04_create_cortex_search.sql
│   │   └── 05_create_vector_embedding_proc.sql
│   ├── backend/                      # SPCS backend (FastAPI + dlib)
│   │   ├── app/main.py
│   │   ├── Dockerfile
│   │   └── requirements-final.txt
│   ├── data/generated/               # Sample data
│   │   ├── csv/                      # 24 CSV files
│   │   └── images/                   # Product images
│   ├── sample_images/                # Hero images, face samples
│   └── scripts/                      # Data generation scripts
├── .github/workflows/                # CI/CD for Docker builds
└── README.md
```

## 🗄️ Data Model

| Schema | Tables | Description |
|--------|--------|-------------|
| PRODUCTS | 8 tables | Product catalog, variants, pricing, ingredients |
| CUSTOMERS | 3 tables | Customer profiles, face embeddings, skin analysis |
| INVENTORY | 3 tables | Locations, stock levels, transactions |
| SOCIAL | 3 tables | Reviews, social mentions, influencers |
| CART_OLTP | 7 hybrid tables | Cart, orders, payments (transactional) |

## 🔧 Manual Deployment

If you prefer step-by-step deployment:

1. **Infrastructure**: `sql/01_setup_database.sql`
2. **Tables**: `sql/02_create_tables.sql`
3. **Semantic Views**: `sql/03_create_semantic_views.sql`
4. **Cortex Search**: `sql/04_create_cortex_search.sql`
5. **Vector Search**: `sql/05_create_vector_embedding_proc.sql`
6. **Load Data**: `sql/06_load_sample_data.sql`
7. **Deploy SPCS**: `sql/07b_deploy_from_github.sql`

## 🐳 Docker Image

The backend image is automatically built and pushed to GitHub Container Registry on every push to main:

```
ghcr.io/sfc-gh-amgupta/agent_commerce/agent-commerce-backend:latest
```

## 📊 Sample Data

| Domain | Records |
|--------|---------|
| Products | 2,000 |
| Variants | 8,000 |
| Customers | 2,000 |
| Reviews | 4,000 |
| Orders | 822 |
| **Total** | ~120,000+ |

## 🛠️ Technologies

- **Snowflake Cortex**: Agent, Analyst, Search
- **Snowpark Container Services**: ML inference
- **dlib + MediaPipe**: Face recognition & skin analysis
- **FastAPI**: Backend API
- **React.js**: Frontend widget (coming soon)

## 📝 License

Apache 2.0

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

---

Built with ❄️ Snowflake

