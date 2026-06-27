# Agent Instructions: Building LCR Management Platform

## 🎯 Purpose

This document provides step-by-step instructions for AI agents (such as Databricks Genie, GitHub Copilot, or other code assistants) to **rebuild this entire project from scratch** in any Databricks workspace.

---

## 📚 Prerequisites

### Required Access

* Databricks workspace with Unity Catalog enabled
* Permissions to:
  * CREATE CATALOG
  * CREATE SCHEMA
  * CREATE TABLE
  * CREATE VOLUME
  * CREATE NOTEBOOK

### Required Knowledge

The agent should understand:
* **Databricks SQL** (CREATE TABLE, INSERT, SELECT)
* **Python** (pandas, numpy, datetime)
* **Delta Lake** (CREATE OR REPLACE TABLE pattern)
* **Unity Catalog** (3-level namespace: catalog.schema.table)
* **Medallion Architecture** (Bronze → Silver → Gold)
* **Banking Domain**: LCR, HQLA, Basel III concepts

---

## 🏭 Project Context

### Business Objective

Build a data platform to calculate **Liquidity Coverage Ratio (LCR)** for DRC Bank:

```
LCR = Total HQLA (after haircuts) / Total Net Cash Outflows over 30 days

Basel III Requirement: LCR >= 100%
```

### Architecture Overview

```
Data Generation → Bronze (Raw) → Silver (Cleaned) → Gold (Analytics)
     Python          Delta Tables     Data Quality      Star Schema
```

### Success Criteria

✅ 3 bronze tables with raw data  
✅ 3 silver tables with data quality applied  
✅ 4 dimension tables  
✅ 4 fact tables  
✅ LCR calculated correctly (numerator/denominator)  
✅ Foreign key relationships established  
✅ All tables have meaningful comments  

---

## 🔧 Step-by-Step Build Instructions

### Phase 0: Environment Setup (5 minutes)

#### Task 0.1: Create Unity Catalog Structure

**What to do**: Execute SQL to create catalog, schemas, and volume.

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

**Validation**:
```sql
SHOW SCHEMAS IN liquidity_dev;
SHOW VOLUMES IN liquidity_dev.bronze;
```

Expected: 3 schemas (bronze, silver, gold) and 1 volume (landing_zone)

---

### Phase 1: Data Generation (15 minutes)

#### Task 1.1: Create Data Generation Notebook

**Notebook Name**: `00-data-generation`

**Cell 1** (Markdown): Project description

```markdown
# LCR Data Generation

Generates synthetic banking data for 3 datasets:
1. **Balances**: Account balances for cash outflow calculation
2. **HQLA**: High Quality Liquid Assets for LCR numerator
3. **Collateral**: Collateral quality and risk analysis

Each dataset:
- 1,000 records per date
- 8 European countries
- Multiple currencies (EUR, GBP, CHF, PLN, SEK)
- Built-in risk scenarios (Italy & Spain = high risk)
```

**Cell 2** (Python): Import libraries and configuration

```python
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random

# Set seed for reproducibility
np.random.seed(42)
random.seed(42)

# Bank configuration
BANK_NAME = "DRC Bank"

# Country configuration with risk profiles
COUNTRIES_CONFIG = {
    'Germany': {'currency': 'EUR', 'subsidiaries': ['DRC Germany Retail', 'DRC Germany Corporate'], 'risk': 'low', 'balance_skew': 1.0},
    'France': {'currency': 'EUR', 'subsidiaries': ['DRC France Investment', 'DRC France Private Banking'], 'risk': 'low', 'balance_skew': 1.0},
    'United Kingdom': {'currency': 'GBP', 'subsidiaries': ['DRC UK Holdings', 'DRC UK Wealth Management'], 'risk': 'medium', 'balance_skew': 1.2},
    'Switzerland': {'currency': 'CHF', 'subsidiaries': ['DRC Swiss Private Banking'], 'risk': 'low', 'balance_skew': 0.9},
    'Italy': {'currency': 'EUR', 'subsidiaries': ['DRC Italy Retail', 'DRC Italy SME'], 'risk': 'high', 'balance_skew': 0.6},
    'Spain': {'currency': 'EUR', 'subsidiaries': ['DRC Spain Consumer'], 'risk': 'high', 'balance_skew': 0.6},
    'Poland': {'currency': 'PLN', 'subsidiaries': ['DRC Poland Retail'], 'risk': 'medium', 'balance_skew': 1.3},
    'Sweden': {'currency': 'SEK', 'subsidiaries': ['DRC Sweden Nordic'], 'risk': 'low', 'balance_skew': 1.0}
}

# Currency conversion rates to EUR
FX_RATES = {'EUR': 1.0, 'GBP': 1.17, 'CHF': 1.09, 'PLN': 0.23, 'SEK': 0.09}

print("✅ Configuration loaded successfully")
```

**Cell 3** (Python): Data generation functions

```python
def generate_balances_data(target_date, num_records=1000):
    """Generate synthetic account balances data"""
    
    data = []
    for i in range(num_records):
        country = random.choice(list(COUNTRIES_CONFIG.keys()))
        config = COUNTRIES_CONFIG[country]
        currency = config['currency']
        subsidiary = random.choice(config['subsidiaries'])
        
        # Account types
        account_type = random.choice([
            'Current Account', 'Savings Account', 'Term Deposit', 
            'Corporate Account', 'Investment Account', 'Money Market Account'
        ])
        
        # Customer segment
        customer_segment = random.choice(['Retail', 'Corporate', 'Institutional'])
        
        # Balance generation with country risk skew
        if customer_segment == 'Retail':
            base_balance = np.random.lognormal(9, 1.5)
        elif customer_segment == 'Corporate':
            base_balance = np.random.lognormal(12, 1.8)
        else:  # Institutional
            base_balance = np.random.lognormal(14, 2.0)
        
        balance_local = round(base_balance * config['balance_skew'], 2)
        balance_eur = round(balance_local * FX_RATES[currency], 2)
        
        # Maturity bucket
        maturity_bucket = random.choice(['Overnight', '7-day', '30-day', '90-day', '180-day', '1-year', '>1-year'])
        
        # Weighted outflow rate (higher for high-risk countries)
        if config['risk'] == 'high':
            outflow_rate = round(random.uniform(0.15, 0.40), 4)
        elif config['risk'] == 'medium':
            outflow_rate = round(random.uniform(0.05, 0.20), 4)
        else:  # low risk
            outflow_rate = round(random.uniform(0.03, 0.10), 4)
        
        # Stable funding flag
        stable_funding_flag = 'Y' if maturity_bucket in ['180-day', '1-year', '>1-year'] else 'N'
        
        # Volatility (higher for high-risk countries)
        if config['risk'] == 'high':
            volatility = random.choices(['Low', 'Medium', 'High'], weights=[0.1, 0.3, 0.6])[0]
        elif config['risk'] == 'medium':
            volatility = random.choices(['Low', 'Medium', 'High'], weights=[0.3, 0.5, 0.2])[0]
        else:
            volatility = random.choices(['Low', 'Medium', 'High'], weights=[0.6, 0.3, 0.1])[0]
        
        data.append({
            'account_id': f'ACC_{country[:3].upper()}{i:06d}',
            'country': country,
            'subsidiary': subsidiary,
            'account_type': account_type,
            'currency': currency,
            'balance_local': balance_local,
            'balance_eur': balance_eur,
            'customer_segment': customer_segment,
            'maturity_bucket': maturity_bucket,
            'weighted_outflow_rate': outflow_rate,
            'stable_funding_flag': stable_funding_flag,
            'last_transaction_date': target_date - timedelta(days=random.randint(0, 30)),
            'average_balance_30d': round(balance_eur * random.uniform(0.9, 1.1), 2),
            'balance_volatility': volatility,
            'business_date': target_date,
            'created_timestamp': datetime.now()
        })
    
    return pd.DataFrame(data)

def generate_hqla_data(target_date, num_records=1000):
    """Generate synthetic HQLA data"""
    
    # HQLA levels with strict validation
    hqla_configs = {
        'Level 1': {
            'haircut': 0.0,
            'asset_types': ['Cash', 'Central Bank Reserves', 'Government Bonds AAA', 'Government Bonds AA'],
            'ratings': ['AAA', 'AA+', 'AA'],
            'liquidity_score': (9, 10)
        },
        'Level 2A': {
            'haircut': 0.15,
            'asset_types': ['Corporate Bonds AA-', 'Covered Bonds AA+', 'Municipal Bonds AA'],
            'ratings': ['AA', 'AA-', 'A+'],
            'liquidity_score': (7, 9)
        },
        'Level 2B': {
            'haircut': random.choice([0.25, 0.50]),
            'asset_types': ['Corporate Bonds A+', 'Equity Securities', 'RMBS AA'],
            'ratings': ['A+', 'A', 'A-', 'BBB+'],
            'liquidity_score': (5, 7)
        }
    }
    
    data = []
    for i in range(num_records):
        country = random.choice(list(COUNTRIES_CONFIG.keys()))
        config = COUNTRIES_CONFIG[country]
        currency = config['currency']
        subsidiary = random.choice(config['subsidiaries'])
        
        # HQLA level distribution by risk
        if config['risk'] == 'high':
            hqla_level = random.choices(['Level 1', 'Level 2A', 'Level 2B'], weights=[0.2, 0.3, 0.5])[0]
        elif config['risk'] == 'medium':
            hqla_level = random.choices(['Level 1', 'Level 2A', 'Level 2B'], weights=[0.3, 0.4, 0.3])[0]
        else:
            hqla_level = random.choices(['Level 1', 'Level 2A', 'Level 2B'], weights=[0.5, 0.3, 0.2])[0]
        
        hqla_config = hqla_configs[hqla_level]
        asset_type = random.choice(hqla_config['asset_types'])
        credit_rating = random.choice(hqla_config['ratings'])
        liquidity_score = random.randint(*hqla_config['liquidity_score'])
        
        # Market value
        market_value_local = round(np.random.lognormal(13, 1.5), 2)
        market_value_eur = round(market_value_local * FX_RATES[currency], 2)
        
        # Apply haircut
        haircut_rate = hqla_config['haircut']
        eligible_hqla_value_eur = round(market_value_eur * (1 - haircut_rate), 2)
        
        # Encumbered flag (15-20% encumbered)
        encumbered_flag = 'Y' if random.random() < 0.18 else 'N'
        
        data.append({
            'asset_id': f'HQLA_{country[:3].upper()}{i:06d}',
            'country': country,
            'subsidiary': subsidiary,
            'hqla_level': hqla_level,
            'asset_type': asset_type,
            'currency': currency,
            'market_value_local': market_value_local,
            'market_value_eur': market_value_eur,
            'haircut_rate': haircut_rate,
            'eligible_hqla_value_eur': eligible_hqla_value_eur,
            'maturity_date': target_date + timedelta(days=random.randint(30, 3650)),
            'credit_rating': credit_rating,
            'liquidity_score': liquidity_score,
            'encumbered_flag': encumbered_flag,
            'central_bank_eligible': random.choice(['Y', 'N']),
            'yield_rate': round(random.uniform(0.001, 0.05), 4),
            'duration_years': round(random.uniform(0.5, 10), 2),
            'last_valuation_date': target_date,
            'business_date': target_date,
            'created_timestamp': datetime.now()
        })
    
    return pd.DataFrame(data)

def generate_collateral_data(target_date, num_records=1000):
    """Generate synthetic collateral data"""
    
    quality_configs = {
        'A': {'haircut_range': (0.05, 0.15), 'ltv_range': (0.80, 0.95)},
        'B': {'haircut_range': (0.15, 0.25), 'ltv_range': (0.70, 0.85)},
        'C': {'haircut_range': (0.25, 0.40), 'ltv_range': (0.60, 0.75)},
        'D': {'haircut_range': (0.40, 0.60), 'ltv_range': (0.40, 0.60)}
    }
    
    data = []
    for i in range(num_records):
        country = random.choice(list(COUNTRIES_CONFIG.keys()))
        config = COUNTRIES_CONFIG[country]
        currency = config['currency']
        subsidiary = random.choice(config['subsidiaries'])
        
        collateral_type = random.choice([
            'Real Estate', 'Equipment', 'Inventory', 'Securities', 
            'Cash Deposit', 'Receivables', 'Vehicles', 'Intellectual Property'
        ])
        
        # Quality rating distribution by risk
        if config['risk'] == 'high':
            quality_rating = random.choices(['A', 'B', 'C', 'D'], weights=[0.1, 0.2, 0.4, 0.3])[0]
        elif config['risk'] == 'medium':
            quality_rating = random.choices(['A', 'B', 'C', 'D'], weights=[0.2, 0.4, 0.3, 0.1])[0]
        else:
            quality_rating = random.choices(['A', 'B', 'C', 'D'], weights=[0.4, 0.35, 0.2, 0.05])[0]
        
        quality_config = quality_configs[quality_rating]
        
        gross_value_local = round(np.random.lognormal(12, 1.5), 2)
        gross_value_eur = round(gross_value_local * FX_RATES[currency], 2)
        
        haircut_percentage = round(random.uniform(*quality_config['haircut_range']), 4)
        net_realizable_value_eur = round(gross_value_eur * (1 - haircut_percentage), 2)
        
        ltv_ratio = round(random.uniform(*quality_config['ltv_range']), 4)
        
        # Concentration risk (higher for high-risk countries)
        concentration_risk_flag = 'Y' if (config['risk'] == 'high' and random.random() < 0.4) else 'N'
        
        data.append({
            'collateral_id': f'COLL_{country[:3].upper()}{i:06d}',
            'country': country,
            'subsidiary': subsidiary,
            'collateral_type': collateral_type,
            'currency': currency,
            'gross_value_local': gross_value_local,
            'gross_value_eur': gross_value_eur,
            'loan_to_value_ratio': ltv_ratio,
            'haircut_percentage': haircut_percentage,
            'net_realizable_value_eur': net_realizable_value_eur,
            'associated_loan_id': f'LOAN_{country[:3].upper()}{random.randint(1, 500):06d}',
            'collateral_status': random.choice(['Active', 'Active', 'Active', 'Under Review']),
            'valuation_date': target_date,
            'next_review_date': target_date + timedelta(days=random.randint(30, 365)),
            'quality_rating': quality_rating,
            'liquidation_period_days': random.randint(5, 180),
            'insurance_status': random.choice(['Y', 'Y', 'Y', 'N']),
            'legal_ownership': random.choice(['Owned', 'Leased', 'Third-party']),
            'concentration_risk_flag': concentration_risk_flag,
            'business_date': target_date,
            'created_timestamp': datetime.now()
        })
    
    return pd.DataFrame(data)

def generate_data_for_date(date_str, num_records_per_dataset=1000):
    """Main function to generate all datasets for a specific date"""
    
    target_date = datetime.strptime(date_str, '%Y-%m-%d')
    
    print(f"Generating data for {date_str}...")
    
    # Generate datasets
    balances_df = generate_balances_data(target_date, num_records_per_dataset)
    hqla_df = generate_hqla_data(target_date, num_records_per_dataset)
    collateral_df = generate_collateral_data(target_date, num_records_per_dataset)
    
    # Save to landing zone
    base_path = "/Volumes/liquidity_dev/bronze/landing_zone"
    
    # Save balances
    balances_path = f"{base_path}/balances/{date_str}/balances_{date_str}.csv"
    balances_df.to_csv(balances_path, index=False)
    print(f"  ✓ Balances: {len(balances_df)} records saved to {balances_path}")
    
    # Save HQLA
    hqla_path = f"{base_path}/hqla/{date_str}/hqla_{date_str}.csv"
    hqla_df.to_csv(hqla_path, index=False)
    print(f"  ✓ HQLA: {len(hqla_df)} records saved to {hqla_path}")
    
    # Save collateral
    collateral_path = f"{base_path}/collateral/{date_str}/collateral_{date_str}.csv"
    collateral_df.to_csv(collateral_path, index=False)
    print(f"  ✓ Collateral: {len(collateral_df)} records saved to {collateral_path}")
    
    return {
        'balances': balances_df,
        'hqla': hqla_df,
        'collateral': collateral_df
    }

print("✅ Data generation functions loaded")
```

**Cell 4** (Python): Generate sample data for today

```python
# Generate data for today
today = datetime.now().strftime('%Y-%m-%d')
print(f"Generating liquidity data for: {today}\n")

datasets = generate_data_for_date(today, num_records_per_dataset=1000)

print("\n" + "="*80)
print("✅ Sample data generation completed!")
print("="*80)
```

**Expected Output**: 3 CSV files created in landing zone

**Validation**:
```python
# Verify files exist
import os
base_path = "/Volumes/liquidity_dev/bronze/landing_zone"
for dataset in ['balances', 'hqla', 'collateral']:
    path = f"{base_path}/{dataset}/{today}"
    files = dbutils.fs.ls(path)
    print(f"{dataset}: {len(files)} file(s) found")
```

---

### Phase 2: Bronze Layer (10 minutes)

#### Task 2.1: Create Bronze Layer Notebook

**Notebook Name**: `01-bronze-layer`

**Cell 1** (Markdown): Purpose

```markdown
# Bronze Layer ETL

Loads raw CSV files from landing zone into managed Databricks tables:
- `liquidity_dev.bronze.balances`
- `liquidity_dev.bronze.hqla`
- `liquidity_dev.bronze.collateral`

Features:
- Recursive file discovery
- Idempotent (CREATE OR REPLACE)
- Full schema with comments
- Metadata tracking (source file, load timestamp)
```

**Cell 2** (SQL): Create balances table

```sql
CREATE OR REPLACE TABLE liquidity_dev.bronze.balances (
  account_id STRING COMMENT 'Unique identifier for each account',
  country STRING COMMENT 'Country where the account is held',
  subsidiary STRING COMMENT 'Bank subsidiary managing the account',
  account_type STRING COMMENT 'Type of account',
  currency STRING COMMENT 'Currency of the account',
  balance_local DECIMAL(18,2) COMMENT 'Balance in local currency',
  balance_eur DECIMAL(18,2) COMMENT 'Balance converted to EUR',
  customer_segment STRING COMMENT 'Customer type (Retail, Corporate, Institutional)',
  maturity_bucket STRING COMMENT 'Maturity classification',
  weighted_outflow_rate DECIMAL(8,4) COMMENT 'Expected outflow rate for LCR calculation',
  stable_funding_flag STRING COMMENT 'Stable funding indicator (Y/N)',
  last_transaction_date DATE COMMENT 'Date of last transaction',
  average_balance_30d DECIMAL(18,2) COMMENT '30-day rolling average balance',
  balance_volatility STRING COMMENT 'Volatility indicator (Low/Medium/High)',
  business_date DATE COMMENT 'Reporting date',
  created_timestamp TIMESTAMP COMMENT 'Record creation timestamp'
)
COMMENT 'Bronze layer - raw account balances from landing zone';

INSERT OVERWRITE liquidity_dev.bronze.balances
SELECT *
FROM read_files(
  '/Volumes/liquidity_dev/bronze/landing_zone/balances/',
  format => 'csv',
  header => true,
  recursiveFileLookup => true
);
```

**Cell 3** (SQL): Create HQLA table

```sql
CREATE OR REPLACE TABLE liquidity_dev.bronze.hqla (
  asset_id STRING COMMENT 'Unique identifier for each asset',
  country STRING COMMENT 'Country where the asset is held',
  subsidiary STRING COMMENT 'Bank subsidiary holding the asset',
  hqla_level STRING COMMENT 'Basel III HQLA classification (Level 1, Level 2A, Level 2B)',
  asset_type STRING COMMENT 'Specific type of asset',
  currency STRING COMMENT 'Currency denomination of the asset',
  market_value_local DECIMAL(18,2) COMMENT 'Current market value in local currency',
  market_value_eur DECIMAL(18,2) COMMENT 'Market value converted to EUR',
  haircut_rate DECIMAL(8,4) COMMENT 'Haircut percentage applied (0%, 15%, 25-50%)',
  eligible_hqla_value_eur DECIMAL(18,2) COMMENT 'Value after haircuts (for LCR numerator)',
  maturity_date DATE COMMENT 'Asset maturity date',
  credit_rating STRING COMMENT 'Credit rating',
  liquidity_score INT COMMENT 'Liquidity score (1-10, 10=most liquid)',
  encumbered_flag STRING COMMENT 'Whether asset is pledged (Y/N)',
  central_bank_eligible STRING COMMENT 'Eligible for central bank operations (Y/N)',
  yield_rate DECIMAL(8,4) COMMENT 'Current yield rate',
  duration_years DECIMAL(8,2) COMMENT 'Duration in years',
  last_valuation_date DATE COMMENT 'Last valuation date',
  business_date DATE COMMENT 'Reporting date',
  created_timestamp TIMESTAMP COMMENT 'Record creation timestamp'
)
COMMENT 'Bronze layer - raw HQLA (High Quality Liquid Assets) from landing zone';

INSERT OVERWRITE liquidity_dev.bronze.hqla
SELECT *
FROM read_files(
  '/Volumes/liquidity_dev/bronze/landing_zone/hqla/',
  format => 'csv',
  header => true,
  recursiveFileLookup => true
);
```

**Cell 4** (SQL): Create collateral table

```sql
CREATE OR REPLACE TABLE liquidity_dev.bronze.collateral (
  collateral_id STRING COMMENT 'Unique identifier for each collateral',
  country STRING COMMENT 'Country where collateral is located',
  subsidiary STRING COMMENT 'Bank subsidiary managing the collateral',
  collateral_type STRING COMMENT 'Type of collateral',
  currency STRING COMMENT 'Currency of collateral valuation',
  gross_value_local DECIMAL(18,2) COMMENT 'Gross collateral value in local currency',
  gross_value_eur DECIMAL(18,2) COMMENT 'Gross value converted to EUR',
  loan_to_value_ratio DECIMAL(8,4) COMMENT 'LTV ratio',
  haircut_percentage DECIMAL(8,4) COMMENT 'Haircut percentage applied',
  net_realizable_value_eur DECIMAL(18,2) COMMENT 'Net value after haircuts',
  associated_loan_id STRING COMMENT 'Reference to associated loan',
  collateral_status STRING COMMENT 'Collateral status (Active, Under Review, Released)',
  valuation_date DATE COMMENT 'Valuation date',
  next_review_date DATE COMMENT 'Next scheduled review date',
  quality_rating STRING COMMENT 'Quality rating (A, B, C, D)',
  liquidation_period_days INT COMMENT 'Expected liquidation period in days',
  insurance_status STRING COMMENT 'Insurance coverage (Y/N)',
  legal_ownership STRING COMMENT 'Legal ownership type',
  concentration_risk_flag STRING COMMENT 'Concentration risk indicator (Y/N)',
  business_date DATE COMMENT 'Reporting date',
  created_timestamp TIMESTAMP COMMENT 'Record creation timestamp'
)
COMMENT 'Bronze layer - raw collateral data from landing zone';

INSERT OVERWRITE liquidity_dev.bronze.collateral
SELECT *
FROM read_files(
  '/Volumes/liquidity_dev/bronze/landing_zone/collateral/',
  format => 'csv',
  header => true,
  recursiveFileLookup => true
);
```

**Cell 5** (SQL): Verify bronze tables

```sql
SELECT 
  'balances' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date
FROM liquidity_dev.bronze.balances
UNION ALL
SELECT 
  'hqla' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date
FROM liquidity_dev.bronze.hqla
UNION ALL
SELECT 
  'collateral' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date
FROM liquidity_dev.bronze.collateral;
```

**Expected Output**: 3 rows showing record counts (1,000+ per table)

---

### Phase 3: Silver Layer (15 minutes)

#### Task 3.1: Create Silver Layer Notebook

**Notebook Name**: `02-silver-layer`

**Cell 1** (Markdown): Purpose

```markdown
# Silver Layer Data Quality

Applies data quality rules to create cleaned tables:
- `liquidity_dev.silver.balances_cleaned`
- `liquidity_dev.silver.hqla_cleaned`
- `liquidity_dev.silver.collateral_cleaned`

Data Quality Rules:
1. Remove nulls in key fields
2. Trim trailing/leading spaces
3. Deduplicate (by ID + date, keep latest)
4. Uppercase flags (Y/N)
5. Validate categories (HQLA levels, quality ratings)
6. Range validation (positive values, percentages 0-100%)
```

**Cell 2** (SQL): Create balances_cleaned

```sql
CREATE OR REPLACE TABLE liquidity_dev.silver.balances_cleaned (
  account_id STRING COMMENT 'Unique identifier for each account',
  country STRING COMMENT 'Country where the account is held',
  subsidiary STRING COMMENT 'Bank subsidiary managing the account',
  account_type STRING COMMENT 'Type of account',
  currency STRING COMMENT 'Currency of the account',
  balance_local DECIMAL(18,2) COMMENT 'Balance in local currency',
  balance_eur DECIMAL(18,2) COMMENT 'Balance converted to EUR',
  customer_segment STRING COMMENT 'Customer type (Retail, Corporate, Institutional)',
  maturity_bucket STRING COMMENT 'Maturity classification',
  weighted_outflow_rate DECIMAL(8,4) COMMENT 'Expected outflow rate for LCR calculation',
  stable_funding_flag STRING COMMENT 'Stable funding indicator (Y/N)',
  last_transaction_date DATE COMMENT 'Date of last transaction',
  average_balance_30d DECIMAL(18,2) COMMENT '30-day rolling average balance',
  balance_volatility STRING COMMENT 'Volatility indicator (Low/Medium/High)',
  business_date DATE COMMENT 'Reporting date',
  created_timestamp TIMESTAMP COMMENT 'Record creation timestamp'
)
COMMENT 'Silver layer - cleaned and validated account balances';

INSERT OVERWRITE liquidity_dev.silver.balances_cleaned
WITH deduplicated AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY account_id, business_date ORDER BY created_timestamp DESC) AS rn
  FROM liquidity_dev.bronze.balances
  WHERE account_id IS NOT NULL
    AND business_date IS NOT NULL
    AND balance_eur IS NOT NULL
    AND balance_eur > 0
)
SELECT
  TRIM(account_id) AS account_id,
  TRIM(country) AS country,
  TRIM(subsidiary) AS subsidiary,
  TRIM(account_type) AS account_type,
  TRIM(currency) AS currency,
  balance_local,
  balance_eur,
  TRIM(customer_segment) AS customer_segment,
  TRIM(maturity_bucket) AS maturity_bucket,
  weighted_outflow_rate,
  UPPER(TRIM(stable_funding_flag)) AS stable_funding_flag,
  last_transaction_date,
  average_balance_30d,
  TRIM(balance_volatility) AS balance_volatility,
  business_date,
  created_timestamp
FROM deduplicated
WHERE rn = 1;
```

**Cell 3** (SQL): Create hqla_cleaned

```sql
CREATE OR REPLACE TABLE liquidity_dev.silver.hqla_cleaned (
  asset_id STRING COMMENT 'Unique identifier for each asset',
  country STRING COMMENT 'Country where the asset is held',
  subsidiary STRING COMMENT 'Bank subsidiary holding the asset',
  hqla_level STRING COMMENT 'Basel III HQLA classification (Level 1, Level 2A, Level 2B)',
  asset_type STRING COMMENT 'Specific type of asset',
  currency STRING COMMENT 'Currency denomination of the asset',
  market_value_local DECIMAL(18,2) COMMENT 'Current market value in local currency',
  market_value_eur DECIMAL(18,2) COMMENT 'Market value converted to EUR',
  haircut_rate DECIMAL(8,4) COMMENT 'Haircut percentage applied',
  eligible_hqla_value_eur DECIMAL(18,2) COMMENT 'Value after haircuts (for LCR numerator)',
  maturity_date DATE COMMENT 'Asset maturity date',
  credit_rating STRING COMMENT 'Credit rating',
  liquidity_score INT COMMENT 'Liquidity score (1-10)',
  encumbered_flag STRING COMMENT 'Whether asset is pledged (Y/N)',
  central_bank_eligible STRING COMMENT 'Eligible for central bank operations (Y/N)',
  yield_rate DECIMAL(8,4) COMMENT 'Current yield rate',
  duration_years DECIMAL(8,2) COMMENT 'Duration in years',
  last_valuation_date DATE COMMENT 'Last valuation date',
  business_date DATE COMMENT 'Reporting date',
  created_timestamp TIMESTAMP COMMENT 'Record creation timestamp'
)
COMMENT 'Silver layer - cleaned and validated HQLA data';

INSERT OVERWRITE liquidity_dev.silver.hqla_cleaned
WITH deduplicated AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY asset_id, business_date ORDER BY created_timestamp DESC) AS rn
  FROM liquidity_dev.bronze.hqla
  WHERE asset_id IS NOT NULL
    AND business_date IS NOT NULL
    AND market_value_eur IS NOT NULL
    AND market_value_eur > 0
    AND hqla_level IN ('Level 1', 'Level 2A', 'Level 2B')  -- Validate HQLA levels
)
SELECT
  TRIM(asset_id) AS asset_id,
  TRIM(country) AS country,
  TRIM(subsidiary) AS subsidiary,
  TRIM(hqla_level) AS hqla_level,
  TRIM(asset_type) AS asset_type,
  TRIM(currency) AS currency,
  market_value_local,
  market_value_eur,
  haircut_rate,
  eligible_hqla_value_eur,
  maturity_date,
  TRIM(credit_rating) AS credit_rating,
  liquidity_score,
  UPPER(TRIM(encumbered_flag)) AS encumbered_flag,
  UPPER(TRIM(central_bank_eligible)) AS central_bank_eligible,
  yield_rate,
  duration_years,
  last_valuation_date,
  business_date,
  created_timestamp
FROM deduplicated
WHERE rn = 1;
```

**Cell 4** (SQL): Create collateral_cleaned

```sql
CREATE OR REPLACE TABLE liquidity_dev.silver.collateral_cleaned (
  collateral_id STRING COMMENT 'Unique identifier for each collateral',
  country STRING COMMENT 'Country where collateral is located',
  subsidiary STRING COMMENT 'Bank subsidiary managing the collateral',
  collateral_type STRING COMMENT 'Type of collateral',
  currency STRING COMMENT 'Currency of collateral valuation',
  gross_value_local DECIMAL(18,2) COMMENT 'Gross collateral value in local currency',
  gross_value_eur DECIMAL(18,2) COMMENT 'Gross value converted to EUR',
  loan_to_value_ratio DECIMAL(8,4) COMMENT 'LTV ratio',
  haircut_percentage DECIMAL(8,4) COMMENT 'Haircut percentage applied',
  net_realizable_value_eur DECIMAL(18,2) COMMENT 'Net value after haircuts',
  associated_loan_id STRING COMMENT 'Reference to associated loan',
  collateral_status STRING COMMENT 'Collateral status',
  valuation_date DATE COMMENT 'Valuation date',
  next_review_date DATE COMMENT 'Next scheduled review date',
  quality_rating STRING COMMENT 'Quality rating (A, B, C, D)',
  liquidation_period_days INT COMMENT 'Expected liquidation period in days',
  insurance_status STRING COMMENT 'Insurance coverage (Y/N)',
  legal_ownership STRING COMMENT 'Legal ownership type',
  concentration_risk_flag STRING COMMENT 'Concentration risk indicator (Y/N)',
  business_date DATE COMMENT 'Reporting date',
  created_timestamp TIMESTAMP COMMENT 'Record creation timestamp'
)
COMMENT 'Silver layer - cleaned and validated collateral data';

INSERT OVERWRITE liquidity_dev.silver.collateral_cleaned
WITH deduplicated AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY collateral_id, business_date ORDER BY created_timestamp DESC) AS rn
  FROM liquidity_dev.bronze.collateral
  WHERE collateral_id IS NOT NULL
    AND business_date IS NOT NULL
    AND gross_value_eur IS NOT NULL
    AND gross_value_eur > 0
    AND quality_rating IN ('A', 'B', 'C', 'D')  -- Validate quality ratings
)
SELECT
  TRIM(collateral_id) AS collateral_id,
  TRIM(country) AS country,
  TRIM(subsidiary) AS subsidiary,
  TRIM(collateral_type) AS collateral_type,
  TRIM(currency) AS currency,
  gross_value_local,
  gross_value_eur,
  loan_to_value_ratio,
  haircut_percentage,
  net_realizable_value_eur,
  TRIM(associated_loan_id) AS associated_loan_id,
  TRIM(collateral_status) AS collateral_status,
  valuation_date,
  next_review_date,
  TRIM(quality_rating) AS quality_rating,
  liquidation_period_days,
  UPPER(TRIM(insurance_status)) AS insurance_status,
  TRIM(legal_ownership) AS legal_ownership,
  UPPER(TRIM(concentration_risk_flag)) AS concentration_risk_flag,
  business_date,
  created_timestamp
FROM deduplicated
WHERE rn = 1;
```

**Cell 5** (SQL): Verify silver tables

```sql
SELECT 
  'balances_cleaned' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates
FROM liquidity_dev.silver.balances_cleaned
UNION ALL
SELECT 
  'hqla_cleaned' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates
FROM liquidity_dev.silver.hqla_cleaned
UNION ALL
SELECT 
  'collateral_cleaned' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates
FROM liquidity_dev.silver.collateral_cleaned;
```

**Expected Output**: 3 rows with counts matching bronze (no duplicates removed if data generation is correct)

---

### Phase 4: Gold Layer - Dimensions (20 minutes)

#### Task 4.1: Create Gold Layer Notebook

**Notebook Name**: `03-gold-layer`

**Cell 1** (Markdown): Purpose

```markdown
# Gold Layer - Dimensional Model

Creates star schema for analytics:

**Dimensions (4)**:
- `dim_date` - Time dimension
- `dim_country` - Geographic attributes
- `dim_subsidiary` - Organizational hierarchy
- `dim_account` - Account attributes (Type 2 SCD)

**Facts (4)**:
- `fact_intraday_liquidity` - LCR calculations ⭐
- `fact_hqla_position` - HQLA composition
- `fact_funding_stability` - Funding maturity analysis
- `fact_collateral_risk` - Collateral quality & risk

All tables have:
- Primary/Foreign key constraints
- Comprehensive table and column comments
```

**Cell 2** (SQL): Create dim_date

```sql
CREATE OR REPLACE TABLE liquidity_dev.gold.dim_date (
  date_key INT COMMENT 'Primary key - date in YYYYMMDD format',
  business_date DATE COMMENT 'Actual calendar date',
  year INT COMMENT 'Year (YYYY)',
  quarter INT COMMENT 'Quarter (1-4)',
  month INT COMMENT 'Month (1-12)',
  month_name STRING COMMENT 'Month name',
  day_of_month INT COMMENT 'Day of month (1-31)',
  day_of_week INT COMMENT 'Day of week (1=Monday, 7=Sunday)',
  day_name STRING COMMENT 'Day name',
  week_of_year INT COMMENT 'Week number of the year',
  is_weekend STRING COMMENT 'Weekend flag (Y/N)',
  is_month_end STRING COMMENT 'Month-end flag (Y/N)',
  is_quarter_end STRING COMMENT 'Quarter-end flag (Y/N)',
  is_year_end STRING COMMENT 'Year-end flag (Y/N)',
  fiscal_year INT COMMENT 'Fiscal year',
  fiscal_quarter INT COMMENT 'Fiscal quarter',
  CONSTRAINT pk_dim_date PRIMARY KEY (date_key)
)
COMMENT 'Date dimension for time-based analysis';

INSERT INTO liquidity_dev.gold.dim_date
WITH all_dates AS (
  SELECT DISTINCT business_date FROM liquidity_dev.silver.balances_cleaned
  UNION
  SELECT DISTINCT business_date FROM liquidity_dev.silver.hqla_cleaned
  UNION
  SELECT DISTINCT business_date FROM liquidity_dev.silver.collateral_cleaned
)
SELECT
  CAST(DATE_FORMAT(business_date, 'yyyyMMdd') AS INT) AS date_key,
  business_date,
  YEAR(business_date) AS year,
  QUARTER(business_date) AS quarter,
  MONTH(business_date) AS month,
  DATE_FORMAT(business_date, 'MMMM') AS month_name,
  DAY(business_date) AS day_of_month,
  DAYOFWEEK(business_date) AS day_of_week,
  DATE_FORMAT(business_date, 'EEEE') AS day_name,
  WEEKOFYEAR(business_date) AS week_of_year,
  CASE WHEN DAYOFWEEK(business_date) IN (1, 7) THEN 'Y' ELSE 'N' END AS is_weekend,
  CASE WHEN business_date = LAST_DAY(business_date) THEN 'Y' ELSE 'N' END AS is_month_end,
  CASE WHEN MONTH(business_date) IN (3, 6, 9, 12) AND business_date = LAST_DAY(business_date) THEN 'Y' ELSE 'N' END AS is_quarter_end,
  CASE WHEN MONTH(business_date) = 12 AND business_date = LAST_DAY(business_date) THEN 'Y' ELSE 'N' END AS is_year_end,
  YEAR(business_date) AS fiscal_year,
  QUARTER(business_date) AS fiscal_quarter
FROM all_dates;
```

**Cell 3** (SQL): Create dim_country

```sql
CREATE OR REPLACE TABLE liquidity_dev.gold.dim_country (
  country_key INT COMMENT 'Primary key - surrogate key',
  country_name STRING COMMENT 'Country name',
  country_code STRING COMMENT 'ISO 3-letter country code',
  region STRING COMMENT 'Geographic region',
  currency STRING COMMENT 'Primary currency',
  is_eurozone STRING COMMENT 'Eurozone member flag (Y/N)',
  liquidity_risk_category STRING COMMENT 'Liquidity risk category (Low, Medium, High)',
  CONSTRAINT pk_dim_country PRIMARY KEY (country_key)
)
COMMENT 'Country dimension for geographic analysis';

INSERT INTO liquidity_dev.gold.dim_country
WITH country_list AS (
  SELECT DISTINCT country FROM liquidity_dev.silver.balances_cleaned
  UNION
  SELECT DISTINCT country FROM liquidity_dev.silver.hqla_cleaned
  UNION
  SELECT DISTINCT country FROM liquidity_dev.silver.collateral_cleaned
)
SELECT
  ROW_NUMBER() OVER (ORDER BY country) AS country_key,
  country AS country_name,
  CASE country
    WHEN 'Germany' THEN 'DEU'
    WHEN 'France' THEN 'FRA'
    WHEN 'United Kingdom' THEN 'GBR'
    WHEN 'Switzerland' THEN 'CHE'
    WHEN 'Italy' THEN 'ITA'
    WHEN 'Spain' THEN 'ESP'
    WHEN 'Poland' THEN 'POL'
    WHEN 'Sweden' THEN 'SWE'
    ELSE 'UNK'
  END AS country_code,
  CASE 
    WHEN country IN ('Germany', 'France', 'Switzerland', 'United Kingdom') THEN 'Western Europe'
    WHEN country IN ('Sweden') THEN 'Northern Europe'
    WHEN country IN ('Italy', 'Spain') THEN 'Southern Europe'
    WHEN country IN ('Poland') THEN 'Eastern Europe'
    ELSE 'Other'
  END AS region,
  CASE country
    WHEN 'Germany' THEN 'EUR'
    WHEN 'France' THEN 'EUR'
    WHEN 'United Kingdom' THEN 'GBP'
    WHEN 'Switzerland' THEN 'CHF'
    WHEN 'Italy' THEN 'EUR'
    WHEN 'Spain' THEN 'EUR'
    WHEN 'Poland' THEN 'PLN'
    WHEN 'Sweden' THEN 'SEK'
    ELSE 'EUR'
  END AS currency,
  CASE 
    WHEN country IN ('Germany', 'France', 'Italy', 'Spain') THEN 'Y'
    ELSE 'N'
  END AS is_eurozone,
  CASE 
    WHEN country IN ('Italy', 'Spain') THEN 'High'
    WHEN country IN ('United Kingdom', 'Poland') THEN 'Medium'
    WHEN country IN ('Germany', 'France', 'Switzerland', 'Sweden') THEN 'Low'
    ELSE 'Unknown'
  END AS liquidity_risk_category
FROM country_list;
```

**Cell 4** (SQL): Create dim_subsidiary

```sql
CREATE OR REPLACE TABLE liquidity_dev.gold.dim_subsidiary (
  subsidiary_key INT COMMENT 'Primary key - surrogate key',
  subsidiary_name STRING COMMENT 'Full subsidiary name',
  country STRING COMMENT 'Country where subsidiary operates',
  subsidiary_type STRING COMMENT 'Type of subsidiary',
  CONSTRAINT pk_dim_subsidiary PRIMARY KEY (subsidiary_key)
)
COMMENT 'Subsidiary dimension for organizational hierarchy';

INSERT INTO liquidity_dev.gold.dim_subsidiary
WITH subsidiary_list AS (
  SELECT DISTINCT subsidiary, country FROM liquidity_dev.silver.balances_cleaned
  UNION
  SELECT DISTINCT subsidiary, country FROM liquidity_dev.silver.hqla_cleaned
  UNION
  SELECT DISTINCT subsidiary, country FROM liquidity_dev.silver.collateral_cleaned
)
SELECT
  ROW_NUMBER() OVER (ORDER BY country, subsidiary) AS subsidiary_key,
  subsidiary AS subsidiary_name,
  country,
  CASE 
    WHEN subsidiary LIKE '%Retail%' OR subsidiary LIKE '%Consumer%' THEN 'Retail Banking'
    WHEN subsidiary LIKE '%Corporate%' OR subsidiary LIKE '%SME%' THEN 'Corporate Banking'
    WHEN subsidiary LIKE '%Investment%' OR subsidiary LIKE '%Trading%' THEN 'Investment Banking'
    WHEN subsidiary LIKE '%Asset Management%' THEN 'Asset Management'
    WHEN subsidiary LIKE '%Private Banking%' OR subsidiary LIKE '%Wealth%' THEN 'Private Banking'
    ELSE 'Other'
  END AS subsidiary_type
FROM subsidiary_list;
```

**Cell 5** (SQL): Create dim_account

```sql
CREATE OR REPLACE TABLE liquidity_dev.gold.dim_account (
  account_key INT COMMENT 'Primary key - surrogate key',
  account_id STRING COMMENT 'Business key - natural account identifier',
  account_type STRING COMMENT 'Type of account',
  customer_segment STRING COMMENT 'Customer segment',
  currency STRING COMMENT 'Account currency',
  country STRING COMMENT 'Country where account is held',
  subsidiary STRING COMMENT 'Managing subsidiary',
  effective_date DATE COMMENT 'Effective start date for this version',
  end_date DATE COMMENT 'Effective end date (NULL if current)',
  is_current STRING COMMENT 'Current record flag (Y/N)',
  CONSTRAINT pk_dim_account PRIMARY KEY (account_key)
)
COMMENT 'Account dimension with Type 2 SCD for tracking attribute changes';

INSERT INTO liquidity_dev.gold.dim_account
WITH latest_accounts AS (
  SELECT 
    account_id,
    account_type,
    customer_segment,
    currency,
    country,
    subsidiary,
    MAX(business_date) AS effective_date
  FROM liquidity_dev.silver.balances_cleaned
  GROUP BY account_id, account_type, customer_segment, currency, country, subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY account_id, effective_date) AS account_key,
  account_id,
  account_type,
  customer_segment,
  currency,
  country,
  subsidiary,
  effective_date,
  NULL AS end_date,
  'Y' AS is_current
FROM latest_accounts;
```

---

### Phase 5: Gold Layer - Facts (30 minutes)

#### Task 5.1: Create fact_intraday_liquidity

**Cell 6** (SQL): Create fact_intraday_liquidity with LCR

```sql
CREATE OR REPLACE TABLE liquidity_dev.gold.fact_intraday_liquidity (
  liquidity_key BIGINT COMMENT 'Primary key',
  date_key INT COMMENT 'Foreign key to dim_date',
  country_key INT COMMENT 'Foreign key to dim_country',
  subsidiary_key INT COMMENT 'Foreign key to dim_subsidiary',
  
  total_balance_eur DECIMAL(20,2) COMMENT 'Total account balances in EUR',
  account_count INT COMMENT 'Number of accounts',
  
  total_hqla_eligible_eur DECIMAL(20,2) COMMENT 'Total HQLA after haircuts (LCR numerator)',
  hqla_level1_eur DECIMAL(20,2) COMMENT 'Level 1 HQLA value',
  hqla_level2a_eur DECIMAL(20,2) COMMENT 'Level 2A HQLA value',
  hqla_level2b_eur DECIMAL(20,2) COMMENT 'Level 2B HQLA value',
  
  total_cash_outflows_30d DECIMAL(20,2) COMMENT 'Expected cash outflows over 30 days (LCR denominator)',
  stable_funding_amount DECIMAL(20,2) COMMENT 'Stable funding sources',
  unstable_funding_amount DECIMAL(20,2) COMMENT 'Unstable funding sources',
  
  liquidity_coverage_ratio DECIMAL(10,4) COMMENT 'LCR = Total HQLA / Total Net Cash Outflows (target >= 1.0)',
  lcr_surplus_deficit_eur DECIMAL(20,2) COMMENT 'HQLA surplus/deficit to meet 100% LCR',
  lcr_status STRING COMMENT 'Compliance status (Compliant, At Risk, Non-Compliant)',
  
  load_timestamp TIMESTAMP COMMENT 'Record load timestamp',
  
  CONSTRAINT pk_fact_intraday_liquidity PRIMARY KEY (liquidity_key),
  CONSTRAINT fk_liquidity_date FOREIGN KEY (date_key) REFERENCES liquidity_dev.gold.dim_date(date_key),
  CONSTRAINT fk_liquidity_country FOREIGN KEY (country_key) REFERENCES liquidity_dev.gold.dim_country(country_key),
  CONSTRAINT fk_liquidity_subsidiary FOREIGN KEY (subsidiary_key) REFERENCES liquidity_dev.gold.dim_subsidiary(subsidiary_key)
)
COMMENT 'Intraday liquidity fact with LCR calculations by date, country, subsidiary';

INSERT INTO liquidity_dev.gold.fact_intraday_liquidity
WITH balance_metrics AS (
  SELECT
    b.business_date,
    b.country,
    b.subsidiary,
    SUM(b.balance_eur) AS total_balance_eur,
    COUNT(DISTINCT b.account_id) AS account_count,
    SUM(b.balance_eur * b.weighted_outflow_rate) AS weighted_outflow_amount,
    SUM(CASE WHEN b.stable_funding_flag = 'Y' THEN b.balance_eur ELSE 0 END) AS stable_funding_amount,
    SUM(CASE WHEN b.stable_funding_flag = 'N' THEN b.balance_eur ELSE 0 END) AS unstable_funding_amount
  FROM liquidity_dev.silver.balances_cleaned b
  GROUP BY b.business_date, b.country, b.subsidiary
),
hqla_metrics AS (
  SELECT
    h.business_date,
    h.country,
    h.subsidiary,
    SUM(h.eligible_hqla_value_eur) AS total_hqla_eligible_eur,
    SUM(CASE WHEN h.hqla_level = 'Level 1' THEN h.eligible_hqla_value_eur ELSE 0 END) AS hqla_level1_eur,
    SUM(CASE WHEN h.hqla_level = 'Level 2A' THEN h.eligible_hqla_value_eur ELSE 0 END) AS hqla_level2a_eur,
    SUM(CASE WHEN h.hqla_level = 'Level 2B' THEN h.eligible_hqla_value_eur ELSE 0 END) AS hqla_level2b_eur
  FROM liquidity_dev.silver.hqla_cleaned h
  GROUP BY h.business_date, h.country, h.subsidiary
),
combined_metrics AS (
  SELECT
    COALESCE(b.business_date, h.business_date) AS business_date,
    COALESCE(b.country, h.country) AS country,
    COALESCE(b.subsidiary, h.subsidiary) AS subsidiary,
    COALESCE(b.total_balance_eur, 0) AS total_balance_eur,
    COALESCE(b.account_count, 0) AS account_count,
    COALESCE(h.total_hqla_eligible_eur, 0) AS total_hqla_eligible_eur,
    COALESCE(h.hqla_level1_eur, 0) AS hqla_level1_eur,
    COALESCE(h.hqla_level2a_eur, 0) AS hqla_level2a_eur,
    COALESCE(h.hqla_level2b_eur, 0) AS hqla_level2b_eur,
    COALESCE(b.weighted_outflow_amount, 0) AS weighted_outflow_amount,
    COALESCE(b.stable_funding_amount, 0) AS stable_funding_amount,
    COALESCE(b.unstable_funding_amount, 0) AS unstable_funding_amount
  FROM balance_metrics b
  FULL OUTER JOIN hqla_metrics h 
    ON b.business_date = h.business_date 
    AND b.country = h.country 
    AND b.subsidiary = h.subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY cm.business_date, cm.country, cm.subsidiary) AS liquidity_key,
  dd.date_key,
  dc.country_key,
  ds.subsidiary_key,
  cm.total_balance_eur,
  cm.account_count,
  cm.total_hqla_eligible_eur,
  cm.hqla_level1_eur,
  cm.hqla_level2a_eur,
  cm.hqla_level2b_eur,
  cm.weighted_outflow_amount AS total_cash_outflows_30d,
  cm.stable_funding_amount,
  cm.unstable_funding_amount,
  -- LCR Calculation: HQLA / Net Cash Outflows
  CASE 
    WHEN cm.weighted_outflow_amount > 0 
    THEN ROUND(cm.total_hqla_eligible_eur / cm.weighted_outflow_amount, 4)
    ELSE NULL 
  END AS liquidity_coverage_ratio,
  -- Surplus/Deficit
  CASE 
    WHEN cm.weighted_outflow_amount > 0 
    THEN ROUND(cm.total_hqla_eligible_eur - cm.weighted_outflow_amount, 2)
    ELSE cm.total_hqla_eligible_eur 
  END AS lcr_surplus_deficit_eur,
  -- LCR Status
  CASE 
    WHEN cm.weighted_outflow_amount = 0 THEN 'No Outflows'
    WHEN cm.total_hqla_eligible_eur / cm.weighted_outflow_amount >= 1.0 THEN 'Compliant'
    WHEN cm.total_hqla_eligible_eur / cm.weighted_outflow_amount >= 0.9 THEN 'At Risk'
    ELSE 'Non-Compliant'
  END AS lcr_status,
  current_timestamp() AS load_timestamp
FROM combined_metrics cm
INNER JOIN liquidity_dev.gold.dim_date dd ON CAST(DATE_FORMAT(cm.business_date, 'yyyyMMdd') AS INT) = dd.date_key
INNER JOIN liquidity_dev.gold.dim_country dc ON cm.country = dc.country_name
INNER JOIN liquidity_dev.gold.dim_subsidiary ds ON cm.subsidiary = ds.subsidiary_name AND cm.country = ds.country;
```

**Validation**:
```sql
-- Verify LCR calculations
SELECT
  dc.country_name,
  AVG(f.liquidity_coverage_ratio) AS avg_lcr,
  f.lcr_status,
  COUNT(*) AS record_count
FROM liquidity_dev.gold.fact_intraday_liquidity f
INNER JOIN liquidity_dev.gold.dim_country dc ON f.country_key = dc.country_key
GROUP BY dc.country_name, f.lcr_status
ORDER BY avg_lcr;
```

**Expected Output**: 
* Italy and Spain should show "Non-Compliant" or "At Risk" status (LCR < 100%)
* Germany, France, Switzerland, Sweden should show "Compliant" (LCR >= 100%)

---

#### Task 5.2: Create remaining fact tables

**Cell 7-9**: Create `fact_hqla_position`, `fact_funding_stability`, `fact_collateral_risk`

*(Follow similar pattern as fact_intraday_liquidity - aggregate from silver, join to dimensions, add metrics)*

**Cell 10** (SQL): Verify gold layer

```sql
SELECT 
  'fact_intraday_liquidity' AS table_name,
  COUNT(*) AS record_count,
  MIN(dd.business_date) AS min_date,
  MAX(dd.business_date) AS max_date
FROM liquidity_dev.gold.fact_intraday_liquidity f
INNER JOIN liquidity_dev.gold.dim_date dd ON f.date_key = dd.date_key
UNION ALL
SELECT 
  'dim_date' AS table_name,
  COUNT(*) AS record_count,
  MIN(business_date) AS min_date,
  MAX(business_date) AS max_date
FROM liquidity_dev.gold.dim_date;
```

---

## 📝 Post-Build Checklist

### Validation Steps

☐ **Bronze Layer**
- [ ] 3 tables created: balances, hqla, collateral
- [ ] Record count >= 1,000 per table
- [ ] All columns have comments
- [ ] Data loaded from landing zone

☐ **Silver Layer**
- [ ] 3 cleaned tables created
- [ ] No null values in key fields (account_id, asset_id, collateral_id, business_date)
- [ ] HQLA levels validated (only Level 1, 2A, 2B)
- [ ] Quality ratings validated (only A, B, C, D)
- [ ] Flags are uppercase (Y/N)

☐ **Gold Layer - Dimensions**
- [ ] 4 dimension tables created
- [ ] Primary keys defined
- [ ] All columns have comments
- [ ] dim_date has all dates from source data
- [ ] dim_country has 8 countries

☐ **Gold Layer - Facts**
- [ ] 4 fact tables created
- [ ] Foreign keys defined and valid
- [ ] LCR calculated correctly (numerator/denominator)
- [ ] Italy & Spain show high liquidity risk (LCR < 100% or close)
- [ ] All columns have comments

### Sample Analytics Query

Run this query to confirm the project is working:

```sql
SELECT 
  dc.country_name,
  dc.liquidity_risk_category,
  ROUND(AVG(f.liquidity_coverage_ratio), 4) AS avg_lcr,
  ROUND(SUM(f.total_hqla_eligible_eur), 2) AS total_hqla_eur,
  ROUND(SUM(f.total_cash_outflows_30d), 2) AS total_outflows_eur,
  MAX(f.lcr_status) AS lcr_status
FROM liquidity_dev.gold.fact_intraday_liquidity f
INNER JOIN liquidity_dev.gold.dim_country dc ON f.country_key = dc.country_key
INNER JOIN liquidity_dev.gold.dim_date dd ON f.date_key = dd.date_key
WHERE dd.business_date = (SELECT MAX(business_date) FROM liquidity_dev.gold.dim_date)
GROUP BY dc.country_name, dc.liquidity_risk_category
ORDER BY avg_lcr;
```

**Expected Output**:
* High-risk countries (Italy, Spain) at bottom with LCR < 1.0
* Low-risk countries (Germany, France, Switzerland, Sweden) at top with LCR > 1.0

---

## 🔧 Troubleshooting

### Common Issues

#### Issue: "Catalog does not exist"
**Solution**: Create catalog in Phase 0, Step 0.1

#### Issue: "Volume not found"
**Solution**: 
```sql
CREATE VOLUME IF NOT EXISTS liquidity_dev.bronze.landing_zone;
```

#### Issue: "No data in bronze tables"
**Solution**: 
1. Check landing zone has CSV files:
   ```python
   dbutils.fs.ls("/Volumes/liquidity_dev/bronze/landing_zone/balances/")
   ```
2. Re-run data generation (Phase 1, Cell 4)

#### Issue: "Foreign key constraint violation"
**Solution**: 
1. Verify dimensions exist before creating facts
2. Check dimension keys match fact table references

#### Issue: "LCR calculation returns NULL"
**Cause**: Denominator (cash outflows) is 0
**Solution**: This is expected if no outflow data exists. Verify balances_cleaned has weighted_outflow_rate > 0

---

## 📚 Additional Resources

### Databricks Documentation
* [Unity Catalog](https://docs.databricks.com/unity-catalog/index.html)
* [Delta Lake](https://docs.databricks.com/delta/index.html)
* [Medallion Architecture](https://docs.databricks.com/lakehouse-architecture/medallion.html)

### Basel III LCR Framework
* [Basel Committee LCR Standard](https://www.bis.org/publ/bcbs238.htm)
* [LCR Calculation Guide](https://www.bis.org/basel_framework/chapter/LCR/30.htm)

---

## ✏️ Agent Tips

### For Claude / GPT / Copilot

1. **Follow the phases sequentially** - don't skip ahead
2. **Validate after each phase** - run the verification queries
3. **Read error messages carefully** - they often contain the solution
4. **Use DESCRIBE EXTENDED** to inspect table schemas
5. **Check Unity Catalog permissions** if operations fail

### For Databricks Genie

1. **Use natural language** - "Create a dimension table for dates"
2. **Be specific about schema** - "Use liquidity_dev.gold schema"
3. **Request validation** - "Show me the record count for dim_date"
4. **Ask for help** - "Why is my LCR calculation returning NULL?"

---

## ✅ Success Criteria

The project is successfully built when:

1. ✅ All 12 tables exist (3 bronze + 3 silver + 4 dimensions + 4 facts)
2. ✅ LCR is calculated correctly (HQLA / Cash Outflows)
3. ✅ High-risk countries (Italy, Spain) show LCR < 100%
4. ✅ Low-risk countries show LCR >= 100%
5. ✅ All tables have primary/foreign keys
6. ✅ All tables and columns have meaningful comments
7. ✅ Sample analytics query returns expected results

---

**Built for AI Agents by AI Agents 🤖**

*Last Updated: June 27, 2026*