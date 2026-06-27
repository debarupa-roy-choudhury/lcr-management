INSERT INTO liquidity_dev.gold.fact_intraday_liquidity
WITH balance_metrics AS (
  SELECT
    b.business_date,
    b.country,
    b.subsidiary,
    SUM(b.balance_eur) AS total_balance_eur,
    SUM(b.balance_local) AS total_balance_local,
    COUNT(DISTINCT b.account_id) AS account_count,
    SUM(b.balance_eur * b.weighted_outflow_rate) AS weighted_outflow_amount,
    SUM(CASE WHEN b.stable_funding_flag = 'Y' THEN b.balance_eur ELSE 0 END) AS stable_funding_amount,
    SUM(CASE WHEN b.stable_funding_flag = 'N' THEN b.balance_eur ELSE 0 END) AS unstable_funding_amount
  FROM liquidity_dev.silver.balances_cleaned b
  GROUP BY b.business_date, b.country, b.subsidiary
),
hqla_metrics AS (
  SELECT
    h.business_date,
    h.country,
    h.subsidiary,
    SUM(h.market_value_eur) AS total_hqla_gross_eur,
    SUM(h.eligible_hqla_value_eur) AS total_hqla_eligible_eur,
    SUM(CASE WHEN h.hqla_level = 'Level 1' THEN h.eligible_hqla_value_eur ELSE 0 END) AS hqla_level1_eur,
    SUM(CASE WHEN h.hqla_level = 'Level 2A' THEN h.eligible_hqla_value_eur ELSE 0 END) AS hqla_level2a_eur,
    SUM(CASE WHEN h.hqla_level = 'Level 2B' THEN h.eligible_hqla_value_eur ELSE 0 END) AS hqla_level2b_eur,
    SUM(CASE WHEN h.encumbered_flag = 'N' THEN h.eligible_hqla_value_eur ELSE 0 END) AS hqla_unencumbered_eur
  FROM liquidity_dev.silver.hqla_cleaned h
  GROUP BY h.business_date, h.country, h.subsidiary
),
collateral_metrics AS (
  SELECT
    c.business_date,
    c.country,
    c.subsidiary,
    SUM(c.gross_value_eur) AS total_collateral_gross_eur,
    SUM(c.net_realizable_value_eur) AS total_collateral_net_eur,
    SUM(CASE WHEN c.quality_rating IN ('A', 'B') THEN c.net_realizable_value_eur ELSE 0 END) AS high_quality_collateral_eur
  FROM liquidity_dev.silver.collateral_cleaned c
  GROUP BY c.business_date, c.country, c.subsidiary
),
combined_metrics AS (
  SELECT
    COALESCE(b.business_date, h.business_date, c.business_date) AS business_date,
    COALESCE(b.country, h.country, c.country) AS country,
    COALESCE(b.subsidiary, h.subsidiary, c.subsidiary) AS subsidiary,
    COALESCE(b.total_balance_eur, 0) AS total_balance_eur,
    COALESCE(b.total_balance_local, 0) AS total_balance_local,
    COALESCE(b.account_count, 0) AS account_count,
    COALESCE(h.total_hqla_gross_eur, 0) AS total_hqla_gross_eur,
    COALESCE(h.total_hqla_eligible_eur, 0) AS total_hqla_eligible_eur,
    COALESCE(h.hqla_level1_eur, 0) AS hqla_level1_eur,
    COALESCE(h.hqla_level2a_eur, 0) AS hqla_level2a_eur,
    COALESCE(h.hqla_level2b_eur, 0) AS hqla_level2b_eur,
    COALESCE(h.hqla_unencumbered_eur, 0) AS hqla_unencumbered_eur,
    COALESCE(b.weighted_outflow_amount, 0) AS weighted_outflow_amount,
    COALESCE(b.stable_funding_amount, 0) AS stable_funding_amount,
    COALESCE(b.unstable_funding_amount, 0) AS unstable_funding_amount,
    COALESCE(c.total_collateral_gross_eur, 0) AS total_collateral_gross_eur,
    COALESCE(c.total_collateral_net_eur, 0) AS total_collateral_net_eur,
    COALESCE(c.high_quality_collateral_eur, 0) AS high_quality_collateral_eur
  FROM balance_metrics b
  FULL OUTER JOIN hqla_metrics h 
    ON b.business_date = h.business_date 
    AND b.country = h.country 
    AND b.subsidiary = h.subsidiary
  FULL OUTER JOIN collateral_metrics c 
    ON COALESCE(b.business_date, h.business_date) = c.business_date 
    AND COALESCE(b.country, h.country) = c.country 
    AND COALESCE(b.subsidiary, h.subsidiary) = c.subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY cm.business_date, cm.country, cm.subsidiary) AS liquidity_key,
  dd.date_key,
  dc.country_key,
  ds.subsidiary_key,
  cm.total_balance_eur,
  cm.total_balance_local,
  cm.account_count,
  cm.total_hqla_gross_eur,
  cm.total_hqla_eligible_eur,
  cm.hqla_level1_eur,
  cm.hqla_level2a_eur,
  cm.hqla_level2b_eur,
  cm.hqla_unencumbered_eur,
  cm.weighted_outflow_amount AS total_cash_outflows_30d,
  cm.weighted_outflow_amount,
  cm.stable_funding_amount,
  cm.unstable_funding_amount,
  cm.total_collateral_gross_eur,
  cm.total_collateral_net_eur,
  cm.high_quality_collateral_eur,
  -- LCR Calculation: HQLA / Net Cash Outflows
  CASE 
    WHEN cm.weighted_outflow_amount > 0 
    THEN ROUND(cm.total_hqla_eligible_eur / cm.weighted_outflow_amount, 4)
    ELSE NULL 
  END AS liquidity_coverage_ratio,
  -- Surplus/Deficit calculation
  CASE 
    WHEN cm.weighted_outflow_amount > 0 
    THEN ROUND(cm.total_hqla_eligible_eur - cm.weighted_outflow_amount, 2)
    ELSE cm.total_hqla_eligible_eur 
  END AS lcr_surplus_deficit_eur,
  -- LCR Status
  CASE 
    WHEN cm.weighted_outflow_amount = 0 THEN 'No Outflows'
    WHEN cm.total_hqla_eligible_eur / cm.weighted_outflow_amount >= 1.0 THEN 'Compliant'
    WHEN cm.total_hqla_eligible_eur / cm.weighted_outflow_amount >= 0.9 THEN 'At Risk'
    ELSE 'Non-Compliant'
  END AS lcr_status,
  current_timestamp() AS load_timestamp
FROM combined_metrics cm
INNER JOIN liquidity_dev.gold.dim_date dd ON CAST(DATE_FORMAT(cm.business_date, 'yyyyMMdd') AS INT) = dd.date_key
INNER JOIN liquidity_dev.gold.dim_country dc ON cm.country = dc.country_name
INNER JOIN liquidity_dev.gold.dim_subsidiary ds ON cm.subsidiary = ds.subsidiary_name AND cm.country = ds.country;
