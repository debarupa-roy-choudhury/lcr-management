INSERT INTO liquidity_dev.silver.collateral_cleaned
WITH deduplicated AS (
  SELECT 
    TRIM(collateral_id) AS collateral_id,
    TRIM(country) AS country,
    TRIM(subsidiary) AS subsidiary,
    TRIM(collateral_type) AS collateral_type,
    TRIM(currency) AS currency,
    gross_value_local,
    gross_value_eur,
    loan_to_value_ratio,
    haircut_percentage,
    net_realizable_value_eur,
    TRIM(associated_loan_id) AS associated_loan_id,
    TRIM(collateral_status) AS collateral_status,
    valuation_date,
    next_review_date,
    UPPER(TRIM(quality_rating)) AS quality_rating,
    liquidation_period_days,
    UPPER(TRIM(insurance_status)) AS insurance_status,
    TRIM(legal_ownership) AS legal_ownership,
    UPPER(TRIM(concentration_risk_flag)) AS concentration_risk_flag,
    business_date,
    created_timestamp,
    source_file,
    load_timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY TRIM(collateral_id), business_date 
      ORDER BY load_timestamp DESC
    ) AS rn
  FROM liquidity_dev.bronze.collateral
  WHERE collateral_id IS NOT NULL
    AND business_date IS NOT NULL
    AND gross_value_eur IS NOT NULL
    AND gross_value_eur >= 0  -- Ensure positive values
    AND UPPER(TRIM(quality_rating)) IN ('A', 'B', 'C', 'D')  -- Validate quality ratings
    AND haircut_percentage >= 0 AND haircut_percentage <= 1  -- Haircut must be between 0 and 100%
    AND loan_to_value_ratio >= 0 AND loan_to_value_ratio <= 1  -- LTV must be between 0 and 100%
)
SELECT 
  collateral_id,
  country,
  subsidiary,
  collateral_type,
  currency,
  gross_value_local,
  gross_value_eur,
  loan_to_value_ratio,
  haircut_percentage,
  net_realizable_value_eur,
  associated_loan_id,
  collateral_status,
  valuation_date,
  next_review_date,
  quality_rating,
  liquidation_period_days,
  insurance_status,
  legal_ownership,
  concentration_risk_flag,
  business_date,
  created_timestamp,
  source_file,
  load_timestamp,
  current_timestamp() AS silver_load_timestamp
FROM deduplicated
WHERE rn = 1;
