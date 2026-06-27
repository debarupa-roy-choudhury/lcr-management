INSERT INTO liquidity_dev.gold.dim_date
WITH all_dates AS (
  SELECT DISTINCT business_date FROM liquidity_dev.silver.balances_cleaned
  UNION
  SELECT DISTINCT business_date FROM liquidity_dev.silver.hqla_cleaned
  UNION
  SELECT DISTINCT business_date FROM liquidity_dev.silver.collateral_cleaned
)
SELECT
  CAST(DATE_FORMAT(business_date, 'yyyyMMdd') AS INT) AS date_key,
  business_date,
  YEAR(business_date) AS year,
  QUARTER(business_date) AS quarter,
  MONTH(business_date) AS month,
  DATE_FORMAT(business_date, 'MMMM') AS month_name,
  DAY(business_date) AS day_of_month,
  DAYOFWEEK(business_date) AS day_of_week,
  DATE_FORMAT(business_date, 'EEEE') AS day_name,
  WEEKOFYEAR(business_date) AS week_of_year,
  CASE WHEN DAYOFWEEK(business_date) IN (1, 7) THEN 'Y' ELSE 'N' END AS is_weekend,
  CASE WHEN business_date = LAST_DAY(business_date) THEN 'Y' ELSE 'N' END AS is_month_end,
  CASE WHEN MONTH(business_date) IN (3, 6, 9, 12) AND business_date = LAST_DAY(business_date) THEN 'Y' ELSE 'N' END AS is_quarter_end,
  CASE WHEN MONTH(business_date) = 12 AND business_date = LAST_DAY(business_date) THEN 'Y' ELSE 'N' END AS is_year_end,
  YEAR(business_date) AS fiscal_year,
  QUARTER(business_date) AS fiscal_quarter
FROM all_dates;
