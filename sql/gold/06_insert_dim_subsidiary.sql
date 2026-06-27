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
