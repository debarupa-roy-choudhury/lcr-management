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
