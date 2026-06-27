# Quick Setup Guide

## 🚀 Quick Start (5 minutes)

### Step 1: Create Unity Catalog Structure

Run this SQL in a Databricks SQL Editor or notebook:

```sql
-- Create catalog
CREATE CATALOG IF NOT EXISTS liquidity_dev
COMMENT 'Liquidity Coverage Ratio (LCR) Management Platform';

-- Create schemas
CREATE SCHEMA IF NOT EXISTS liquidity_dev.bronze
COMMENT 'Bronze layer - raw data from landing zone';

CREATE SCHEMA IF NOT EXISTS liquidity_dev.silver
COMMENT 'Silver layer - cleaned and validated data';

CREATE SCHEMA IF NOT EXISTS liquidity_dev.gold
COMMENT 'Gold layer - dimensional model for analytics';

-- Create volume for landing zone
CREATE VOLUME IF NOT EXISTS liquidity_dev.bronze.landing_zone
COMMENT 'Landing zone for CSV file ingestion';
```

### Step 2: Verify Setup

```sql
-- Verify catalog
SHOW SCHEMAS IN liquidity_dev;

-- Verify volume
SHOW VOLUMES IN liquidity_dev.bronze;
```

Expected output:
* 3 schemas: bronze, silver, gold
* 1 volume: landing_zone

---

## 📝 Notebook Execution Order

### Option A: Manual Execution

Run notebooks in sequence:

1. **00-data-generation** - Generate synthetic banking data
   * Run Cell 2 to load functions
   * Run Cell 4 to generate data for today
   * *Optional*: Run Cell 5 for historical data

2. **01-bronze-layer** - Load raw data into Delta tables
   * Run all cells (2-5)
   * Verify bronze tables created

3. **02-silver-layer** - Apply data quality rules
   * Run all cells (2-6)
   * Verify cleaned tables created

4. **03-gold-layer** - Create dimensional model
   * Run cells 2-5 for dimensions
   * Run cells 6-9 for facts
   * Run cell 10 to verify

### Option B: Automated Job (Production)

Create a Databricks Job:

```json
{
  "name": "LCR Daily Load",
  "tasks": [
    {
      "task_key": "data_generation",
      "notebook_task": {
        "notebook_path": "/lcr_management/00-data-generation"
      }
    },
    {
      "task_key": "bronze_load",
      "depends_on": [{"task_key": "data_generation"}],
      "notebook_task": {
        "notebook_path": "/lcr_management/01-bronze-layer"
      }
    },
    {
      "task_key": "silver_clean",
      "depends_on": [{"task_key": "bronze_load"}],
      "notebook_task": {
        "notebook_path": "/lcr_management/02-silver-layer"
      }
    },
    {
      "task_key": "gold_transform",
      "depends_on": [{"task_key": "silver_clean"}],
      "notebook_task": {
        "notebook_path": "/lcr_management/03-gold-layer"
      }
    }
  ]
}
```

---

## ✅ Verification Queries

### Check Data Load Success

```sql
-- Bronze layer
SELECT 'balances' AS table_name, COUNT(*) AS records FROM liquidity_dev.bronze.balances
UNION ALL
SELECT 'hqla', COUNT(*) FROM liquidity_dev.bronze.hqla
UNION ALL
SELECT 'collateral', COUNT(*) FROM liquidity_dev.bronze.collateral;

-- Expected: 1,000+ records per table
```

### Verify LCR Calculation

```sql
SELECT 
  dc.country_name,
  dc.liquidity_risk_category,
  ROUND(AVG(f.liquidity_coverage_ratio), 4) AS avg_lcr,
  f.lcr_status
FROM liquidity_dev.gold.fact_intraday_liquidity f
INNER JOIN liquidity_dev.gold.dim_country dc ON f.country_key = dc.country_key
GROUP BY dc.country_name, dc.liquidity_risk_category, f.lcr_status
ORDER BY avg_lcr;
```

**Expected Results**:
* High-risk countries (Italy, Spain) with LCR < 1.0 (Non-Compliant)
* Low-risk countries (Germany, France, etc.) with LCR >= 1.0 (Compliant)

---

## 🔧 Troubleshooting

### Issue: "Permission denied"
**Solution**: Request CREATE CATALOG permission from workspace admin

### Issue: "No data in bronze tables"
**Solution**: 
1. Verify landing zone has files:
   ```python
   dbutils.fs.ls("/Volumes/liquidity_dev/bronze/landing_zone/balances/")
   ```
2. Re-run data generation notebook

### Issue: "Foreign key constraint failed"
**Solution**: 
1. Verify dimensions exist before creating facts
2. Check dimension tables have data:
   ```sql
   SELECT COUNT(*) FROM liquidity_dev.gold.dim_date;
   ```

---

## 📞 Support

For detailed instructions, see:
* **README.md** - Complete project documentation
* **AGENT_INSTRUCTIONS.md** - Step-by-step rebuild guide for AI agents

---

**Quick Setup Complete!** 🎉

*Proceed to notebook execution to generate data and build the LCR platform.*