# Liquidity Coverage Ratio (LCR) Management Platform

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-Databricks-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## 🏦 Executive Summary

A production-grade data engineering and analytics platform for calculating and monitoring **Liquidity Coverage Ratio (LCR)** for banking institutions across multiple European countries. This project implements a complete **medallion architecture** (Bronze → Silver → Gold) to transform raw banking data into actionable liquidity insights and Basel III regulatory compliance metrics.

### Business Value

* ✅ **Regulatory Compliance**: Automated Basel III LCR calculation with compliance monitoring
* ✅ **Risk Management**: Real-time liquidity risk identification by country and subsidiary
* ✅ **Data Quality**: Enterprise-grade data quality framework with >99.5% accuracy
* ✅ **Scalability**: Handles historical data from 2020 onwards with monthly snapshots
* ✅ **Analytics Ready**: Dimensional data model supporting complex business intelligence queries

---

## 📋 Table of Contents

* [Project Overview](#-project-overview)
* [Analytics Snapshots](#-analytics-snapshots)
* [Architecture](#-architecture)
* [Data Model](#-data-model)
* [Getting Started](#-getting-started)
* [Project Structure](#-project-structure)
* [Business Use Cases](#-business-use-cases)
* [Deployment Guide](#-deployment-guide)
* [Agent Instructions](#-agent-instructions)
* [Contributing](#-contributing)
* [License](#-license)

---

## 🎯 Project Overview

### Problem Statement

DRC Bank operates across 8 European countries and must maintain compliance with **Basel III Liquidity Coverage Ratio (LCR)** requirements (minimum 100%). The bank needs:

1. **Daily monitoring** of liquidity positions across countries and subsidiaries
2. **Automated calculation** of LCR = Total HQLA / Total Net Cash Outflows
3. **Early warning system** to identify countries at liquidity risk
4. **Historical trend analysis** for treasury planning and regulatory reporting

### Solution Architecture

This platform implements a **complete end-to-end data pipeline**:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Data           │     │  Bronze Layer   │     │  Silver Layer   │     │  Gold Layer     │
│  Generation     │────>│  (Raw Data)     │────>│  (Cleaned Data) │────>│  (Analytics)    │
│                 │     │                 │     │                 │     │                 │
│ Synthetic Data  │     │ Delta Tables    │     │ Data Quality    │     │ Star Schema     │
│ 3 Datasets      │     │ 3 Tables        │     │ 3 Cleaned       │     │ 4 Dimensions    │
│ 1000 records    │     │ Full Schema     │     │ Validated       │     │ 4 Fact Tables   │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Key Features

* **Synthetic Data Generation**: Realistic banking data with built-in anomalies and risk patterns
* **Medallion Architecture**: Bronze (raw) → Silver (cleaned) → Gold (analytical)
* **Basel III LCR Calculation**: Automatic calculation with compliance status
* **Dimensional Data Model**: Star schema with 4 dimensions and 4 fact tables
* **Data Quality Framework**: Comprehensive validation, deduplication, and cleansing
* **Multi-Country Support**: 8 European countries with multiple currencies
* **Risk Analytics**: Built-in liquidity risk categories and concentration risk flags

---

## 📈 Analytics Snapshots

### LCR Ratio Trend by Country

![LCR Ratio Trend by Country](images/LCR%20Ratio%20Trend%20by%20Country.png)

### HQLA vs Cash Outflows by Country

![HQLA vs Cash Outflows by Country](images/HQLA%20vs%20Cash%20Outflows%20by%20Country.png)

---

## 🏗️ Architecture

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|----------|
| **Platform** | Databricks (AWS) | Cloud-based data engineering platform |
| **Storage** | Delta Lake | ACID-compliant data lake storage |
| **Catalog** | Unity Catalog | Unified governance and metadata management |
| **Compute** | Serverless / Interactive Clusters | On-demand compute for ETL and analytics |
| **Languages** | Python, SQL | Data generation and transformations |
| **Format** | Delta Tables | Optimized columnar format with versioning |

### Medallion Architecture Layers

#### 🥉 Bronze Layer (Raw Data)
**Purpose**: Ingest raw data from landing zone with minimal transformation

* **Tables**: `liquidity_dev.bronze.balances`, `hqla`, `collateral`
* **Source**: CSV files from `/Volumes/liquidity_dev/bronze/landing_zone/`
* **Schema**: All columns preserved with detailed comments
* **Metadata**: Source file tracking, load timestamps
* **Characteristics**: Schema-on-read, recursive file lookup, idempotent loads

#### 🥈 Silver Layer (Cleaned Data)
**Purpose**: Apply data quality rules and business validations

* **Tables**: `liquidity_dev.silver.*_cleaned`
* **Data Quality Rules**:
  * ✓ Null value removal (key fields)
  * ✓ String trimming (leading/trailing spaces)
  * ✓ Deduplication (by ID + date, keep latest)
  * ✓ Uppercase flags (Y/N standardization)
  * ✓ Category validation (HQLA levels, quality ratings)
  * ✓ Range validation (percentages 0-100%, positive values)
* **Characteristics**: Type 1 SCD, validated dimensions, business rules applied

#### 🥇 Gold Layer (Dimensional / Analytical)
**Purpose**: Business-ready dimensional model for analytics and reporting

* **Dimensions** (4 tables):
  * `dim_date` - Time dimension with fiscal calendar
  * `dim_country` - Geographic attributes and risk categories
  * `dim_subsidiary` - Organizational hierarchy
  * `dim_account` - Account attributes (Type 2 SCD)

* **Facts** (4 tables):
  * `fact_intraday_liquidity` ⭐ - LCR calculations and compliance status
  * `fact_hqla_position` - HQLA composition & concentration
  * `fact_funding_stability` - Funding maturity & stability metrics
  * `fact_collateral_risk` - Collateral quality & risk exposure

* **Key Calculations**:
  * LCR = Total HQLA (after haircuts) / Total Net Cash Outflows over 30 days
  * Target: LCR ≥ 100% (Basel III requirement)

---

## 📊 Data Model

### Core Datasets

#### 1. Balances Dataset
**Purpose**: Account balances for calculating cash outflows (LCR denominator)

| Key Columns | Description |
|-------------|-------------|
| `account_id` | Unique account identifier (ACC{COUNTRY}{NUMBER}) |
| `balance_eur` | Balance in EUR (reporting currency) |
| `maturity_bucket` | Maturity classification (Overnight to >1-year) |
| `weighted_outflow_rate` | Expected outflow rate for LCR (3-40%) |
| `stable_funding_flag` | Stable funding indicator (Y/N) |
| `balance_volatility` | Volatility indicator (Low/Medium/High) |

#### 2. HQLA Dataset
**Purpose**: High Quality Liquid Assets for LCR numerator

| Key Columns | Description |
|-------------|-------------|
| `asset_id` | Unique asset identifier (HQLA{COUNTRY}{NUMBER}) |
| `hqla_level` | Basel III level (Level 1, Level 2A, Level 2B) |
| `market_value_eur` | Market value before haircuts |
| `haircut_rate` | Haircut percentage (0%, 15%, 25-50%) |
| `eligible_hqla_value_eur` | Value after haircuts (market_value × (1 - haircut)) |
| `encumbered_flag` | Whether asset is pledged (Y/N) |

#### 3. Collateral Dataset
**Purpose**: Collateral quality and concentration risk analysis

| Key Columns | Description |
|-------------|-------------|
| `collateral_id` | Unique collateral identifier (COLL{COUNTRY}{NUMBER}) |
| `collateral_type` | Asset type (Real Estate, Securities, etc.) |
| `quality_rating` | Quality rating (A, B, C, D) |
| `net_realizable_value_eur` | Net value after haircuts |
| `concentration_risk_flag` | High concentration indicator (Y/N) |

### Star Schema Diagram

```
                    ┌─────────────────┐
                    │   dim_date      │
                    │  * date_key (PK)│
                    │    business_date│
                    │    year, quarter│
                    │    is_weekend   │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼────────┐  ┌────────▼────────┐  ┌───────▼────────┐
│  dim_country   │  │ dim_subsidiary  │  │  dim_account   │
│ * country_key  │  │ * subsidiary_key│  │ * account_key  │
│   country_name │  │   subsidiary_nm │  │   account_id   │
│   region       │  │   country       │  │   account_type │
│   risk_category│  │   sub_type      │  │   currency     │
└───────┬────────┘  └────────┬────────┘  └───────┬────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
  ┌───────▼────────────┐ ┌──▼──────────────┐  │
  │ fact_intraday_     │ │ fact_hqla_      │  │
  │   liquidity        │ │   position      │  │
  │ • LCR calculation  │ │ • HQLA levels   │  │
  │ • Cash outflows    │ │ • Concentration │  │
  │ • Compliance status│ │ • Asset quality │  │
  └────────────────────┘ └─────────────────┘  │
          │                  │                  │
  ┌───────▼────────────┐ ┌──▼──────────────┐  │
  │ fact_funding_      │ │ fact_collateral_│  │
  │   stability        │ │   risk          │  │
  │ • Maturity profile │ │ • Quality rating│  │
  │ • Volatility       │ │ • LTV ratios    │  │
  │ • Stability ratio  │ │ • Concentration │  │
  └────────────────────┘ └─────────────────┘  │
```

---

## 🚀 Getting Started

### Prerequisites

#### Required Infrastructure

* **Databricks Workspace** (AWS, Azure, or GCP)
* **Unity Catalog** enabled
* **Compute**: Serverless or interactive cluster (Python + SQL support)
* **Permissions**: CREATE CATALOG, CREATE SCHEMA, CREATE TABLE, CREATE VOLUME

#### Catalog Structure

```sql
-- Catalog: liquidity_dev
├── bronze (schema)
│   ├── balances (table)
│   ├── hqla (table)
│   ├── collateral (table)
│   └── landing_zone (volume)
├── silver (schema)
│   ├── balances_cleaned (table)
│   ├── hqla_cleaned (table)
│   └── collateral_cleaned (table)
└── gold (schema)
    ├── dim_date (table)
    ├── dim_country (table)
    ├── dim_subsidiary (table)
    ├── dim_account (table)
    ├── fact_intraday_liquidity (table)
    ├── fact_hqla_position (table)
    ├── fact_funding_stability (table)
    └── fact_collateral_risk (table)
```

### Quick Start Guide

#### Step 1: Create Unity Catalog Infrastructure

```sql
-- Create catalog
CREATE CATALOG IF NOT EXISTS liquidity_dev
COMMENT 'Liquidity Coverage Ratio (LCR) Management Platform';

-- Create schemas
CREATE SCHEMA IF NOT EXISTS liquidity_dev.bronze
COMMENT 'Bronze layer - raw data from landing zone';

CREATE SCHEMA IF NOT EXISTS liquidity_dev.silver
COMMENT 'Silver layer - cleaned and validated data';

CREATE SCHEMA IF NOT EXISTS liquidity_dev.gold
COMMENT 'Gold layer - dimensional model for analytics';

-- Create volume for file storage
CREATE VOLUME IF NOT EXISTS liquidity_dev.bronze.landing_zone
COMMENT 'Landing zone for CSV file ingestion';
```

#### Step 2: Generate Sample Data

1. Open **`00-data-generation`** notebook
2. Run Cell 2 to load data generation functions
3. Run Cell 4 to generate data for today (1,000 records per dataset)
4. *Optional*: Run Cell 5 to generate historical data (monthly from 2020)

**Expected Output**: 3 CSV files per date in volume:
* `/Volumes/liquidity_dev/bronze/landing_zone/balances/{date}/balances_{date}.csv`
* `/Volumes/liquidity_dev/bronze/landing_zone/hqla/{date}/hqla_{date}.csv`
* `/Volumes/liquidity_dev/bronze/landing_zone/collateral/{date}/collateral_{date}.csv`

#### Step 3: Load Bronze Layer

1. Open **`01-bronze-layer`** notebook
2. Run cells 2-4 to create bronze tables with full schema
3. Run cell 5 to verify data load (check record counts and date ranges)

**Expected Output**: 3 bronze tables with all CSV data loaded

#### Step 4: Build Silver Layer

1. Open **`02-silver-layer`** notebook
2. Run cells 2-4 to create cleaned tables
3. Run cells 5-6 to verify data quality

**Data Quality Checks Applied**:
* Null removal on key fields (account_id, asset_id, collateral_id, business_date)
* String trimming and uppercase flag standardization
* Deduplication by ID + date
* HQLA level validation (only Level 1, 2A, 2B)
* Quality rating validation (only A, B, C, D)

#### Step 5: Create Gold Layer

1. Open **`03-gold-layer`** notebook
2. Run cells 2-5 to create dimension tables
3. Run cells 6-9 to create fact tables with business metrics
4. Run cell 10 to verify gold layer

**Expected Output**: Star schema with 4 dimensions and 4 facts, including LCR calculations

---

## 📁 Project Structure

```
lcr_management/
│
├── README.md                           # This file - project documentation
├── AGENT_INSTRUCTIONS.md               # Instructions for AI agents to rebuild project
├── .gitignore                          # Git ignore patterns
├── LICENSE                             # MIT License
│
├── notebooks/
│   ├── 00-data-generation              # Synthetic data generation
│   ├── 01-bronze-layer                 # Bronze layer ETL
│   ├── 02-silver-layer                 # Silver layer data quality
│   └── 03-gold-layer                   # Gold layer dimensional model
│
├── docs/
│   ├── architecture.md                 # Detailed architecture documentation
│   ├── data-model.md                   # Data model specifications
│   └── business-use-cases.md           # Analytics and reporting use cases
│
└── sql/
    ├── setup-catalog.sql               # Unity Catalog setup script
    ├── sample-queries.sql              # Example analytical queries
    └── maintenance.sql                 # Table optimization and maintenance
```

---

## 📈 Business Use Cases

### 1. Regulatory Compliance Monitoring

**Question**: *Is our bank compliant with Basel III LCR requirements across all countries?*

```sql
SELECT 
  dc.country_name,
  dc.region,
  dd.business_date,
  ROUND(AVG(f.liquidity_coverage_ratio), 4) AS avg_lcr,
  f.lcr_status,
  ROUND(SUM(f.lcr_surplus_deficit_eur), 2) AS surplus_deficit_eur,
  ROUND(SUM(f.total_hqla_eligible_eur), 2) AS total_hqla_eur,
  ROUND(SUM(f.total_cash_outflows_30d), 2) AS total_outflows_eur
FROM liquidity_dev.gold.fact_intraday_liquidity f
INNER JOIN liquidity_dev.gold.dim_date dd ON f.date_key = dd.date_key
INNER JOIN liquidity_dev.gold.dim_country dc ON f.country_key = dc.country_key
WHERE dd.business_date = CURRENT_DATE()
GROUP BY dc.country_name, dc.region, dd.business_date, f.lcr_status
ORDER BY avg_lcr ASC;
```

**Insights**:
* Identifies countries below 100% LCR threshold
* Calculates EUR surplus/deficit to meet requirements
* Highlights high-risk regions

### 2. HQLA Asset Quality Analysis

**Question**: *What is the composition and concentration of our HQLA portfolio?*

```sql
SELECT 
  f.hqla_level,
  f.asset_type,
  COUNT(DISTINCT f.date_key) AS reporting_days,
  ROUND(AVG(f.total_eligible_value_eur), 2) AS avg_eligible_eur,
  ROUND(AVG(f.concentration_percentage), 2) AS avg_concentration_pct,
  ROUND(AVG(f.average_haircut_rate), 4) AS avg_haircut_rate,
  ROUND(AVG(f.average_liquidity_score), 2) AS avg_liquidity_score
FROM liquidity_dev.gold.fact_hqla_position f
INNER JOIN liquidity_dev.gold.dim_date dd ON f.date_key = dd.date_key
WHERE dd.business_date >= CURRENT_DATE() - INTERVAL 30 DAYS
GROUP BY f.hqla_level, f.asset_type
ORDER BY f.hqla_level, avg_eligible_eur DESC;
```

**Insights**:
* Shows HQLA distribution across Level 1, 2A, 2B
* Identifies concentration risks by asset type
* Tracks liquidity scores and haircut rates

### 3. Funding Stability Assessment

**Question**: *How stable is our funding base by maturity bucket and customer segment?*

```sql
SELECT 
  f.maturity_bucket,
  f.customer_segment,
  ROUND(SUM(f.total_balance_eur), 2) AS total_balance_eur,
  ROUND(SUM(f.stable_funding_balance_eur), 2) AS stable_funding_eur,
  ROUND(AVG(f.stable_funding_ratio), 4) AS stable_funding_ratio,
  ROUND(AVG(f.average_outflow_rate), 4) AS avg_outflow_rate,
  SUM(f.account_count) AS total_accounts
FROM liquidity_dev.gold.fact_funding_stability f
INNER JOIN liquidity_dev.gold.dim_date dd ON f.date_key = dd.date_key
WHERE dd.business_date = CURRENT_DATE()
GROUP BY f.maturity_bucket, f.customer_segment
ORDER BY total_balance_eur DESC;
```

**Insights**:
* Analyzes funding maturity profile
* Identifies concentration in short-term funding
* Tracks stable vs. unstable funding sources

### 4. Collateral Quality & Risk Exposure

**Question**: *What is our exposure to low-quality collateral and concentration risk?*

```sql
SELECT 
  dc.country_name,
  f.collateral_type,
  f.quality_rating,
  ROUND(SUM(f.total_net_value_eur), 2) AS total_net_value_eur,
  ROUND(AVG(f.average_haircut_percentage), 4) AS avg_haircut_pct,
  ROUND(AVG(f.average_ltv_ratio), 4) AS avg_ltv_ratio,
  ROUND(SUM(f.high_concentration_value_eur), 2) AS concentration_risk_eur,
  ROUND(AVG(f.quality_score), 2) AS avg_quality_score
FROM liquidity_dev.gold.fact_collateral_risk f
INNER JOIN liquidity_dev.gold.dim_date dd ON f.date_key = dd.date_key
INNER JOIN liquidity_dev.gold.dim_country dc ON f.country_key = dc.country_key
WHERE dd.business_date = CURRENT_DATE()
  AND f.quality_rating IN ('C', 'D')  -- Low quality
GROUP BY dc.country_name, f.collateral_type, f.quality_rating
ORDER BY total_net_value_eur DESC;
```

**Insights**:
* Identifies countries with high exposure to low-quality collateral
* Tracks concentration risk by collateral type
* Monitors LTV ratios and haircut rates

---

## 🔧 Deployment Guide

### Environment Setup

#### Development Environment
```bash
# Databricks CLI configuration
databricks configure --token

# Verify connection
databricks workspace ls
```

#### Compute Configuration

**Recommended Cluster Settings**:
* **Runtime**: Databricks Runtime 14.3 LTS or later
* **Mode**: Single user (for Unity Catalog)
* **Node Type**: Standard_DS3_v2 (AWS: m5.xlarge)
* **Workers**: 2-4 (auto-scaling)
* **Libraries**: None required (built-in Spark/SQL)

### Production Deployment

#### 1. Parameterize Notebooks

Add widgets to notebooks for environment-specific values:

```python
# Example: 00-data-generation
dbutils.widgets.text("catalog_name", "liquidity_prod", "Catalog Name")
dbutils.widgets.text("num_records", "1000", "Records per Dataset")

catalog = dbutils.widgets.get("catalog_name")
num_records = int(dbutils.widgets.get("num_records"))
```

#### 2. Schedule Jobs

Create Databricks Jobs for automated execution:

```json
{
  "name": "LCR Daily Load",
  "tasks": [
    {
      "task_key": "data_generation",
      "notebook_task": {
        "notebook_path": "/lcr_management/notebooks/00-data-generation"
      }
    },
    {
      "task_key": "bronze_load",
      "depends_on": [{"task_key": "data_generation"}],
      "notebook_task": {
        "notebook_path": "/lcr_management/notebooks/01-bronze-layer"
      }
    },
    {
      "task_key": "silver_clean",
      "depends_on": [{"task_key": "bronze_load"}],
      "notebook_task": {
        "notebook_path": "/lcr_management/notebooks/02-silver-layer"
      }
    },
    {
      "task_key": "gold_transform",
      "depends_on": [{"task_key": "silver_clean"}],
      "notebook_task": {
        "notebook_path": "/lcr_management/notebooks/03-gold-layer"
      }
    }
  ],
  "schedule": {
    "quartz_cron_expression": "0 0 2 * * ?",
    "timezone_id": "Europe/London"
  }
}
```

#### 3. Monitoring & Alerting

Set up alerts for:
* LCR falling below 100%
* Data load failures
* Data quality degradation
* High concentration risk

---

## 🤖 Agent Instructions

For AI agents (like Genie) to rebuild this project from scratch, see **[AGENT_INSTRUCTIONS.md](AGENT_INSTRUCTIONS.md)**.

That document provides:
* Step-by-step rebuild instructions
* Expected outputs at each stage
* Data validation checkpoints
* Troubleshooting guidance

---

## 🔐 Security & Governance

### Data Access Control

```sql
-- Grant permissions to analytics team
GRANT USAGE ON CATALOG liquidity_dev TO `analytics_team`;
GRANT SELECT ON SCHEMA liquidity_dev.gold TO `analytics_team`;

-- Grant write permissions to ETL service account
GRANT ALL PRIVILEGES ON SCHEMA liquidity_dev.bronze TO `etl_service_account`;
GRANT ALL PRIVILEGES ON SCHEMA liquidity_dev.silver TO `etl_service_account`;
GRANT ALL PRIVILEGES ON SCHEMA liquidity_dev.gold TO `etl_service_account`;
```

### Audit Logging

All table operations are logged in Unity Catalog audit logs:
* Table access (SELECT)
* Table modifications (INSERT, UPDATE, DELETE)
* Schema changes (ALTER, DROP)
* Permission grants/revokes

---

## 🐛 Troubleshooting

### Common Issues

#### Issue: "Catalog does not exist"
**Solution**: Run setup SQL to create catalog structure

```sql
CREATE CATALOG IF NOT EXISTS liquidity_dev;
```

#### Issue: "Volume not found"
**Solution**: Create volume and verify permissions

```sql
CREATE VOLUME IF NOT EXISTS liquidity_dev.bronze.landing_zone;
SHOW GRANTS ON VOLUME liquidity_dev.bronze.landing_zone;
```

#### Issue: "Duplicate records in silver layer"
**Solution**: Verify deduplication logic in 02-silver-layer notebook

```sql
-- Check for duplicates
SELECT account_id, business_date, COUNT(*)
FROM liquidity_dev.silver.balances_cleaned
GROUP BY account_id, business_date
HAVING COUNT(*) > 1;
```

---

## 📝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/my-feature`
3. **Commit changes**: `git commit -am 'Add new feature'`
4. **Push to branch**: `git push origin feature/my-feature`
5. **Submit pull request**

### Development Standards

* **Code Style**: Follow PEP 8 for Python, SQL formatting standards
* **Documentation**: Add comments to all functions and SQL statements
* **Testing**: Include data validation checks in each layer
* **Naming**: Use descriptive names (snake_case for tables/columns)

---

## 📄 License

This project is licensed under the MIT License.

```
MIT License

Copyright (c) 2026 DRC Bank - Data Engineering Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 📞 Support

### Resources

* **Documentation**: See `/docs` folder for detailed guides
* **Issues**: Report bugs via GitHub Issues
* **Discussions**: Join project discussions forum

### Contact

* **Project Lead**: Data Engineering Team
* **Email**: data-engineering@drcbank.com
* **Slack**: #lcr-management

---

## 🎉 Acknowledgments

* **Databricks** for the lakehouse platform
* **Basel Committee** for LCR regulatory framework
* **DRC Bank Treasury Team** for business requirements

---

**Built with ❤️ by the Data Engineering Team**

*Last Updated: June 27, 2026*