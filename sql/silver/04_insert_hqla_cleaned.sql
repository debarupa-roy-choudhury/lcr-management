INSERT INTO liquidity_dev.silver.hqla_cleaned
WITH deduplicated AS (
  SELECT 
    TRIM(asset_id) AS asset_id,
    TRIM(country) AS country,
    TRIM(subsidiary) AS subsidiary,
    TRIM(hqla_level) AS hqla_level,
    TRIM(asset_type) AS asset_type,
    TRIM(currency) AS currency,
    market_value_local,
    market_value_eur,
    haircut_rate,
    eligible_hqla_value_eur,
    maturity_date,
    TRIM(credit_rating) AS credit_rating,
    liquidity_score,
    UPPER(TRIM(encumbered_flag)) AS encumbered_flag,
    UPPER(TRIM(central_bank_eligible)) AS central_bank_eligible,
    yield_rate,
    duration_years,
    last_valuation_date,
    business_date,
    created_timestamp,
    source_file,
    load_timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY TRIM(asset_id), business_date 
      ORDER BY load_timestamp DESC
    ) AS rn
  FROM liquidity_dev.bronze.hqla
  WHERE asset_id IS NOT NULL
    AND business_date IS NOT NULL
    AND market_value_eur IS NOT NULL
    AND market_value_eur >= 0  -- Ensure positive values
    AND TRIM(hqla_level) IN ('Level 1', 'Level 2A', 'Level 2B')  -- Validate HQLA levels
    AND haircut_rate >= 0 AND haircut_rate <= 1  -- Haircut must be between 0 and 100%
)
SELECT 
  asset_id,
  country,
  subsidiary,
  hqla_level,
  asset_type,
  currency,
  market_value_local,
  market_value_eur,
  haircut_rate,
  eligible_hqla_value_eur,
  maturity_date,
  credit_rating,
  liquidity_score,
  encumbered_flag,
  central_bank_eligible,
  yield_rate,
  duration_years,
  last_valuation_date,
  business_date,
  created_timestamp,
  source_file,
  load_timestamp,
  current_timestamp() AS silver_load_timestamp
FROM deduplicated
WHERE rn = 1;
