# 🚀 Quick Start Guide

**LCR Management Platform - Python & SQL Edition**

This project uses **production-ready Python scripts and SQL files** instead of notebooks for better version control, testing, and CI/CD integration.

---

## 📂 Project Structure

```
lcr_management/
├── src/
│   ├── data_generation.py    # Generate synthetic LCR data
│   └── run_pipeline.py        # Orchestrate pipeline execution
├── sql/
│   ├── 00_setup.sql          # Unity Catalog setup
│   ├── 01_bronze_layer.sql   # Raw data ingestion
│   ├── 02_silver_layer.sql   # Data quality transforms
│   └── 03_gold_layer.sql     # Dimensional model
├── requirements.txt           # Python dependencies
└── README.md                  # Full documentation
```

---

## ⚡ 5-Minute Setup

### Step 1: Create Unity Catalog

```bash
databricks sql execute --file sql/00_setup.sql
```

Or run in SQL Editor:
```sql
CREATE CATALOG IF NOT EXISTS liquidity_dev;
CREATE SCHEMA IF NOT EXISTS liquidity_dev.bronze;
CREATE SCHEMA IF NOT EXISTS liquidity_dev.silver;
CREATE SCHEMA IF NOT EXISTS liquidity_dev.gold;
CREATE VOLUME IF NOT EXISTS liquidity_dev.bronze.landing_zone;
```

### Step 2: Generate Sample Data

**From Python:**
```bash
python src/data_generation.py
```

**From Databricks Notebook:**
```python
%run ./src/data_generation.py
```

**From Orchestrator:**
```bash
python src/run_pipeline.py --generate-data --date 2026-06-27
```

✅ **Output**: CSV files in `/Volumes/liquidity_dev/bronze/landing_zone/{balances|hqla|collateral}/`

### Step 3: Run Pipeline

**Option A: Run Everything**
```bash
python src/run_pipeline.py --all
```

**Option B: Run Individual Layers**
```bash
# Bronze (raw ingestion)
databricks sql execute --file sql/01_bronze_layer.sql

# Silver (data quality)
databricks sql execute --file sql/02_silver_layer.sql

# Gold (dimensional model)
databricks sql execute --file sql/03_gold_layer.sql
```

**Option C: Use Orchestrator**
```bash
# Just bronze
python src/run_pipeline.py --bronze

# Bronze + Silver
python src/run_pipeline.py --bronze --silver

# Complete pipeline
python src/run_pipeline.py --bronze --silver --gold
```

---

## 📊 Verify Your Data

### Check LCR by Country

```sql
SELECT 
  dc.country_name,
  ROUND(AVG(f.liquidity_coverage_ratio), 4) AS avg_lcr,
  f.lcr_status,
  COUNT(*) AS days_measured
FROM liquidity_dev.gold.fact_intraday_liquidity f
INNER JOIN liquidity_dev.gold.dim_country dc 
  ON f.country_key = dc.country_key
GROUP BY dc.country_name, f.lcr_status
ORDER BY avg_lcr;
```

**Expected**: Italy & Spain should show LCR < 1.0 (Non-Compliant)

### View HQLA Composition

```sql
SELECT 
  hqla_level,
  ROUND(SUM(total_hqla_value), 2) AS total_value_eur,
  COUNT(DISTINCT asset_id) AS asset_count
FROM liquidity_dev.gold.fact_hqla_position
GROUP BY hqla_level
ORDER BY total_value_eur DESC;
```

---

## 🛠️ Development Workflow

### 1. Modify Data Generation

Edit `src/data_generation.py` to change:
* Countries and currencies
* Risk profiles (liquidity_risk: low/medium/high)
* Data volume (num_records parameter)
* Date ranges

### 2. Update Transformations

Edit SQL files:
* `sql/01_bronze_layer.sql` - Add columns, change ingestion logic
* `sql/02_silver_layer.sql` - Modify data quality rules
* `sql/03_gold_layer.sql` - Add dimensions or facts

### 3. Test Changes

```bash
# Test data generation
python src/data_generation.py

# Test specific layer
databricks sql execute --file sql/02_silver_layer.sql

# Test full pipeline
python src/run_pipeline.py --all
```

### 4. Version Control

```bash
git add src/ sql/
git commit -m "Update LCR transformations"
git push
```

---

## 📋 Common Tasks

### Generate Historical Data

Edit `src/data_generation.py` and modify the historical generation section, then run:

```python
# In notebook or Python environment
%run ./src/data_generation.py

# Run the historical data generation function
from datetime import datetime
start_date = datetime(2024, 1, 1)
end_date = datetime.now()

current_date = start_date
while current_date <= end_date:
    generate_data_for_date(current_date.strftime('%Y-%m-%d'), num_records_per_dataset=1000)
    # Move to next month
    current_date = current_date.replace(day=1) + timedelta(days=32)
    current_date = current_date.replace(day=1)
```

### Add New Country

Edit `src/data_generation.py`, add to `COUNTRIES_CONFIG`:

```python
'Netherlands': {
    'currency': 'EUR',
    'subsidiaries': ['DRC Netherlands Corporate'],
    'liquidity_risk': 'low',
    'skew_factor': 1.0
}
```

### Schedule Pipeline

Create Databricks Job:

```bash
databricks jobs create --json @job_config.json
```

Example `job_config.json`:
```json
{
  "name": "LCR Daily Pipeline",
  "tasks": [
    {
      "task_key": "generate_data",
      "python_wheel_task": {
        "package_name": "lcr_management",
        "entry_point": "data_generation"
      }
    },
    {
      "task_key": "run_pipeline",
      "depends_on": [{"task_key": "generate_data"}],
      "sql_task": {
        "file": {"path": "sql/01_bronze_layer.sql"}
      }
    }
  ],
  "schedule": {
    "quartz_cron_expression": "0 0 2 * * ?",
    "timezone_id": "Europe/London"
  }
}
```

---

## 🐛 Troubleshooting

### "Catalog does not exist"
**Solution**: Run `sql/00_setup.sql` first

### "No files found in landing zone"
**Solution**: Run `src/data_generation.py` to create CSV files

### "Permission denied"
**Solution**: Ensure you have:
* `CREATE CATALOG` on metastore
* `CREATE SCHEMA` on catalog  
* `CREATE TABLE` on schema
* `WRITE FILES` on volume

### "Import Error: pandas not found"
**Solution**: Install dependencies
```bash
pip install -r requirements.txt
```

---

## 📚 Next Steps

* Read [README.md](#file-156788113506778) for full documentation
* Check [AGENT_INSTRUCTIONS.md](#file-156788113506779) for AI-assisted rebuilding
* Review [PROJECT_STRUCTURE.md](#file-156788113506788) for architecture details
* See [SETUP.md](#file-156788113506785) for deployment guide

---

## ⏱️ Time Estimates

| Task | Time |
|------|------|
| Unity Catalog setup | 2 min |
| Generate sample data | 2 min |
| Run bronze layer | 3 min |
| Run silver layer | 3 min |
| Run gold layer | 5 min |
| **Total: First run** | **~15 minutes** |

---

**Ready to start? Run the setup SQL and generate some data!** 🚀

```bash
databricks sql execute --file sql/00_setup.sql
python src/data_generation.py
python src/run_pipeline.py --all
```
