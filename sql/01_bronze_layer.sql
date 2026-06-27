-- ============================================================================
-- Bronze Layer - Raw Data Ingestion
-- ============================================================================
-- Creates managed Databricks tables from CSV files in landing zone
-- Delta is the default table format in modern Databricks workspaces
-- Recursively reads all files, maintains full schema with comments
-- Idempotent: Uses CREATE OR REPLACE TABLE
--
-- Usage:
--   databricks sql execute --file sql/01_bronze_layer.sql

-- Create managed table for Balances
-- Recursively reads all CSV files from the landing zone
-- Idempotent: CREATE OR REPLACE TABLE

CREATE OR REPLACE TABLE liquidity_dev.bronze.balances (
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
  created_timestamp TIMESTAMP COMMENT 'System timestamp when record was created',
  source_file STRING COMMENT 'Source CSV file path from landing zone',
  load_timestamp TIMESTAMP COMMENT 'Timestamp when data was loaded into bronze table'
)
COMMENT 'Bronze layer table containing account balance information across countries, subsidiaries, and account types for liquidity analysis';

INSERT INTO liquidity_dev.bronze.balances
SELECT 
  account_id,
  country,
  subsidiary,
  account_type,
  currency,
  CAST(balance_local AS DECIMAL(18,2)) AS balance_local,
  CAST(balance_eur AS DECIMAL(18,2)) AS balance_eur,
  customer_segment,
  maturity_bucket,
  CAST(weighted_outflow_rate AS DECIMAL(8,4)) AS weighted_outflow_rate,
  stable_funding_flag,
  CAST(last_transaction_date AS DATE) AS last_transaction_date,
  CAST(average_balance_30d AS DECIMAL(18,2)) AS average_balance_30d,
  balance_volatility,
  CAST(business_date AS DATE) AS business_date,
  CAST(created_timestamp AS TIMESTAMP) AS created_timestamp,
  input_file_name() AS source_file,
  current_timestamp() AS load_timestamp
FROM read_files(
  '/Volumes/liquidity_dev/bronze/landing_zone/balances/',
  format => 'csv',
  header => true,
  recursiveFileLookup => true,
  pathGlobFilter => '*.csv'
);

-- Create managed table for HQLA (High Quality Liquid Assets)
-- Recursively reads all CSV files from the landing zone
-- Idempotent: CREATE OR REPLACE TABLE

CREATE OR REPLACE TABLE liquidity_dev.bronze.hqla (
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
  created_timestamp TIMESTAMP COMMENT 'System timestamp when record was created',
  source_file STRING COMMENT 'Source CSV file path from landing zone',
  load_timestamp TIMESTAMP COMMENT 'Timestamp when data was loaded into bronze table'
)
COMMENT 'Bronze layer table containing High Quality Liquid Assets (HQLA) details with Basel III classifications for liquidity coverage ratio calculations';

INSERT INTO liquidity_dev.bronze.hqla
SELECT 
  asset_id,
  country,
  subsidiary,
  hqla_level,
  asset_type,
  currency,
  CAST(market_value_local AS DECIMAL(18,2)) AS market_value_local,
  CAST(market_value_eur AS DECIMAL(18,2)) AS market_value_eur,
  CAST(haircut_rate AS DECIMAL(8,4)) AS haircut_rate,
  CAST(eligible_hqla_value_eur AS DECIMAL(18,2)) AS eligible_hqla_value_eur,
  CAST(maturity_date AS DATE) AS maturity_date,
  credit_rating,
  CAST(liquidity_score AS INT) AS liquidity_score,
  encumbered_flag,
  central_bank_eligible,
  CAST(yield_rate AS DECIMAL(8,4)) AS yield_rate,
  CAST(duration_years AS DECIMAL(8,2)) AS duration_years,
  CAST(last_valuation_date AS DATE) AS last_valuation_date,
  CAST(business_date AS DATE) AS business_date,
  CAST(created_timestamp AS TIMESTAMP) AS created_timestamp,
  input_file_name() AS source_file,
  current_timestamp() AS load_timestamp
FROM read_files(
  '/Volumes/liquidity_dev/bronze/landing_zone/hqla/',
  format => 'csv',
  header => true,
  recursiveFileLookup => true,
  pathGlobFilter => '*.csv'
);

-- Create managed table for Collateral
-- Recursively reads all CSV files from the landing zone
-- Idempotent: CREATE OR REPLACE TABLE

CREATE OR REPLACE TABLE liquidity_dev.bronze.collateral (
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
  created_timestamp TIMESTAMP COMMENT 'System timestamp when record was created',
  source_file STRING COMMENT 'Source CSV file path from landing zone',
  load_timestamp TIMESTAMP COMMENT 'Timestamp when data was loaded into bronze table'
)
COMMENT 'Bronze layer table containing collateral details with quality ratings, valuations, and liquidation characteristics';

INSERT INTO liquidity_dev.bronze.collateral
SELECT 
  collateral_id,
  country,
  subsidiary,
  collateral_type,
  currency,
  CAST(gross_value_local AS DECIMAL(18,2)) AS gross_value_local,
  CAST(gross_value_eur AS DECIMAL(18,2)) AS gross_value_eur,
  CAST(loan_to_value_ratio AS DECIMAL(8,4)) AS loan_to_value_ratio,
  CAST(haircut_percentage AS DECIMAL(8,4)) AS haircut_percentage,
  CAST(net_realizable_value_eur AS DECIMAL(18,2)) AS net_realizable_value_eur,
  associated_loan_id,
  collateral_status,
  CAST(valuation_date AS DATE) AS valuation_date,
  CAST(next_review_date AS DATE) AS next_review_date,
  quality_rating,
  CAST(liquidation_period_days AS INT) AS liquidation_period_days,
  insurance_status,
  legal_ownership,
  concentration_risk_flag,
  CAST(business_date AS DATE) AS business_date,
  CAST(created_timestamp AS TIMESTAMP) AS created_timestamp,
  input_file_name() AS source_file,
  current_timestamp() AS load_timestamp
FROM read_files(
  '/Volumes/liquidity_dev/bronze/landing_zone/collateral/',
  format => 'csv',
  header => true,
  recursiveFileLookup => true,
  pathGlobFilter => '*.csv'
);

-- Verify tables were created and show summary statistics

SELECT 
  'balances' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  ROUND(SUM(balance_eur), 2) AS total_balance_eur
FROM liquidity_dev.bronze.balances

UNION ALL

SELECT 
  'hqla' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  ROUND(SUM(eligible_hqla_value_eur), 2) AS total_value_eur
FROM liquidity_dev.bronze.hqla

UNION ALL

SELECT 
  'collateral' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  ROUND(SUM(net_realizable_value_eur), 2) AS total_value_eur
FROM liquidity_dev.bronze.collateral

ORDER BY table_name;

-- View schema for all three bronze tables

DESCRIBE EXTENDED liquidity_dev.bronze.balances;