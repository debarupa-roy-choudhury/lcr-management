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
