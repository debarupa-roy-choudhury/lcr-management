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
