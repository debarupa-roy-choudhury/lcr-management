-- Validate data quality rules applied in silver layer
-- Check that flags are uppercase, HQLA levels are valid, quality ratings are valid

-- Check 1: Verify all flags are uppercase Y/N in balances
SELECT 
  'balances_cleaned - stable_funding_flag' AS validation_check,
  stable_funding_flag AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.balances_cleaned
GROUP BY stable_funding_flag

UNION ALL

-- Check 2: Verify HQLA levels are valid
SELECT 
  'hqla_cleaned - hqla_level' AS validation_check,
  hqla_level AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.hqla_cleaned
GROUP BY hqla_level

UNION ALL

-- Check 3: Verify encumbered_flag in HQLA
SELECT 
  'hqla_cleaned - encumbered_flag' AS validation_check,
  encumbered_flag AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.hqla_cleaned
GROUP BY encumbered_flag

UNION ALL

-- Check 4: Verify central_bank_eligible in HQLA
SELECT 
  'hqla_cleaned - central_bank_eligible' AS validation_check,
  central_bank_eligible AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.hqla_cleaned
GROUP BY central_bank_eligible

UNION ALL

-- Check 5: Verify quality ratings in collateral
SELECT 
  'collateral_cleaned - quality_rating' AS validation_check,
  quality_rating AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.collateral_cleaned
GROUP BY quality_rating

UNION ALL

-- Check 6: Verify insurance_status in collateral
SELECT 
  'collateral_cleaned - insurance_status' AS validation_check,
  insurance_status AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.collateral_cleaned
GROUP BY insurance_status

UNION ALL

-- Check 7: Verify concentration_risk_flag in collateral
SELECT 
  'collateral_cleaned - concentration_risk_flag' AS validation_check,
  concentration_risk_flag AS flag_value,
  COUNT(*) AS record_count
FROM liquidity_dev.silver.collateral_cleaned
GROUP BY concentration_risk_flag

ORDER BY validation_check, flag_value;
