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
