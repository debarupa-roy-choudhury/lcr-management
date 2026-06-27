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
