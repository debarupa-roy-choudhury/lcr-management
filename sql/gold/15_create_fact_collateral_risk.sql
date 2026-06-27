-- Create Collateral Risk Fact Table
-- Business Question: What is our collateral quality and concentration risk exposure?
-- Helps identify collateral quality issues and concentration risks

CREATE OR REPLACE TABLE liquidity_dev.gold.fact_collateral_risk (
  collateral_risk_key BIGINT COMMENT 'Primary key - surrogate key',
  date_key INT COMMENT 'Foreign key to dim_date',
  country_key INT COMMENT 'Foreign key to dim_country',
  subsidiary_key INT COMMENT 'Foreign key to dim_subsidiary',
  
  collateral_type STRING COMMENT 'Type of collateral',
  quality_rating STRING COMMENT 'Quality rating (A, B, C, D)',
  collateral_status STRING COMMENT 'Collateral status',
  
  collateral_count INT COMMENT 'Number of collateral items',
  total_gross_value_eur DECIMAL(20,2) COMMENT 'Total gross value',
  total_net_value_eur DECIMAL(20,2) COMMENT 'Total net realizable value',
  average_haircut_percentage DECIMAL(8,4) COMMENT 'Average haircut applied',
  average_ltv_ratio DECIMAL(8,4) COMMENT 'Average loan-to-value ratio',
  average_liquidation_days DECIMAL(10,2) COMMENT 'Average liquidation period',
  
  high_concentration_value_eur DECIMAL(20,2) COMMENT 'Value with concentration risk flag',
  insured_value_eur DECIMAL(20,2) COMMENT 'Insured collateral value',
  uninsured_value_eur DECIMAL(20,2) COMMENT 'Uninsured collateral value',
  
  active_collateral_value_eur DECIMAL(20,2) COMMENT 'Active collateral value',
  under_review_value_eur DECIMAL(20,2) COMMENT 'Collateral under review',
  
  overdue_review_count INT COMMENT 'Number of items with overdue reviews',
  overdue_review_value_eur DECIMAL(20,2) COMMENT 'Value of collateral with overdue reviews',
  
  concentration_percentage DECIMAL(8,4) COMMENT 'Percentage of total collateral',
  quality_score DECIMAL(8,4) COMMENT 'Weighted quality score (A=4, B=3, C=2, D=1)',
  
  load_timestamp TIMESTAMP COMMENT 'Record load timestamp',
  
  CONSTRAINT pk_fact_collateral_risk PRIMARY KEY (collateral_risk_key),
  CONSTRAINT fk_collateral_date FOREIGN KEY (date_key) REFERENCES liquidity_dev.gold.dim_date(date_key),
  CONSTRAINT fk_collateral_country FOREIGN KEY (country_key) REFERENCES liquidity_dev.gold.dim_country(country_key),
  CONSTRAINT fk_collateral_subsidiary FOREIGN KEY (subsidiary_key) REFERENCES liquidity_dev.gold.dim_subsidiary(subsidiary_key)
)
COMMENT 'Collateral risk fact table for analyzing collateral quality, concentration, and liquidation risk';
