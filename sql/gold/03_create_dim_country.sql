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
