-- Verify tables were created and show summary statistics

SELECT 
  'balances' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  ROUND(SUM(balance_eur), 2) AS total_balance_eur
FROM liquidity_dev.bronze.balances

UNION ALL

SELECT 
  'hqla' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  ROUND(SUM(eligible_hqla_value_eur), 2) AS total_value_eur
FROM liquidity_dev.bronze.hqla

UNION ALL

SELECT 
  'collateral' AS table_name,
  COUNT(*) AS record_count,
  COUNT(DISTINCT business_date) AS distinct_dates,
  MIN(business_date) AS earliest_date,
  MAX(business_date) AS latest_date,
  COUNT(DISTINCT country) AS distinct_countries,
  ROUND(SUM(net_realizable_value_eur), 2) AS total_value_eur
FROM liquidity_dev.bronze.collateral

ORDER BY table_name;
