-- Create Intraday Liquidity Fact Table with LCR Calculation
-- LCR = Total HQLA (after haircuts) / Total Net Cash Outflows over 30 days
-- Basel III requirement: LCR >= 100%

CREATE OR REPLACE TABLE liquidity_dev.gold.fact_intraday_liquidity (
  liquidity_key BIGINT COMMENT 'Primary key - surrogate key',
  date_key INT COMMENT 'Foreign key to dim_date',
  country_key INT COMMENT 'Foreign key to dim_country',
  subsidiary_key INT COMMENT 'Foreign key to dim_subsidiary',
  
  -- Balance metrics
  total_balance_eur DECIMAL(20,2) COMMENT 'Total account balances in EUR',
  total_balance_local DECIMAL(20,2) COMMENT 'Total account balances in local currency',
  account_count INT COMMENT 'Number of accounts',
  
  -- HQLA metrics (numerator for LCR)
  total_hqla_gross_eur DECIMAL(20,2) COMMENT 'Total HQLA market value before haircuts',
  total_hqla_eligible_eur DECIMAL(20,2) COMMENT 'Total HQLA after haircuts (numerator for LCR)',
  hqla_level1_eur DECIMAL(20,2) COMMENT 'Level 1 HQLA value (0% haircut)',
  hqla_level2a_eur DECIMAL(20,2) COMMENT 'Level 2A HQLA value (15% haircut)',
  hqla_level2b_eur DECIMAL(20,2) COMMENT 'Level 2B HQLA value (25-50% haircut)',
  hqla_unencumbered_eur DECIMAL(20,2) COMMENT 'Unencumbered HQLA available for use',
  
  -- Cash outflow metrics (denominator for LCR)
  total_cash_outflows_30d DECIMAL(20,2) COMMENT 'Expected cash outflows over next 30 days',
  weighted_outflow_amount DECIMAL(20,2) COMMENT 'Balance * weighted outflow rate',
  stable_funding_amount DECIMAL(20,2) COMMENT 'Stable funding sources',
  unstable_funding_amount DECIMAL(20,2) COMMENT 'Unstable funding sources',
  
  -- Collateral metrics
  total_collateral_gross_eur DECIMAL(20,2) COMMENT 'Total collateral gross value',
  total_collateral_net_eur DECIMAL(20,2) COMMENT 'Total collateral net realizable value',
  high_quality_collateral_eur DECIMAL(20,2) COMMENT 'Collateral rated A or B',
  
  -- LCR Calculation
  liquidity_coverage_ratio DECIMAL(10,4) COMMENT 'LCR = Total HQLA / Total Net Cash Outflows (target >= 1.0 or 100%)',
  lcr_surplus_deficit_eur DECIMAL(20,2) COMMENT 'HQLA surplus/deficit to meet 100% LCR requirement',
  lcr_status STRING COMMENT 'Compliance status (Compliant, At Risk, Non-Compliant)',
  
  -- Metadata
  load_timestamp TIMESTAMP COMMENT 'Record load timestamp',
  
  CONSTRAINT pk_fact_intraday_liquidity PRIMARY KEY (liquidity_key),
  CONSTRAINT fk_liquidity_date FOREIGN KEY (date_key) REFERENCES liquidity_dev.gold.dim_date(date_key),
  CONSTRAINT fk_liquidity_country FOREIGN KEY (country_key) REFERENCES liquidity_dev.gold.dim_country(country_key),
  CONSTRAINT fk_liquidity_subsidiary FOREIGN KEY (subsidiary_key) REFERENCES liquidity_dev.gold.dim_subsidiary(subsidiary_key)
)
COMMENT 'Intraday liquidity fact table with Liquidity Coverage Ratio (LCR) calculations aggregated by date, country, and subsidiary';
