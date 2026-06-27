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
--   Execute all files in sql/gold/ in filename order

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
