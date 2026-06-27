# Liquidity Coverage Ratio (LCR) Management Platform

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)

## Intro

A Databricks lakehouse project for calculating and monitoring Liquidity Coverage Ratio (LCR) across European banking entities. The platform uses a medallion architecture to turn raw balances, HQLA, and collateral data into analytics-ready gold tables for Basel III liquidity reporting.

The core LCR calculation is:

```text
LCR = Total HQLA after haircuts / Total net cash outflows over 30 days
Basel III target: LCR >= 100%
```

## Analytics Snapshots

### LCR Ratio Trend by Country

![LCR Ratio Trend by Country](images/LCR%20Ratio%20Trend%20by%20Country.png)

### HQLA vs Cash Outflows by Country

![HQLA vs Cash Outflows by Country](images/HQLA%20vs%20Cash%20Outflows%20by%20Country.png)

## Project Structure

```text
lcr-management/
├── README.md
├── AGENT_INSTRUCTIONS.md
├── SETUP.md
├── PROJECT_STRUCTURE.md
├── QUICK_START.md
├── requirements.txt
├── LICENSE
├── LICENSE.py
├── images/
│   ├── HQLA vs Cash Outflows by Country.png
│   └── LCR Ratio Trend by Country.png
├── sql/
│   ├── 00_setup.sql
│   ├── bronze/
│   │   ├── 01_create_balances.sql
│   │   ├── 02_insert_balances.sql
│   │   ├── 03_create_hqla.sql
│   │   ├── 04_insert_hqla.sql
│   │   ├── 05_create_collateral.sql
│   │   ├── 06_insert_collateral.sql
│   │   ├── 07_verify_bronze_summary.sql
│   │   └── 08_describe_balances.sql
│   ├── silver/
│   │   ├── 01_create_balances_cleaned.sql
│   │   ├── 02_insert_balances_cleaned.sql
│   │   ├── 03_create_hqla_cleaned.sql
│   │   ├── 04_insert_hqla_cleaned.sql
│   │   ├── 05_create_collateral_cleaned.sql
│   │   ├── 06_insert_collateral_cleaned.sql
│   │   ├── 07_verify_silver_summary.sql
│   │   └── 08_validate_silver_quality.sql
│   └── gold/
│       ├── 01_create_dim_date.sql
│       ├── 02_insert_dim_date.sql
│       ├── 03_create_dim_country.sql
│       ├── 04_insert_dim_country.sql
│       ├── 05_create_dim_subsidiary.sql
│       ├── 06_insert_dim_subsidiary.sql
│       ├── 07_create_dim_account.sql
│       ├── 08_insert_dim_account.sql
│       ├── 09_create_fact_intraday_liquidity.sql
│       ├── 10_insert_fact_intraday_liquidity.sql
│       ├── 11_create_fact_hqla_position.sql
│       ├── 12_insert_fact_hqla_position.sql
│       ├── 13_create_fact_funding_stability.sql
│       ├── 14_insert_fact_funding_stability.sql
│       ├── 15_create_fact_collateral_risk.sql
│       ├── 16_insert_fact_collateral_risk.sql
│       └── 17_verify_gold_summary.sql
└── src/
    ├── data_generation.py
    └── run_pipeline.py
```

## Star Schema Diagram

```text
                    ┌─────────────────┐
                    │   dim_date      │
                    │  * date_key     │
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
  │ * LCR calculation  │ │ * HQLA levels   │  │
  │ * Cash outflows    │ │ * Concentration │  │
  │ * Compliance status│ │ * Asset quality │  │
  └────────────────────┘ └─────────────────┘  │
          │                  │                  │
  ┌───────▼────────────┐ ┌──▼──────────────┐  │
  │ fact_funding_      │ │ fact_collateral_│  │
  │   stability        │ │   risk          │  │
  │ * Maturity profile │ │ * Quality rating│  │
  │ * Volatility       │ │ * LTV ratios    │  │
  │ * Stability ratio  │ │ * Concentration │  │
  └────────────────────┘ └─────────────────┘  │
```
