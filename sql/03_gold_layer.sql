-- ============================================================================
-- Gold Layer - Dimensional Model for LCR Analytics
-- ============================================================================
-- Creates star schema with dimensions and fact tables
--
-- Dimensions:
-- * dim_date - Date dimension for time-based analysis
-- * dim_country - Country attributes and risk profiles
-- * dim_subsidiary - Bank subsidiary information
-- * dim_account - Account attributes (SCD Type 2)
--
-- Facts:
-- * fact_intraday_liquidity - LCR calculation by country/date
-- * fact_hqla_position - HQLA asset composition
-- * fact_funding_stability - Funding maturity and stability
-- * fact_collateral_risk - Collateral quality and concentration
--
-- Usage:
--   databricks sql execute --file sql/03_gold_layer.sql

-- Create Date Dimension
-- Primary dimension for time-based analysis across all facts

CREATE OR REPLACE TABLE liquidity_dev.gold.dim_date (
  date_key INT COMMENT 'Primary key - date in YYYYMMDD format',
  business_date DATE COMMENT 'Actual calendar date',
  year INT COMMENT 'Year (YYYY)',
  quarter INT COMMENT 'Quarter (1-4)',
  month INT COMMENT 'Month (1-12)',
  month_name STRING COMMENT 'Month name (January, February, etc.)',
  day_of_month INT COMMENT 'Day of month (1-31)',
  day_of_week INT COMMENT 'Day of week (1=Monday, 7=Sunday)',
  day_name STRING COMMENT 'Day name (Monday, Tuesday, etc.)',
  week_of_year INT COMMENT 'Week number of the year (1-53)',
  is_weekend STRING COMMENT 'Weekend flag (Y/N)',
  is_month_end STRING COMMENT 'Month-end flag (Y/N)',
  is_quarter_end STRING COMMENT 'Quarter-end flag (Y/N)',
  is_year_end STRING COMMENT 'Year-end flag (Y/N)',
  fiscal_year INT COMMENT 'Fiscal year',
  fiscal_quarter INT COMMENT 'Fiscal quarter',
  CONSTRAINT pk_dim_date PRIMARY KEY (date_key)
)
COMMENT 'Date dimension for time-based analysis across liquidity metrics';

INSERT INTO liquidity_dev.gold.dim_date
WITH all_dates AS (
  SELECT DISTINCT business_date FROM liquidity_dev.silver.balances_cleaned
  UNION
  SELECT DISTINCT business_date FROM liquidity_dev.silver.hqla_cleaned
  UNION
  SELECT DISTINCT business_date FROM liquidity_dev.silver.collateral_cleaned
)
SELECT
  CAST(DATE_FORMAT(business_date, 'yyyyMMdd') AS INT) AS date_key,
  business_date,
  YEAR(business_date) AS year,
  QUARTER(business_date) AS quarter,
  MONTH(business_date) AS month,
  DATE_FORMAT(business_date, 'MMMM') AS month_name,
  DAY(business_date) AS day_of_month,
  DAYOFWEEK(business_date) AS day_of_week,
  DATE_FORMAT(business_date, 'EEEE') AS day_name,
  WEEKOFYEAR(business_date) AS week_of_year,
  CASE WHEN DAYOFWEEK(business_date) IN (1, 7) THEN 'Y' ELSE 'N' END AS is_weekend,
  CASE WHEN business_date = LAST_DAY(business_date) THEN 'Y' ELSE 'N' END AS is_month_end,
  CASE WHEN MONTH(business_date) IN (3, 6, 9, 12) AND business_date = LAST_DAY(business_date) THEN 'Y' ELSE 'N' END AS is_quarter_end,
  CASE WHEN MONTH(business_date) = 12 AND business_date = LAST_DAY(business_date) THEN 'Y' ELSE 'N' END AS is_year_end,
  YEAR(business_date) AS fiscal_year,
  QUARTER(business_date) AS fiscal_quarter
FROM all_dates;

-- Create Country Dimension
-- Contains country-level attributes for geographic analysis

CREATE OR REPLACE TABLE liquidity_dev.gold.dim_country (
  country_key INT COMMENT 'Primary key - surrogate key for country',
  country_name STRING COMMENT 'Country name',
  country_code STRING COMMENT 'ISO 3-letter country code',
  region STRING COMMENT 'Geographic region (Western Europe, Northern Europe, Southern Europe, Eastern Europe)',
  currency STRING COMMENT 'Primary currency used in the country',
  is_eurozone STRING COMMENT 'Eurozone member flag (Y/N)',
  liquidity_risk_category STRING COMMENT 'Assigned liquidity risk category (Low, Medium, High)',
  CONSTRAINT pk_dim_country PRIMARY KEY (country_key)
)
COMMENT 'Country dimension for geographic analysis of liquidity positions';

INSERT INTO liquidity_dev.gold.dim_country
WITH country_list AS (
  SELECT DISTINCT country FROM liquidity_dev.silver.balances_cleaned
  UNION
  SELECT DISTINCT country FROM liquidity_dev.silver.hqla_cleaned
  UNION
  SELECT DISTINCT country FROM liquidity_dev.silver.collateral_cleaned
)
SELECT
  ROW_NUMBER() OVER (ORDER BY country) AS country_key,
  country AS country_name,
  CASE country
    WHEN 'Germany' THEN 'DEU'
    WHEN 'France' THEN 'FRA'
    WHEN 'United Kingdom' THEN 'GBR'
    WHEN 'Switzerland' THEN 'CHE'
    WHEN 'Italy' THEN 'ITA'
    WHEN 'Spain' THEN 'ESP'
    WHEN 'Poland' THEN 'POL'
    WHEN 'Sweden' THEN 'SWE'
    ELSE 'UNK'
  END AS country_code,
  CASE 
    WHEN country IN ('Germany', 'France', 'Switzerland') THEN 'Western Europe'
    WHEN country IN ('Sweden') THEN 'Northern Europe'
    WHEN country IN ('Italy', 'Spain') THEN 'Southern Europe'
    WHEN country IN ('Poland') THEN 'Eastern Europe'
    WHEN country IN ('United Kingdom') THEN 'Western Europe'
    ELSE 'Other'
  END AS region,
  CASE country
    WHEN 'Germany' THEN 'EUR'
    WHEN 'France' THEN 'EUR'
    WHEN 'United Kingdom' THEN 'GBP'
    WHEN 'Switzerland' THEN 'CHF'
    WHEN 'Italy' THEN 'EUR'
    WHEN 'Spain' THEN 'EUR'
    WHEN 'Poland' THEN 'PLN'
    WHEN 'Sweden' THEN 'SEK'
    ELSE 'EUR'
  END AS currency,
  CASE 
    WHEN country IN ('Germany', 'France', 'Italy', 'Spain') THEN 'Y'
    ELSE 'N'
  END AS is_eurozone,
  CASE 
    WHEN country IN ('Italy', 'Spain') THEN 'High'
    WHEN country IN ('United Kingdom', 'Poland') THEN 'Medium'
    WHEN country IN ('Germany', 'France', 'Switzerland', 'Sweden') THEN 'Low'
    ELSE 'Unknown'
  END AS liquidity_risk_category
FROM country_list;

-- Create Subsidiary Dimension
-- Contains bank subsidiary attributes for organizational analysis

CREATE OR REPLACE TABLE liquidity_dev.gold.dim_subsidiary (
  subsidiary_key INT COMMENT 'Primary key - surrogate key for subsidiary',
  subsidiary_name STRING COMMENT 'Full subsidiary name',
  country STRING COMMENT 'Country where subsidiary operates',
  subsidiary_type STRING COMMENT 'Type of subsidiary (Retail, Corporate, Investment, Asset Management, Private Banking, etc.)',
  CONSTRAINT pk_dim_subsidiary PRIMARY KEY (subsidiary_key)
)
COMMENT 'Subsidiary dimension for organizational hierarchy analysis';

INSERT INTO liquidity_dev.gold.dim_subsidiary
WITH subsidiary_list AS (
  SELECT DISTINCT subsidiary, country FROM liquidity_dev.silver.balances_cleaned
  UNION
  SELECT DISTINCT subsidiary, country FROM liquidity_dev.silver.hqla_cleaned
  UNION
  SELECT DISTINCT subsidiary, country FROM liquidity_dev.silver.collateral_cleaned
)
SELECT
  ROW_NUMBER() OVER (ORDER BY country, subsidiary) AS subsidiary_key,
  subsidiary AS subsidiary_name,
  country,
  CASE 
    WHEN subsidiary LIKE '%Retail%' OR subsidiary LIKE '%Consumer%' THEN 'Retail Banking'
    WHEN subsidiary LIKE '%Corporate%' OR subsidiary LIKE '%SME%' OR subsidiary LIKE '%Commercial%' THEN 'Corporate Banking'
    WHEN subsidiary LIKE '%Investment%' OR subsidiary LIKE '%Trading%' THEN 'Investment Banking'
    WHEN subsidiary LIKE '%Asset Management%' THEN 'Asset Management'
    WHEN subsidiary LIKE '%Private Banking%' OR subsidiary LIKE '%Wealth%' THEN 'Private Banking'
    WHEN subsidiary LIKE '%Holdings%' THEN 'Holdings'
    WHEN subsidiary LIKE '%Digital%' THEN 'Digital Banking'
    ELSE 'Other'
  END AS subsidiary_type
FROM subsidiary_list;

-- Create Account Dimension
-- Contains account attributes (Type 2 SCD - track changes over time)

CREATE OR REPLACE TABLE liquidity_dev.gold.dim_account (
  account_key INT COMMENT 'Primary key - surrogate key for account',
  account_id STRING COMMENT 'Business key - natural account identifier',
  account_type STRING COMMENT 'Type of account (Current, Savings, Term Deposit, Corporate, Investment, etc.)',
  customer_segment STRING COMMENT 'Customer segment (Retail, Corporate, Institutional)',
  currency STRING COMMENT 'Account currency',
  country STRING COMMENT 'Country where account is held',
  subsidiary STRING COMMENT 'Managing subsidiary',
  effective_date DATE COMMENT 'Effective start date for this version',
  end_date DATE COMMENT 'Effective end date (NULL if current)',
  is_current STRING COMMENT 'Current record flag (Y/N)',
  CONSTRAINT pk_dim_account PRIMARY KEY (account_key)
)
COMMENT 'Account dimension with Type 2 SCD for tracking account attribute changes';

INSERT INTO liquidity_dev.gold.dim_account
WITH latest_accounts AS (
  SELECT 
    account_id,
    account_type,
    customer_segment,
    currency,
    country,
    subsidiary,
    MAX(business_date) AS effective_date
  FROM liquidity_dev.silver.balances_cleaned
  GROUP BY account_id, account_type, customer_segment, currency, country, subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY account_id, effective_date) AS account_key,
  account_id,
  account_type,
  customer_segment,
  currency,
  country,
  subsidiary,
  effective_date,
  NULL AS end_date,
  'Y' AS is_current
FROM latest_accounts;

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

INSERT INTO liquidity_dev.gold.fact_intraday_liquidity
WITH balance_metrics AS (
  SELECT
    b.business_date,
    b.country,
    b.subsidiary,
    SUM(b.balance_eur) AS total_balance_eur,
    SUM(b.balance_local) AS total_balance_local,
    COUNT(DISTINCT b.account_id) AS account_count,
    SUM(b.balance_eur * b.weighted_outflow_rate) AS weighted_outflow_amount,
    SUM(CASE WHEN b.stable_funding_flag = 'Y' THEN b.balance_eur ELSE 0 END) AS stable_funding_amount,
    SUM(CASE WHEN b.stable_funding_flag = 'N' THEN b.balance_eur ELSE 0 END) AS unstable_funding_amount
  FROM liquidity_dev.silver.balances_cleaned b
  GROUP BY b.business_date, b.country, b.subsidiary
),
hqla_metrics AS (
  SELECT
    h.business_date,
    h.country,
    h.subsidiary,
    SUM(h.market_value_eur) AS total_hqla_gross_eur,
    SUM(h.eligible_hqla_value_eur) AS total_hqla_eligible_eur,
    SUM(CASE WHEN h.hqla_level = 'Level 1' THEN h.eligible_hqla_value_eur ELSE 0 END) AS hqla_level1_eur,
    SUM(CASE WHEN h.hqla_level = 'Level 2A' THEN h.eligible_hqla_value_eur ELSE 0 END) AS hqla_level2a_eur,
    SUM(CASE WHEN h.hqla_level = 'Level 2B' THEN h.eligible_hqla_value_eur ELSE 0 END) AS hqla_level2b_eur,
    SUM(CASE WHEN h.encumbered_flag = 'N' THEN h.eligible_hqla_value_eur ELSE 0 END) AS hqla_unencumbered_eur
  FROM liquidity_dev.silver.hqla_cleaned h
  GROUP BY h.business_date, h.country, h.subsidiary
),
collateral_metrics AS (
  SELECT
    c.business_date,
    c.country,
    c.subsidiary,
    SUM(c.gross_value_eur) AS total_collateral_gross_eur,
    SUM(c.net_realizable_value_eur) AS total_collateral_net_eur,
    SUM(CASE WHEN c.quality_rating IN ('A', 'B') THEN c.net_realizable_value_eur ELSE 0 END) AS high_quality_collateral_eur
  FROM liquidity_dev.silver.collateral_cleaned c
  GROUP BY c.business_date, c.country, c.subsidiary
),
combined_metrics AS (
  SELECT
    COALESCE(b.business_date, h.business_date, c.business_date) AS business_date,
    COALESCE(b.country, h.country, c.country) AS country,
    COALESCE(b.subsidiary, h.subsidiary, c.subsidiary) AS subsidiary,
    COALESCE(b.total_balance_eur, 0) AS total_balance_eur,
    COALESCE(b.total_balance_local, 0) AS total_balance_local,
    COALESCE(b.account_count, 0) AS account_count,
    COALESCE(h.total_hqla_gross_eur, 0) AS total_hqla_gross_eur,
    COALESCE(h.total_hqla_eligible_eur, 0) AS total_hqla_eligible_eur,
    COALESCE(h.hqla_level1_eur, 0) AS hqla_level1_eur,
    COALESCE(h.hqla_level2a_eur, 0) AS hqla_level2a_eur,
    COALESCE(h.hqla_level2b_eur, 0) AS hqla_level2b_eur,
    COALESCE(h.hqla_unencumbered_eur, 0) AS hqla_unencumbered_eur,
    COALESCE(b.weighted_outflow_amount, 0) AS weighted_outflow_amount,
    COALESCE(b.stable_funding_amount, 0) AS stable_funding_amount,
    COALESCE(b.unstable_funding_amount, 0) AS unstable_funding_amount,
    COALESCE(c.total_collateral_gross_eur, 0) AS total_collateral_gross_eur,
    COALESCE(c.total_collateral_net_eur, 0) AS total_collateral_net_eur,
    COALESCE(c.high_quality_collateral_eur, 0) AS high_quality_collateral_eur
  FROM balance_metrics b
  FULL OUTER JOIN hqla_metrics h 
    ON b.business_date = h.business_date 
    AND b.country = h.country 
    AND b.subsidiary = h.subsidiary
  FULL OUTER JOIN collateral_metrics c 
    ON COALESCE(b.business_date, h.business_date) = c.business_date 
    AND COALESCE(b.country, h.country) = c.country 
    AND COALESCE(b.subsidiary, h.subsidiary) = c.subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY cm.business_date, cm.country, cm.subsidiary) AS liquidity_key,
  dd.date_key,
  dc.country_key,
  ds.subsidiary_key,
  cm.total_balance_eur,
  cm.total_balance_local,
  cm.account_count,
  cm.total_hqla_gross_eur,
  cm.total_hqla_eligible_eur,
  cm.hqla_level1_eur,
  cm.hqla_level2a_eur,
  cm.hqla_level2b_eur,
  cm.hqla_unencumbered_eur,
  cm.weighted_outflow_amount AS total_cash_outflows_30d,
  cm.weighted_outflow_amount,
  cm.stable_funding_amount,
  cm.unstable_funding_amount,
  cm.total_collateral_gross_eur,
  cm.total_collateral_net_eur,
  cm.high_quality_collateral_eur,
  -- LCR Calculation: HQLA / Net Cash Outflows
  CASE 
    WHEN cm.weighted_outflow_amount > 0 
    THEN ROUND(cm.total_hqla_eligible_eur / cm.weighted_outflow_amount, 4)
    ELSE NULL 
  END AS liquidity_coverage_ratio,
  -- Surplus/Deficit calculation
  CASE 
    WHEN cm.weighted_outflow_amount > 0 
    THEN ROUND(cm.total_hqla_eligible_eur - cm.weighted_outflow_amount, 2)
    ELSE cm.total_hqla_eligible_eur 
  END AS lcr_surplus_deficit_eur,
  -- LCR Status
  CASE 
    WHEN cm.weighted_outflow_amount = 0 THEN 'No Outflows'
    WHEN cm.total_hqla_eligible_eur / cm.weighted_outflow_amount >= 1.0 THEN 'Compliant'
    WHEN cm.total_hqla_eligible_eur / cm.weighted_outflow_amount >= 0.9 THEN 'At Risk'
    ELSE 'Non-Compliant'
  END AS lcr_status,
  current_timestamp() AS load_timestamp
FROM combined_metrics cm
INNER JOIN liquidity_dev.gold.dim_date dd ON CAST(DATE_FORMAT(cm.business_date, 'yyyyMMdd') AS INT) = dd.date_key
INNER JOIN liquidity_dev.gold.dim_country dc ON cm.country = dc.country_name
INNER JOIN liquidity_dev.gold.dim_subsidiary ds ON cm.subsidiary = ds.subsidiary_name AND cm.country = ds.country;

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

INSERT INTO liquidity_dev.gold.fact_hqla_position
WITH hqla_aggregated AS (
  SELECT
    h.business_date,
    h.country,
    h.subsidiary,
    h.hqla_level,
    h.asset_type,
    h.credit_rating,
    COUNT(h.asset_id) AS asset_count,
    SUM(h.market_value_eur) AS total_market_value_eur,
    SUM(h.eligible_hqla_value_eur) AS total_eligible_value_eur,
    AVG(h.haircut_rate) AS average_haircut_rate,
    AVG(h.yield_rate) AS average_yield_rate,
    AVG(h.liquidity_score) AS average_liquidity_score,
    SUM(CASE WHEN h.encumbered_flag = 'Y' THEN h.eligible_hqla_value_eur ELSE 0 END) AS encumbered_value_eur,
    SUM(CASE WHEN h.encumbered_flag = 'N' THEN h.eligible_hqla_value_eur ELSE 0 END) AS unencumbered_value_eur,
    SUM(CASE WHEN h.central_bank_eligible = 'Y' THEN h.eligible_hqla_value_eur ELSE 0 END) AS central_bank_eligible_value_eur
  FROM liquidity_dev.silver.hqla_cleaned h
  GROUP BY h.business_date, h.country, h.subsidiary, h.hqla_level, h.asset_type, h.credit_rating
),
total_hqla AS (
  SELECT
    business_date,
    country,
    subsidiary,
    SUM(total_eligible_value_eur) AS total_portfolio_value
  FROM hqla_aggregated
  GROUP BY business_date, country, subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY ha.business_date, ha.country, ha.subsidiary, ha.hqla_level, ha.asset_type) AS hqla_position_key,
  dd.date_key,
  dc.country_key,
  ds.subsidiary_key,
  ha.hqla_level,
  ha.asset_type,
  ha.credit_rating,
  ha.asset_count,
  ha.total_market_value_eur,
  ha.total_eligible_value_eur,
  ha.average_haircut_rate,
  ha.average_yield_rate,
  ha.average_liquidity_score,
  ha.encumbered_value_eur,
  ha.unencumbered_value_eur,
  ha.central_bank_eligible_value_eur,
  CASE 
    WHEN th.total_portfolio_value > 0 
    THEN ROUND((ha.total_eligible_value_eur / th.total_portfolio_value) * 100, 4)
    ELSE 0 
  END AS concentration_percentage,
  current_timestamp() AS load_timestamp
FROM hqla_aggregated ha
INNER JOIN total_hqla th 
  ON ha.business_date = th.business_date 
  AND ha.country = th.country 
  AND ha.subsidiary = th.subsidiary
INNER JOIN liquidity_dev.gold.dim_date dd ON CAST(DATE_FORMAT(ha.business_date, 'yyyyMMdd') AS INT) = dd.date_key
INNER JOIN liquidity_dev.gold.dim_country dc ON ha.country = dc.country_name
INNER JOIN liquidity_dev.gold.dim_subsidiary ds ON ha.subsidiary = ds.subsidiary_name AND ha.country = ds.country;

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

INSERT INTO liquidity_dev.gold.fact_funding_stability
WITH funding_aggregated AS (
  SELECT
    b.business_date,
    b.country,
    b.subsidiary,
    b.maturity_bucket,
    b.customer_segment,
    b.account_type,
    COUNT(b.account_id) AS account_count,
    SUM(b.balance_eur) AS total_balance_eur,
    AVG(b.balance_eur) AS average_balance_eur,
    SUM(CASE WHEN b.stable_funding_flag = 'Y' THEN b.balance_eur ELSE 0 END) AS stable_funding_balance_eur,
    SUM(CASE WHEN b.stable_funding_flag = 'N' THEN b.balance_eur ELSE 0 END) AS unstable_funding_balance_eur,
    SUM(b.balance_eur * b.weighted_outflow_rate) AS weighted_outflow_amount,
    AVG(b.weighted_outflow_rate) AS average_outflow_rate,
    SUM(CASE WHEN b.balance_volatility = 'High' THEN b.balance_eur ELSE 0 END) AS high_volatility_balance_eur,
    SUM(CASE WHEN b.balance_volatility = 'Medium' THEN b.balance_eur ELSE 0 END) AS medium_volatility_balance_eur,
    SUM(CASE WHEN b.balance_volatility = 'Low' THEN b.balance_eur ELSE 0 END) AS low_volatility_balance_eur,
    SUM(CASE WHEN DATEDIFF(b.business_date, b.last_transaction_date) > 30 THEN 1 ELSE 0 END) AS inactive_account_count,
    SUM(CASE WHEN DATEDIFF(b.business_date, b.last_transaction_date) > 30 THEN b.balance_eur ELSE 0 END) AS inactive_balance_eur
  FROM liquidity_dev.silver.balances_cleaned b
  GROUP BY b.business_date, b.country, b.subsidiary, b.maturity_bucket, b.customer_segment, b.account_type
),
total_funding AS (
  SELECT
    business_date,
    country,
    subsidiary,
    SUM(total_balance_eur) AS total_portfolio_balance
  FROM funding_aggregated
  GROUP BY business_date, country, subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY fa.business_date, fa.country, fa.subsidiary, fa.maturity_bucket, fa.customer_segment) AS funding_stability_key,
  dd.date_key,
  dc.country_key,
  ds.subsidiary_key,
  fa.maturity_bucket,
  fa.customer_segment,
  fa.account_type,
  fa.account_count,
  fa.total_balance_eur,
  fa.average_balance_eur,
  fa.stable_funding_balance_eur,
  fa.unstable_funding_balance_eur,
  fa.weighted_outflow_amount,
  fa.average_outflow_rate,
  fa.high_volatility_balance_eur,
  fa.medium_volatility_balance_eur,
  fa.low_volatility_balance_eur,
  fa.inactive_account_count,
  fa.inactive_balance_eur,
  CASE 
    WHEN fa.total_balance_eur > 0 
    THEN ROUND(fa.stable_funding_balance_eur / fa.total_balance_eur, 4)
    ELSE 0 
  END AS stable_funding_ratio,
  CASE 
    WHEN tf.total_portfolio_balance > 0 
    THEN ROUND((fa.total_balance_eur / tf.total_portfolio_balance) * 100, 4)
    ELSE 0 
  END AS concentration_percentage,
  current_timestamp() AS load_timestamp
FROM funding_aggregated fa
INNER JOIN total_funding tf 
  ON fa.business_date = tf.business_date 
  AND fa.country = tf.country 
  AND fa.subsidiary = tf.subsidiary
INNER JOIN liquidity_dev.gold.dim_date dd ON CAST(DATE_FORMAT(fa.business_date, 'yyyyMMdd') AS INT) = dd.date_key
INNER JOIN liquidity_dev.gold.dim_country dc ON fa.country = dc.country_name
INNER JOIN liquidity_dev.gold.dim_subsidiary ds ON fa.subsidiary = ds.subsidiary_name AND fa.country = ds.country;

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

INSERT INTO liquidity_dev.gold.fact_collateral_risk
WITH collateral_aggregated AS (
  SELECT
    c.business_date,
    c.country,
    c.subsidiary,
    c.collateral_type,
    c.quality_rating,
    c.collateral_status,
    COUNT(c.collateral_id) AS collateral_count,
    SUM(c.gross_value_eur) AS total_gross_value_eur,
    SUM(c.net_realizable_value_eur) AS total_net_value_eur,
    AVG(c.haircut_percentage) AS average_haircut_percentage,
    AVG(c.loan_to_value_ratio) AS average_ltv_ratio,
    AVG(c.liquidation_period_days) AS average_liquidation_days,
    SUM(CASE WHEN c.concentration_risk_flag = 'Y' THEN c.net_realizable_value_eur ELSE 0 END) AS high_concentration_value_eur,
    SUM(CASE WHEN c.insurance_status = 'Y' THEN c.net_realizable_value_eur ELSE 0 END) AS insured_value_eur,
    SUM(CASE WHEN c.insurance_status = 'N' THEN c.net_realizable_value_eur ELSE 0 END) AS uninsured_value_eur,
    SUM(CASE WHEN c.collateral_status = 'Active' THEN c.net_realizable_value_eur ELSE 0 END) AS active_collateral_value_eur,
    SUM(CASE WHEN c.collateral_status = 'Under Review' THEN c.net_realizable_value_eur ELSE 0 END) AS under_review_value_eur,
    SUM(CASE WHEN c.next_review_date < c.business_date THEN 1 ELSE 0 END) AS overdue_review_count,
    SUM(CASE WHEN c.next_review_date < c.business_date THEN c.net_realizable_value_eur ELSE 0 END) AS overdue_review_value_eur,
    AVG(CASE c.quality_rating
      WHEN 'A' THEN 4
      WHEN 'B' THEN 3
      WHEN 'C' THEN 2
      WHEN 'D' THEN 1
      ELSE 0
    END) AS quality_score
  FROM liquidity_dev.silver.collateral_cleaned c
  GROUP BY c.business_date, c.country, c.subsidiary, c.collateral_type, c.quality_rating, c.collateral_status
),
total_collateral AS (
  SELECT
    business_date,
    country,
    subsidiary,
    SUM(total_net_value_eur) AS total_portfolio_value
  FROM collateral_aggregated
  GROUP BY business_date, country, subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY ca.business_date, ca.country, ca.subsidiary, ca.collateral_type, ca.quality_rating) AS collateral_risk_key,
  dd.date_key,
  dc.country_key,
  ds.subsidiary_key,
  ca.collateral_type,
  ca.quality_rating,
  ca.collateral_status,
  ca.collateral_count,
  ca.total_gross_value_eur,
  ca.total_net_value_eur,
  ca.average_haircut_percentage,
  ca.average_ltv_ratio,
  ca.average_liquidation_days,
  ca.high_concentration_value_eur,
  ca.insured_value_eur,
  ca.uninsured_value_eur,
  ca.active_collateral_value_eur,
  ca.under_review_value_eur,
  ca.overdue_review_count,
  ca.overdue_review_value_eur,
  CASE 
    WHEN tc.total_portfolio_value > 0 
    THEN ROUND((ca.total_net_value_eur / tc.total_portfolio_value) * 100, 4)
    ELSE 0 
  END AS concentration_percentage,
  ca.quality_score,
  current_timestamp() AS load_timestamp
FROM collateral_aggregated ca
INNER JOIN total_collateral tc 
  ON ca.business_date = tc.business_date 
  AND ca.country = tc.country 
  AND ca.subsidiary = tc.subsidiary
INNER JOIN liquidity_dev.gold.dim_date dd ON CAST(DATE_FORMAT(ca.business_date, 'yyyyMMdd') AS INT) = dd.date_key
INNER JOIN liquidity_dev.gold.dim_country dc ON ca.country = dc.country_name
INNER JOIN liquidity_dev.gold.dim_subsidiary ds ON ca.subsidiary = ds.subsidiary_name AND ca.country = ds.country;

-- Verify all gold layer tables with summary statistics

SELECT 
  'dim_date' AS table_name,
  'dimension' AS table_type,
  COUNT(*) AS record_count,
  MIN(business_date) AS min_date,
  MAX(business_date) AS max_date,
  NULL AS total_value_eur
FROM liquidity_dev.gold.dim_date

UNION ALL

SELECT 
  'dim_country' AS table_name,
  'dimension' AS table_type,
  COUNT(*) AS record_count,
  NULL AS min_date,
  NULL AS max_date,
  NULL AS total_value_eur
FROM liquidity_dev.gold.dim_country

UNION ALL

SELECT 
  'dim_subsidiary' AS table_name,
  'dimension' AS table_type,
  COUNT(*) AS record_count,
  NULL AS min_date,
  NULL AS max_date,
  NULL AS total_value_eur
FROM liquidity_dev.gold.dim_subsidiary

UNION ALL

SELECT 
  'dim_account' AS table_name,
  'dimension' AS table_type,
  COUNT(*) AS record_count,
  NULL AS min_date,
  NULL AS max_date,
  NULL AS total_value_eur
FROM liquidity_dev.gold.dim_account

UNION ALL

SELECT 
  'fact_intraday_liquidity' AS table_name,
  'fact' AS table_type,
  COUNT(*) AS record_count,
  MIN(dd.business_date) AS min_date,
  MAX(dd.business_date) AS max_date,
  ROUND(SUM(f.total_hqla_eligible_eur), 2) AS total_value_eur
FROM liquidity_dev.gold.fact_intraday_liquidity f
INNER JOIN liquidity_dev.gold.dim_date dd ON f.date_key = dd.date_key

UNION ALL

SELECT 
  'fact_hqla_position' AS table_name,
  'fact' AS table_type,
  COUNT(*) AS record_count,
  MIN(dd.business_date) AS min_date,
  MAX(dd.business_date) AS max_date,
  ROUND(SUM(f.total_eligible_value_eur), 2) AS total_value_eur
FROM liquidity_dev.gold.fact_hqla_position f
INNER JOIN liquidity_dev.gold.dim_date dd ON f.date_key = dd.date_key

UNION ALL

SELECT 
  'fact_funding_stability' AS table_name,
  'fact' AS table_type,
  COUNT(*) AS record_count,
  MIN(dd.business_date) AS min_date,
  MAX(dd.business_date) AS max_date,
  ROUND(SUM(f.total_balance_eur), 2) AS total_value_eur
FROM liquidity_dev.gold.fact_funding_stability f
INNER JOIN liquidity_dev.gold.dim_date dd ON f.date_key = dd.date_key

UNION ALL

SELECT 
  'fact_collateral_risk' AS table_name,
  'fact' AS table_type,
  COUNT(*) AS record_count,
  MIN(dd.business_date) AS min_date,
  MAX(dd.business_date) AS max_date,
  ROUND(SUM(f.total_net_value_eur), 2) AS total_value_eur
FROM liquidity_dev.gold.fact_collateral_risk f
INNER JOIN liquidity_dev.gold.dim_date dd ON f.date_key = dd.date_key

ORDER BY table_type, table_name;