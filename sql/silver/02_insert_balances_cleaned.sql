INSERT INTO liquidity_dev.silver.balances_cleaned
WITH deduplicated AS (
  SELECT 
    TRIM(account_id) AS account_id,
    TRIM(country) AS country,
    TRIM(subsidiary) AS subsidiary,
    TRIM(account_type) AS account_type,
    TRIM(currency) AS currency,
    balance_local,
    balance_eur,
    TRIM(customer_segment) AS customer_segment,
    TRIM(maturity_bucket) AS maturity_bucket,
    weighted_outflow_rate,
    UPPER(TRIM(stable_funding_flag)) AS stable_funding_flag,
    last_transaction_date,
    average_balance_30d,
    TRIM(balance_volatility) AS balance_volatility,
    business_date,
    created_timestamp,
    source_file,
    load_timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY TRIM(account_id), business_date 
      ORDER BY load_timestamp DESC
    ) AS rn
  FROM liquidity_dev.bronze.balances
  WHERE account_id IS NOT NULL
    AND business_date IS NOT NULL
    AND balance_eur IS NOT NULL
    AND balance_eur >= 0  -- Ensure positive balances
)
SELECT 
  account_id,
  country,
  subsidiary,
  account_type,
  currency,
  balance_local,
  balance_eur,
  customer_segment,
  maturity_bucket,
  weighted_outflow_rate,
  stable_funding_flag,
  last_transaction_date,
  average_balance_30d,
  balance_volatility,
  business_date,
  created_timestamp,
  source_file,
  load_timestamp,
  current_timestamp() AS silver_load_timestamp
FROM deduplicated
WHERE rn = 1;
