# Liquidity Coverage Ratio (LCR) Management Platform

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-Databricks-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

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
│   ├── 01_bronze_layer.sql
│   ├── 02_silver_layer.sql
│   └── 03_gold_layer.sql
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
