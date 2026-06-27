-- Create Funding Stability Fact Table
-- Business Question: How stable is our funding base by maturity and customer segment?
-- Helps assess funding risk and maturity concentration

CREATE OR REPLACE TABLE liquidity_dev.gold.fact_funding_stability (
  funding_stability_key BIGINT COMMENT 'Primary key - surrogate key',
  date_key INT COMMENT 'Foreign key to dim_date',
  country_key INT COMMENT 'Foreign key to dim_country',
  subsidiary_key INT COMMENT 'Foreign key to dim_subsidiary',
  
  maturity_bucket STRING COMMENT 'Maturity classification',
  customer_segment STRING COMMENT 'Customer segment',
  account_type STRING COMMENT 'Account type',
  
  account_count INT COMMENT 'Number of accounts',
  total_balance_eur DECIMAL(20,2) COMMENT 'Total balance',
  average_balance_eur DECIMAL(20,2) COMMENT 'Average balance per account',
  stable_funding_balance_eur DECIMAL(20,2) COMMENT 'Balance flagged as stable',
  unstable_funding_balance_eur DECIMAL(20,2) COMMENT 'Balance flagged as unstable',
  weighted_outflow_amount DECIMAL(20,2) COMMENT 'Expected outflow amount',
  average_outflow_rate DECIMAL(8,4) COMMENT 'Average weighted outflow rate',
  
  high_volatility_balance_eur DECIMAL(20,2) COMMENT 'Balance with high volatility',
  medium_volatility_balance_eur DECIMAL(20,2) COMMENT 'Balance with medium volatility',
  low_volatility_balance_eur DECIMAL(20,2) COMMENT 'Balance with low volatility',
  
  inactive_account_count INT COMMENT 'Accounts with no activity in last 30 days',
  inactive_balance_eur DECIMAL(20,2) COMMENT 'Balance in inactive accounts',
  
  stable_funding_ratio DECIMAL(8,4) COMMENT 'Ratio of stable to total funding',
  concentration_percentage DECIMAL(8,4) COMMENT 'Percentage of total funding',
  
  load_timestamp TIMESTAMP COMMENT 'Record load timestamp',
  
  CONSTRAINT pk_fact_funding_stability PRIMARY KEY (funding_stability_key),
  CONSTRAINT fk_funding_date FOREIGN KEY (date_key) REFERENCES liquidity_dev.gold.dim_date(date_key),
  CONSTRAINT fk_funding_country FOREIGN KEY (country_key) REFERENCES liquidity_dev.gold.dim_country(country_key),
  CONSTRAINT fk_funding_subsidiary FOREIGN KEY (subsidiary_key) REFERENCES liquidity_dev.gold.dim_subsidiary(subsidiary_key)
)
COMMENT 'Funding stability fact table for analyzing funding sources by maturity, customer segment, and volatility';
