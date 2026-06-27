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
