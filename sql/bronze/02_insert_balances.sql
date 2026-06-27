INSERT INTO liquidity_dev.bronze.balances
SELECT 
  account_id,
  country,
  subsidiary,
  account_type,
  currency,
  CAST(balance_local AS DECIMAL(18,2)) AS balance_local,
  CAST(balance_eur AS DECIMAL(18,2)) AS balance_eur,
  customer_segment,
  maturity_bucket,
  CAST(weighted_outflow_rate AS DECIMAL(8,4)) AS weighted_outflow_rate,
  stable_funding_flag,
  CAST(last_transaction_date AS DATE) AS last_transaction_date,
  CAST(average_balance_30d AS DECIMAL(18,2)) AS average_balance_30d,
  balance_volatility,
  CAST(business_date AS DATE) AS business_date,
  CAST(created_timestamp AS TIMESTAMP) AS created_timestamp,
  input_file_name() AS source_file,
  current_timestamp() AS load_timestamp
FROM read_files(
  '/Volumes/liquidity_dev/bronze/landing_zone/balances/',
  format => 'csv',
  header => true,
  recursiveFileLookup => true,
  pathGlobFilter => '*.csv'
);
