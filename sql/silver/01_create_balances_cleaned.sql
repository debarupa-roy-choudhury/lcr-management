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
--   Execute all files in sql/silver/ in filename order

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
