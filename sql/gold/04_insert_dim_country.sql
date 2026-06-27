INSERT INTO liquidity_dev.gold.dim_country
WITH country_list AS (
  SELECT DISTINCT country FROM liquidity_dev.silver.balances_cleaned
  UNION
  SELECT DISTINCT country FROM liquidity_dev.silver.hqla_cleaned
  UNION
  SELECT DISTINCT country FROM liquidity_dev.silver.collateral_cleaned
)
SELECT
  ROW_NUMBER() OVER (ORDER BY country) AS country_key,
  country AS country_name,
  CASE country
    WHEN 'Germany' THEN 'DEU'
    WHEN 'France' THEN 'FRA'
    WHEN 'United Kingdom' THEN 'GBR'
    WHEN 'Switzerland' THEN 'CHE'
    WHEN 'Italy' THEN 'ITA'
    WHEN 'Spain' THEN 'ESP'
    WHEN 'Poland' THEN 'POL'
    WHEN 'Sweden' THEN 'SWE'
    ELSE 'UNK'
  END AS country_code,
  CASE 
    WHEN country IN ('Germany', 'France', 'Switzerland') THEN 'Western Europe'
    WHEN country IN ('Sweden') THEN 'Northern Europe'
    WHEN country IN ('Italy', 'Spain') THEN 'Southern Europe'
    WHEN country IN ('Poland') THEN 'Eastern Europe'
    WHEN country IN ('United Kingdom') THEN 'Western Europe'
    ELSE 'Other'
  END AS region,
  CASE country
    WHEN 'Germany' THEN 'EUR'
    WHEN 'France' THEN 'EUR'
    WHEN 'United Kingdom' THEN 'GBP'
    WHEN 'Switzerland' THEN 'CHF'
    WHEN 'Italy' THEN 'EUR'
    WHEN 'Spain' THEN 'EUR'
    WHEN 'Poland' THEN 'PLN'
    WHEN 'Sweden' THEN 'SEK'
    ELSE 'EUR'
  END AS currency,
  CASE 
    WHEN country IN ('Germany', 'France', 'Italy', 'Spain') THEN 'Y'
    ELSE 'N'
  END AS is_eurozone,
  CASE 
    WHEN country IN ('Italy', 'Spain') THEN 'High'
    WHEN country IN ('United Kingdom', 'Poland') THEN 'Medium'
    WHEN country IN ('Germany', 'France', 'Switzerland', 'Sweden') THEN 'Low'
    ELSE 'Unknown'
  END AS liquidity_risk_category
FROM country_list;
