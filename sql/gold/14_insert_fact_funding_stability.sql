INSERT INTO liquidity_dev.gold.fact_funding_stability
WITH funding_aggregated AS (
  SELECT
    b.business_date,
    b.country,
    b.subsidiary,
    b.maturity_bucket,
    b.customer_segment,
    b.account_type,
    COUNT(b.account_id) AS account_count,
    SUM(b.balance_eur) AS total_balance_eur,
    AVG(b.balance_eur) AS average_balance_eur,
    SUM(CASE WHEN b.stable_funding_flag = 'Y' THEN b.balance_eur ELSE 0 END) AS stable_funding_balance_eur,
    SUM(CASE WHEN b.stable_funding_flag = 'N' THEN b.balance_eur ELSE 0 END) AS unstable_funding_balance_eur,
    SUM(b.balance_eur * b.weighted_outflow_rate) AS weighted_outflow_amount,
    AVG(b.weighted_outflow_rate) AS average_outflow_rate,
    SUM(CASE WHEN b.balance_volatility = 'High' THEN b.balance_eur ELSE 0 END) AS high_volatility_balance_eur,
    SUM(CASE WHEN b.balance_volatility = 'Medium' THEN b.balance_eur ELSE 0 END) AS medium_volatility_balance_eur,
    SUM(CASE WHEN b.balance_volatility = 'Low' THEN b.balance_eur ELSE 0 END) AS low_volatility_balance_eur,
    SUM(CASE WHEN DATEDIFF(b.business_date, b.last_transaction_date) > 30 THEN 1 ELSE 0 END) AS inactive_account_count,
    SUM(CASE WHEN DATEDIFF(b.business_date, b.last_transaction_date) > 30 THEN b.balance_eur ELSE 0 END) AS inactive_balance_eur
  FROM liquidity_dev.silver.balances_cleaned b
  GROUP BY b.business_date, b.country, b.subsidiary, b.maturity_bucket, b.customer_segment, b.account_type
),
total_funding AS (
  SELECT
    business_date,
    country,
    subsidiary,
    SUM(total_balance_eur) AS total_portfolio_balance
  FROM funding_aggregated
  GROUP BY business_date, country, subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY fa.business_date, fa.country, fa.subsidiary, fa.maturity_bucket, fa.customer_segment) AS funding_stability_key,
  dd.date_key,
  dc.country_key,
  ds.subsidiary_key,
  fa.maturity_bucket,
  fa.customer_segment,
  fa.account_type,
  fa.account_count,
  fa.total_balance_eur,
  fa.average_balance_eur,
  fa.stable_funding_balance_eur,
  fa.unstable_funding_balance_eur,
  fa.weighted_outflow_amount,
  fa.average_outflow_rate,
  fa.high_volatility_balance_eur,
  fa.medium_volatility_balance_eur,
  fa.low_volatility_balance_eur,
  fa.inactive_account_count,
  fa.inactive_balance_eur,
  CASE 
    WHEN fa.total_balance_eur > 0 
    THEN ROUND(fa.stable_funding_balance_eur / fa.total_balance_eur, 4)
    ELSE 0 
  END AS stable_funding_ratio,
  CASE 
    WHEN tf.total_portfolio_balance > 0 
    THEN ROUND((fa.total_balance_eur / tf.total_portfolio_balance) * 100, 4)
    ELSE 0 
  END AS concentration_percentage,
  current_timestamp() AS load_timestamp
FROM funding_aggregated fa
INNER JOIN total_funding tf 
  ON fa.business_date = tf.business_date 
  AND fa.country = tf.country 
  AND fa.subsidiary = tf.subsidiary
INNER JOIN liquidity_dev.gold.dim_date dd ON CAST(DATE_FORMAT(fa.business_date, 'yyyyMMdd') AS INT) = dd.date_key
INNER JOIN liquidity_dev.gold.dim_country dc ON fa.country = dc.country_name
INNER JOIN liquidity_dev.gold.dim_subsidiary ds ON fa.subsidiary = ds.subsidiary_name AND fa.country = ds.country;
