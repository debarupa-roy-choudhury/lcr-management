INSERT INTO liquidity_dev.gold.dim_account
WITH latest_accounts AS (
  SELECT 
    account_id,
    account_type,
    customer_segment,
    currency,
    country,
    subsidiary,
    MAX(business_date) AS effective_date
  FROM liquidity_dev.silver.balances_cleaned
  GROUP BY account_id, account_type, customer_segment, currency, country, subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY account_id, effective_date) AS account_key,
  account_id,
  account_type,
  customer_segment,
  currency,
  country,
  subsidiary,
  effective_date,
  NULL AS end_date,
  'Y' AS is_current
FROM latest_accounts;
