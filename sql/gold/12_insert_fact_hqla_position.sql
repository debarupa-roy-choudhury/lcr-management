INSERT INTO liquidity_dev.gold.fact_hqla_position
WITH hqla_aggregated AS (
  SELECT
    h.business_date,
    h.country,
    h.subsidiary,
    h.hqla_level,
    h.asset_type,
    h.credit_rating,
    COUNT(h.asset_id) AS asset_count,
    SUM(h.market_value_eur) AS total_market_value_eur,
    SUM(h.eligible_hqla_value_eur) AS total_eligible_value_eur,
    AVG(h.haircut_rate) AS average_haircut_rate,
    AVG(h.yield_rate) AS average_yield_rate,
    AVG(h.liquidity_score) AS average_liquidity_score,
    SUM(CASE WHEN h.encumbered_flag = 'Y' THEN h.eligible_hqla_value_eur ELSE 0 END) AS encumbered_value_eur,
    SUM(CASE WHEN h.encumbered_flag = 'N' THEN h.eligible_hqla_value_eur ELSE 0 END) AS unencumbered_value_eur,
    SUM(CASE WHEN h.central_bank_eligible = 'Y' THEN h.eligible_hqla_value_eur ELSE 0 END) AS central_bank_eligible_value_eur
  FROM liquidity_dev.silver.hqla_cleaned h
  GROUP BY h.business_date, h.country, h.subsidiary, h.hqla_level, h.asset_type, h.credit_rating
),
total_hqla AS (
  SELECT
    business_date,
    country,
    subsidiary,
    SUM(total_eligible_value_eur) AS total_portfolio_value
  FROM hqla_aggregated
  GROUP BY business_date, country, subsidiary
)
SELECT
  ROW_NUMBER() OVER (ORDER BY ha.business_date, ha.country, ha.subsidiary, ha.hqla_level, ha.asset_type) AS hqla_position_key,
  dd.date_key,
  dc.country_key,
  ds.subsidiary_key,
  ha.hqla_level,
  ha.asset_type,
  ha.credit_rating,
  ha.asset_count,
  ha.total_market_value_eur,
  ha.total_eligible_value_eur,
  ha.average_haircut_rate,
  ha.average_yield_rate,
  ha.average_liquidity_score,
  ha.encumbered_value_eur,
  ha.unencumbered_value_eur,
  ha.central_bank_eligible_value_eur,
  CASE 
    WHEN th.total_portfolio_value > 0 
    THEN ROUND((ha.total_eligible_value_eur / th.total_portfolio_value) * 100, 4)
    ELSE 0 
  END AS concentration_percentage,
  current_timestamp() AS load_timestamp
FROM hqla_aggregated ha
INNER JOIN total_hqla th 
  ON ha.business_date = th.business_date 
  AND ha.country = th.country 
  AND ha.subsidiary = th.subsidiary
INNER JOIN liquidity_dev.gold.dim_date dd ON CAST(DATE_FORMAT(ha.business_date, 'yyyyMMdd') AS INT) = dd.date_key
INNER JOIN liquidity_dev.gold.dim_country dc ON ha.country = dc.country_name
INNER JOIN liquidity_dev.gold.dim_subsidiary ds ON ha.subsidiary = ds.subsidiary_name AND ha.country = ds.country;
