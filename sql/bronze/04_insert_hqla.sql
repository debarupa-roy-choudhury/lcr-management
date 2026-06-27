INSERT INTO liquidity_dev.bronze.hqla
SELECT 
  asset_id,
  country,
  subsidiary,
  hqla_level,
  asset_type,
  currency,
  CAST(market_value_local AS DECIMAL(18,2)) AS market_value_local,
  CAST(market_value_eur AS DECIMAL(18,2)) AS market_value_eur,
  CAST(haircut_rate AS DECIMAL(8,4)) AS haircut_rate,
  CAST(eligible_hqla_value_eur AS DECIMAL(18,2)) AS eligible_hqla_value_eur,
  CAST(maturity_date AS DATE) AS maturity_date,
  credit_rating,
  CAST(liquidity_score AS INT) AS liquidity_score,
  encumbered_flag,
  central_bank_eligible,
  CAST(yield_rate AS DECIMAL(8,4)) AS yield_rate,
  CAST(duration_years AS DECIMAL(8,2)) AS duration_years,
  CAST(last_valuation_date AS DATE) AS last_valuation_date,
  CAST(business_date AS DATE) AS business_date,
  CAST(created_timestamp AS TIMESTAMP) AS created_timestamp,
  input_file_name() AS source_file,
  current_timestamp() AS load_timestamp
FROM read_files(
  '/Volumes/liquidity_dev/bronze/landing_zone/hqla/',
  format => 'csv',
  header => true,
  recursiveFileLookup => true,
  pathGlobFilter => '*.csv'
);
