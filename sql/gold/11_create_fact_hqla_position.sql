-- Create HQLA Position Fact Table
-- Business Question: What is our HQLA composition by level, country, and asset type?
-- Helps understand asset quality distribution and diversification

CREATE OR REPLACE TABLE liquidity_dev.gold.fact_hqla_position (
  hqla_position_key BIGINT COMMENT 'Primary key - surrogate key',
  date_key INT COMMENT 'Foreign key to dim_date',
  country_key INT COMMENT 'Foreign key to dim_country',
  subsidiary_key INT COMMENT 'Foreign key to dim_subsidiary',
  
  hqla_level STRING COMMENT 'HQLA classification level',
  asset_type STRING COMMENT 'Type of HQLA asset',
  credit_rating STRING COMMENT 'Credit rating bucket',
  
  asset_count INT COMMENT 'Number of assets',
  total_market_value_eur DECIMAL(20,2) COMMENT 'Total market value',
  total_eligible_value_eur DECIMAL(20,2) COMMENT 'Total value after haircuts',
  average_haircut_rate DECIMAL(8,4) COMMENT 'Average haircut rate applied',
  average_yield_rate DECIMAL(8,4) COMMENT 'Average yield rate',
  average_liquidity_score DECIMAL(5,2) COMMENT 'Average liquidity score (1-10)',
  encumbered_value_eur DECIMAL(20,2) COMMENT 'Value of encumbered assets',
  unencumbered_value_eur DECIMAL(20,2) COMMENT 'Value of unencumbered assets',
  central_bank_eligible_value_eur DECIMAL(20,2) COMMENT 'Value eligible for central bank operations',
  
  concentration_percentage DECIMAL(8,4) COMMENT 'Percentage of total HQLA portfolio',
  
  load_timestamp TIMESTAMP COMMENT 'Record load timestamp',
  
  CONSTRAINT pk_fact_hqla_position PRIMARY KEY (hqla_position_key),
  CONSTRAINT fk_hqla_date FOREIGN KEY (date_key) REFERENCES liquidity_dev.gold.dim_date(date_key),
  CONSTRAINT fk_hqla_country FOREIGN KEY (country_key) REFERENCES liquidity_dev.gold.dim_country(country_key),
  CONSTRAINT fk_hqla_subsidiary FOREIGN KEY (subsidiary_key) REFERENCES liquidity_dev.gold.dim_subsidiary(subsidiary_key)
)
COMMENT 'HQLA position fact table for analyzing asset quality, composition, and concentration by level and type';
