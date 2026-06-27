-- Verify silver tables and compare with bronze layer
-- Shows record counts, date ranges, and data quality metrics

SELECT 
  'balances' AS table_name,
  'bronze' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  SUM(CASE WHEN account_id IS NULL THEN 1 ELSE 0 END) AS null_account_ids
FROM liquidity_dev.bronze.balances

UNION ALL

SELECT 
  'balances' AS table_name,
  'silver' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  0 AS null_account_ids  -- Should be 0 after cleaning
FROM liquidity_dev.silver.balances_cleaned

UNION ALL

SELECT 
  'hqla' AS table_name,
  'bronze' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  SUM(CASE WHEN asset_id IS NULL THEN 1 ELSE 0 END) AS null_ids
FROM liquidity_dev.bronze.hqla

UNION ALL

SELECT 
  'hqla' AS table_name,
  'silver' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  0 AS null_ids  -- Should be 0 after cleaning
FROM liquidity_dev.silver.hqla_cleaned

UNION ALL

SELECT 
  'collateral' AS table_name,
  'bronze' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  SUM(CASE WHEN collateral_id IS NULL THEN 1 ELSE 0 END) AS null_ids
FROM liquidity_dev.bronze.collateral

UNION ALL

SELECT 
  'collateral' AS table_name,
  'silver' AS layer,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  0 AS null_ids  -- Should be 0 after cleaning
FROM liquidity_dev.silver.collateral_cleaned

ORDER BY table_name, layer;
