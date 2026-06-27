INSERT INTO liquidity_dev.gold.fact_collateral_risk
WITH collateral_aggregated AS (
  SELECT
    c.business_date,
    c.country,
    c.subsidiary,
    c.collateral_type,
    c.quality_rating,
    c.collateral_status,
    COUNT(c.collateral_id) AS collateral_count,
    SUM(c.gross_value_eur) AS total_gross_value_eur,
    SUM(c.net_realizable_value_eur) AS total_net_value_eur,
    AVG(c.haircut_percentage) AS average_haircut_percentage,
    AVG(c.loan_to_value_ratio) AS average_ltv_ratio,
    AVG(c.liquidation_period_days) AS average_liquidation_days,
    SUM(CASE WHEN c.concentration_risk_flag = 'Y' THEN c.net_realizable_value_eur ELSE 0 END) AS high_concentration_value_eur,
    SUM(CASE WHEN c.insurance_status = 'Y' THEN c.net_realizable_value_eur ELSE 0 END) AS insured_value_eur,
    SUM(CASE WHEN c.insurance_status = 'N' THEN c.net_realizable_value_eur ELSE 0 END) AS uninsured_value_eur,
    SUM(CASE WHEN c.collateral_status = 'Active' THEN c.net_realizable_value_eur ELSE 0 END) AS active_collateral_value_eur,
    SUM(CASE WHEN c.collateral_status = 'Under Review' THEN c.net_realizable_value_eur ELSE 0 END) AS under_review_value_eur,
    SUM(CASE WHEN c.next_review_date < c.business_date THEN 1 ELSE 0 END) AS overdue_review_count,
    SUM(CASE WHEN c.next_review_date < c.business_date THEN c.net_realizable_value_eur ELSE 0 END) AS overdue_review_value_eur,
    AVG(CASE c.quality_rating
      WHEN 'A' THEN 4
      WHEN 'B' THEN 3
      WHEN 'C' THEN 2
      WHEN 'D' THEN 1
      ELSE 0
    END) AS quality_score
  FROM liquidity_dev.silver.collateral_cleaned c
  GROUP BY c.business_date, c.country, c.subsidiary, c.collateral_type, c.quality_rating, c.collateral_status
),
total_collateral AS (
  SELECT
    business_date,
    country,
    subsidiary,
    SUM(total_net_value_eur) AS total_portfolio_value
  FROM collateral_aggregated
  GROUP BY business_date, country, subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY ca.business_date, ca.country, ca.subsidiary, ca.collateral_type, ca.quality_rating) AS collateral_risk_key,
  dd.date_key,
  dc.country_key,
  ds.subsidiary_key,
  ca.collateral_type,
  ca.quality_rating,
  ca.collateral_status,
  ca.collateral_count,
  ca.total_gross_value_eur,
  ca.total_net_value_eur,
  ca.average_haircut_percentage,
  ca.average_ltv_ratio,
  ca.average_liquidation_days,
  ca.high_concentration_value_eur,
  ca.insured_value_eur,
  ca.uninsured_value_eur,
  ca.active_collateral_value_eur,
  ca.under_review_value_eur,
  ca.overdue_review_count,
  ca.overdue_review_value_eur,
  CASE 
    WHEN tc.total_portfolio_value > 0 
    THEN ROUND((ca.total_net_value_eur / tc.total_portfolio_value) * 100, 4)
    ELSE 0 
  END AS concentration_percentage,
  ca.quality_score,
  current_timestamp() AS load_timestamp
FROM collateral_aggregated ca
INNER JOIN total_collateral tc 
  ON ca.business_date = tc.business_date 
  AND ca.country = tc.country 
  AND ca.subsidiary = tc.subsidiary
INNER JOIN liquidity_dev.gold.dim_date dd ON CAST(DATE_FORMAT(ca.business_date, 'yyyyMMdd') AS INT) = dd.date_key
INNER JOIN liquidity_dev.gold.dim_country dc ON ca.country = dc.country_name
INNER JOIN liquidity_dev.gold.dim_subsidiary ds ON ca.subsidiary = ds.subsidiary_name AND ca.country = ds.country;
