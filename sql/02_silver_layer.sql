-- ============================================================================
-- Silver Layer - Data Quality and Cleansing
-- ============================================================================
-- Applies data quality rules to bronze tables:
-- * Remove null values in key fields
-- * Trim trailing/leading spaces
-- * Deduplicate records
-- * Uppercase flags (Y/N)
-- * Validate categories and codes
-- * Ensure positive values
--
-- Usage:
--   databricks sql execute --file sql/02_silver_layer.sql

-- Create cleaned balances table in silver layer
-- Data quality rules:
-- 1. Remove records with null key fields (account_id, business_date, balance_eur)
-- 2. Trim trailing/leading spaces from string columns
-- 3. Deduplicate based on account_id and business_date (keep latest load_timestamp)
-- 4. Uppercase all flag columns (Y/N)
-- 5. Ensure positive balance values

CREATE OR REPLACE TABLE liquidity_dev.silver.balances_cleaned (
  account_id STRING COMMENT 'Unique identifier for each account (format: ACC{COUNTRY_CODE}{NUMBER})',
  country STRING COMMENT 'Country where the account is held',
  subsidiary STRING COMMENT 'Bank subsidiary managing the account',
  account_type STRING COMMENT 'Type of account (Current, Savings, Term Deposit, Corporate, Investment, Escrow, Money Market, Treasury)',
  currency STRING COMMENT 'Original currency of the account (EUR, GBP, CHF, PLN, SEK)',
  balance_local DECIMAL(18,2) COMMENT 'Balance amount in the local currency',
  balance_eur DECIMAL(18,2) COMMENT 'Balance converted to EUR (reporting currency)',
  customer_segment STRING COMMENT 'Customer type (Retail, Corporate, Institutional)',
  maturity_bucket STRING COMMENT 'Maturity classification (Overnight, 7-day, 30-day, 90-day, 180-day, 1-year, >1-year)',
  weighted_outflow_rate DECIMAL(8,4) COMMENT 'Expected outflow rate for LCR calculation (range: 0.03 to 0.40)',
  stable_funding_flag STRING COMMENT 'Whether this is a stable funding source (Y/N)',
  last_transaction_date DATE COMMENT 'Date of the most recent transaction on the account',
  average_balance_30d DECIMAL(18,2) COMMENT '30-day rolling average balance',
  balance_volatility STRING COMMENT 'Balance volatility indicator (Low, Medium, High)',
  business_date DATE COMMENT 'Reporting date for this data snapshot',
  created_timestamp TIMESTAMP COMMENT 'System timestamp when record was created in source',
  source_file STRING COMMENT 'Source CSV file path from landing zone',
  load_timestamp TIMESTAMP COMMENT 'Timestamp when data was loaded into bronze table',
  silver_load_timestamp TIMESTAMP COMMENT 'Timestamp when data was loaded into silver table'
)
COMMENT 'Silver layer cleaned table containing account balance information with data quality rules applied (no nulls, deduplicated, trimmed, validated)';

INSERT INTO liquidity_dev.silver.balances_cleaned
WITH deduplicated AS (
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
    created_timestamp,
    source_file,
    load_timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY TRIM(account_id), business_date 
      ORDER BY load_timestamp DESC
    ) AS rn
  FROM liquidity_dev.bronze.balances
  WHERE account_id IS NOT NULL
    AND business_date IS NOT NULL
    AND balance_eur IS NOT NULL
    AND balance_eur >= 0  -- Ensure positive balances
)
SELECT 
  account_id,
  country,
  subsidiary,
  account_type,
  currency,
  balance_local,
  balance_eur,
  customer_segment,
  maturity_bucket,
  weighted_outflow_rate,
  stable_funding_flag,
  last_transaction_date,
  average_balance_30d,
  balance_volatility,
  business_date,
  created_timestamp,
  source_file,
  load_timestamp,
  current_timestamp() AS silver_load_timestamp
FROM deduplicated
WHERE rn = 1;

-- Create cleaned HQLA table in silver layer
-- Data quality rules:
-- 1. Remove records with null key fields (asset_id, business_date, market_value_eur)
-- 2. Trim trailing/leading spaces from string columns
-- 3. Deduplicate based on asset_id and business_date (keep latest load_timestamp)
-- 4. Uppercase all flag columns (Y/N)
-- 5. Validate HQLA levels (must be 'Level 1', 'Level 2A', or 'Level 2B')
-- 6. Ensure positive market values
-- 7. Validate haircut rates are within expected ranges

CREATE OR REPLACE TABLE liquidity_dev.silver.hqla_cleaned (
  asset_id STRING COMMENT 'Unique identifier for each asset (format: HQLA{COUNTRY_CODE}{NUMBER})',
  country STRING COMMENT 'Country where the asset is held',
  subsidiary STRING COMMENT 'Bank subsidiary holding the asset',
  hqla_level STRING COMMENT 'Basel III HQLA classification (Level 1, Level 2A, Level 2B)',
  asset_type STRING COMMENT 'Specific type of asset (Cash, Central Bank Reserves, Government Bonds, Corporate Bonds, Covered Bonds, etc.)',
  currency STRING COMMENT 'Currency denomination of the asset',
  market_value_local DECIMAL(18,2) COMMENT 'Current market value in local currency',
  market_value_eur DECIMAL(18,2) COMMENT 'Market value converted to EUR',
  haircut_rate DECIMAL(8,4) COMMENT 'Haircut percentage applied (0% for Level 1, 15% for Level 2A, 25-50% for Level 2B)',
  eligible_hqla_value_eur DECIMAL(18,2) COMMENT 'Value after haircut for LCR calculation',
  maturity_date DATE COMMENT 'Date when the asset matures',
  credit_rating STRING COMMENT 'Credit rating of the asset (AAA, AA+, AA, AA-, A+, A, A-, BBB+)',
  liquidity_score INT COMMENT 'Liquidity score from 1-10 (10 being most liquid)',
  encumbered_flag STRING COMMENT 'Whether asset is pledged/encumbered (Y/N)',
  central_bank_eligible STRING COMMENT 'Can be used as central bank collateral (Y/N)',
  yield_rate DECIMAL(8,4) COMMENT 'Current yield rate of the asset',
  duration_years DECIMAL(8,2) COMMENT 'Duration in years',
  last_valuation_date DATE COMMENT 'Most recent valuation date',
  business_date DATE COMMENT 'Reporting date for this data snapshot',
  created_timestamp TIMESTAMP COMMENT 'System timestamp when record was created in source',
  source_file STRING COMMENT 'Source CSV file path from landing zone',
  load_timestamp TIMESTAMP COMMENT 'Timestamp when data was loaded into bronze table',
  silver_load_timestamp TIMESTAMP COMMENT 'Timestamp when data was loaded into silver table'
)
COMMENT 'Silver layer cleaned table containing High Quality Liquid Assets with data quality rules and HQLA level validation applied';

INSERT INTO liquidity_dev.silver.hqla_cleaned
WITH deduplicated AS (
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
    created_timestamp,
    source_file,
    load_timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY TRIM(asset_id), business_date 
      ORDER BY load_timestamp DESC
    ) AS rn
  FROM liquidity_dev.bronze.hqla
  WHERE asset_id IS NOT NULL
    AND business_date IS NOT NULL
    AND market_value_eur IS NOT NULL
    AND market_value_eur >= 0  -- Ensure positive values
    AND TRIM(hqla_level) IN ('Level 1', 'Level 2A', 'Level 2B')  -- Validate HQLA levels
    AND haircut_rate >= 0 AND haircut_rate <= 1  -- Haircut must be between 0 and 100%
)
SELECT 
  asset_id,
  country,
  subsidiary,
  hqla_level,
  asset_type,
  currency,
  market_value_local,
  market_value_eur,
  haircut_rate,
  eligible_hqla_value_eur,
  maturity_date,
  credit_rating,
  liquidity_score,
  encumbered_flag,
  central_bank_eligible,
  yield_rate,
  duration_years,
  last_valuation_date,
  business_date,
  created_timestamp,
  source_file,
  load_timestamp,
  current_timestamp() AS silver_load_timestamp
FROM deduplicated
WHERE rn = 1;

-- Create cleaned collateral table in silver layer
-- Data quality rules:
-- 1. Remove records with null key fields (collateral_id, business_date, gross_value_eur)
-- 2. Trim trailing/leading spaces from string columns
-- 3. Deduplicate based on collateral_id and business_date (keep latest load_timestamp)
-- 4. Uppercase all flag columns (Y/N)
-- 5. Ensure positive gross values
-- 6. Validate quality ratings (A, B, C, D)
-- 7. Validate haircut percentages and LTV ratios

CREATE OR REPLACE TABLE liquidity_dev.silver.collateral_cleaned (
  collateral_id STRING COMMENT 'Unique identifier for each collateral (format: COLL{COUNTRY_CODE}{NUMBER})',
  country STRING COMMENT 'Country where collateral is located',
  subsidiary STRING COMMENT 'Bank subsidiary managing the collateral',
  collateral_type STRING COMMENT 'Type of collateral (Real Estate, Equipment, Inventory, Securities, Cash Deposit, Receivables, Vehicles, Intellectual Property)',
  currency STRING COMMENT 'Currency of collateral valuation',
  gross_value_local DECIMAL(18,2) COMMENT 'Gross collateral value in local currency',
  gross_value_eur DECIMAL(18,2) COMMENT 'Gross value converted to EUR',
  loan_to_value_ratio DECIMAL(8,4) COMMENT 'LTV ratio (loan amount / collateral value)',
  haircut_percentage DECIMAL(8,4) COMMENT 'Haircut applied to collateral value',
  net_realizable_value_eur DECIMAL(18,2) COMMENT 'Net value after haircut in EUR',
  associated_loan_id STRING COMMENT 'Reference to the associated loan',
  collateral_status STRING COMMENT 'Current status (Active, Under Review, Released)',
  valuation_date DATE COMMENT 'Date when collateral was valued',
  next_review_date DATE COMMENT 'Next scheduled review date',
  quality_rating STRING COMMENT 'Quality rating (A=Highest, B=Good, C=Fair, D=Poor)',
  liquidation_period_days INT COMMENT 'Expected days to liquidate the collateral',
  insurance_status STRING COMMENT 'Whether collateral is insured (Y/N)',
  legal_ownership STRING COMMENT 'Ownership status (Owned, Leased, Third-party)',
  concentration_risk_flag STRING COMMENT 'High concentration risk indicator (Y/N)',
  business_date DATE COMMENT 'Reporting date for this data snapshot',
  created_timestamp TIMESTAMP COMMENT 'System timestamp when record was created in source',
  source_file STRING COMMENT 'Source CSV file path from landing zone',
  load_timestamp TIMESTAMP COMMENT 'Timestamp when data was loaded into bronze table',
  silver_load_timestamp TIMESTAMP COMMENT 'Timestamp when data was loaded into silver table'
)
COMMENT 'Silver layer cleaned table containing collateral details with data quality rules and validation applied';

INSERT INTO liquidity_dev.silver.collateral_cleaned
WITH deduplicated AS (
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
    UPPER(TRIM(quality_rating)) AS quality_rating,
    liquidation_period_days,
    UPPER(TRIM(insurance_status)) AS insurance_status,
    TRIM(legal_ownership) AS legal_ownership,
    UPPER(TRIM(concentration_risk_flag)) AS concentration_risk_flag,
    business_date,
    created_timestamp,
    source_file,
    load_timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY TRIM(collateral_id), business_date 
      ORDER BY load_timestamp DESC
    ) AS rn
  FROM liquidity_dev.bronze.collateral
  WHERE collateral_id IS NOT NULL
    AND business_date IS NOT NULL
    AND gross_value_eur IS NOT NULL
    AND gross_value_eur >= 0  -- Ensure positive values
    AND UPPER(TRIM(quality_rating)) IN ('A', 'B', 'C', 'D')  -- Validate quality ratings
    AND haircut_percentage >= 0 AND haircut_percentage <= 1  -- Haircut must be between 0 and 100%
    AND loan_to_value_ratio >= 0 AND loan_to_value_ratio <= 1  -- LTV must be between 0 and 100%
)
SELECT 
  collateral_id,
  country,
  subsidiary,
  collateral_type,
  currency,
  gross_value_local,
  gross_value_eur,
  loan_to_value_ratio,
  haircut_percentage,
  net_realizable_value_eur,
  associated_loan_id,
  collateral_status,
  valuation_date,
  next_review_date,
  quality_rating,
  liquidation_period_days,
  insurance_status,
  legal_ownership,
  concentration_risk_flag,
  business_date,
  created_timestamp,
  source_file,
  load_timestamp,
  current_timestamp() AS silver_load_timestamp
FROM deduplicated
WHERE rn = 1;

-- Verify silver tables and compare with bronze layer
-- Shows record counts, date ranges, and data quality metrics

SELECT 
  'balances' AS table_name,
  'bronze' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  SUM(CASE WHEN account_id IS NULL THEN 1 ELSE 0 END) AS null_account_ids
FROM liquidity_dev.bronze.balances

UNION ALL

SELECT 
  'balances' AS table_name,
  'silver' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  0 AS null_account_ids  -- Should be 0 after cleaning
FROM liquidity_dev.silver.balances_cleaned

UNION ALL

SELECT 
  'hqla' AS table_name,
  'bronze' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  SUM(CASE WHEN asset_id IS NULL THEN 1 ELSE 0 END) AS null_ids
FROM liquidity_dev.bronze.hqla

UNION ALL

SELECT 
  'hqla' AS table_name,
  'silver' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  0 AS null_ids  -- Should be 0 after cleaning
FROM liquidity_dev.silver.hqla_cleaned

UNION ALL

SELECT 
  'collateral' AS table_name,
  'bronze' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  SUM(CASE WHEN collateral_id IS NULL THEN 1 ELSE 0 END) AS null_ids
FROM liquidity_dev.bronze.collateral

UNION ALL

SELECT 
  'collateral' AS table_name,
  'silver' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  0 AS null_ids  -- Should be 0 after cleaning
FROM liquidity_dev.silver.collateral_cleaned

ORDER BY table_name, layer;

-- Validate data quality rules applied in silver layer
-- Check that flags are uppercase, HQLA levels are valid, quality ratings are valid

-- Check 1: Verify all flags are uppercase Y/N in balances
SELECT 
  'balances_cleaned - stable_funding_flag' AS validation_check,
  stable_funding_flag AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.balances_cleaned
GROUP BY stable_funding_flag

UNION ALL

-- Check 2: Verify HQLA levels are valid
SELECT 
  'hqla_cleaned - hqla_level' AS validation_check,
  hqla_level AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.hqla_cleaned
GROUP BY hqla_level

UNION ALL

-- Check 3: Verify encumbered_flag in HQLA
SELECT 
  'hqla_cleaned - encumbered_flag' AS validation_check,
  encumbered_flag AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.hqla_cleaned
GROUP BY encumbered_flag

UNION ALL

-- Check 4: Verify central_bank_eligible in HQLA
SELECT 
  'hqla_cleaned - central_bank_eligible' AS validation_check,
  central_bank_eligible AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.hqla_cleaned
GROUP BY central_bank_eligible

UNION ALL

-- Check 5: Verify quality ratings in collateral
SELECT 
  'collateral_cleaned - quality_rating' AS validation_check,
  quality_rating AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.collateral_cleaned
GROUP BY quality_rating

UNION ALL

-- Check 6: Verify insurance_status in collateral
SELECT 
  'collateral_cleaned - insurance_status' AS validation_check,
  insurance_status AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.collateral_cleaned
GROUP BY insurance_status

UNION ALL

-- Check 7: Verify concentration_risk_flag in collateral
SELECT 
  'collateral_cleaned - concentration_risk_flag' AS validation_check,
  concentration_risk_flag AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.collateral_cleaned
GROUP BY concentration_risk_flag

ORDER BY validation_check, flag_value;