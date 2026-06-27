INSERT INTO liquidity_dev.bronze.collateral
SELECT 
  collateral_id,
  country,
  subsidiary,
  collateral_type,
  currency,
  CAST(gross_value_local AS DECIMAL(18,2)) AS gross_value_local,
  CAST(gross_value_eur AS DECIMAL(18,2)) AS gross_value_eur,
  CAST(loan_to_value_ratio AS DECIMAL(8,4)) AS loan_to_value_ratio,
  CAST(haircut_percentage AS DECIMAL(8,4)) AS haircut_percentage,
  CAST(net_realizable_value_eur AS DECIMAL(18,2)) AS net_realizable_value_eur,
  associated_loan_id,
  collateral_status,
  CAST(valuation_date AS DATE) AS valuation_date,
  CAST(next_review_date AS DATE) AS next_review_date,
  quality_rating,
  CAST(liquidation_period_days AS INT) AS liquidation_period_days,
  insurance_status,
  legal_ownership,
  concentration_risk_flag,
  CAST(business_date AS DATE) AS business_date,
  CAST(created_timestamp AS TIMESTAMP) AS created_timestamp,
  input_file_name() AS source_file,
  current_timestamp() AS load_timestamp
FROM read_files(
  '/Volumes/liquidity_dev/bronze/landing_zone/collateral/',
  format => 'csv',
  header => true,
  recursiveFileLookup => true,
  pathGlobFilter => '*.csv'
);
