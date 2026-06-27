# LCR Management Project Structure

## 📁 Complete Folder Structure

```
lcr_management/
│
├── 📝 README.md                           # Complete project documentation
├── 🤖 AGENT_INSTRUCTIONS.md               # Step-by-step rebuild guide for AI agents
├── 🚀 SETUP.md                            # Quick setup guide
├── 📄 PROJECT_STRUCTURE.md                # This file - project overview
├── 📋 NOTEBOOK_COPY_INSTRUCTIONS.md       # Instructions to copy notebooks
├── 🛡️ .gitignore                          # Git ignore patterns
├── ⚖️ LICENSE                             # MIT License
│
├── 📓 00-data-generation                 # Synthetic data generation notebook
├── 📓 01-bronze-layer                    # Bronze layer ETL notebook
├── 📓 02-silver-layer                    # Silver layer data quality notebook
└── 📓 03-gold-layer                      # Gold layer dimensional model notebook
```

---

## 📚 Documentation Files

### 📝 README.md (Primary Documentation)
**Purpose**: Comprehensive project documentation  
**Audience**: Developers, analysts, stakeholders  
**Contains**:
* Executive summary with business value
* Architecture overview (medallion pattern)
* Data model specifications
* Getting started guide
* Business use cases with sample queries
* Deployment instructions
* Troubleshooting guide
* Contributing guidelines

**When to use**: Start here for understanding the entire project

---

### 🤖 AGENT_INSTRUCTIONS.md (Rebuild Guide)
**Purpose**: Complete step-by-step instructions for rebuilding the project from scratch  
**Audience**: AI agents (Genie, Claude, GPT, Copilot), developers  
**Contains**:
* Phase-by-phase build instructions
* All SQL DDL statements
* Complete Python code for data generation
* Validation queries at each step
* Expected outputs and success criteria
* Troubleshooting tips

**When to use**: 
* When you need to rebuild the project in a new workspace
* When training an AI agent to understand the project
* When you want to learn the architecture by building it step-by-step

---

### 🚀 SETUP.md (Quick Start)
**Purpose**: Minimal setup to get started quickly  
**Audience**: Users who want to get running fast  
**Contains**:
* Unity Catalog setup SQL
* Notebook execution order
* Verification queries
* Common troubleshooting

**When to use**: When you just want to get the project running without reading 50 pages

---

### 📋 NOTEBOOK_COPY_INSTRUCTIONS.md
**Purpose**: Instructions for copying notebooks from the original folder  
**Audience**: Users setting up this folder  
**Contains**:
* Manual copy steps
* Automated copy using Databricks CLI
* Verification methods
* Alternative rebuild approach

**When to use**: 
* After cloning this folder structure
* When notebooks are empty placeholders

---

### 📄 PROJECT_STRUCTURE.md (This File)
**Purpose**: Overview of all project files and their purpose  
**Audience**: New users, contributors  
**Contains**:
* Complete folder structure
* Description of each file
* Navigation guide

**When to use**: When you want to understand what each file does

---

## 📓 Notebooks

### 00-data-generation
**Purpose**: Generate synthetic banking data for LCR analysis  
**Language**: Python  
**Key Functions**:
* `generate_balances_data()` - Account balances
* `generate_hqla_data()` - High Quality Liquid Assets
* `generate_collateral_data()` - Collateral details
* `generate_data_for_date()` - Main orchestrator

**Outputs**: CSV files in `/Volumes/liquidity_dev/bronze/landing_zone/`

**Risk Profiles Built-In**:
* High Risk: Italy, Spain (LCR < 100%)
* Medium Risk: UK, Poland
* Low Risk: Germany, France, Switzerland, Sweden (LCR >= 100%)

---

### 01-bronze-layer
**Purpose**: Load raw CSV files into Delta tables  
**Language**: SQL  
**Tables Created**:
* `liquidity_dev.bronze.balances`
* `liquidity_dev.bronze.hqla`
* `liquidity_dev.bronze.collateral`

**Features**:
* Recursive file discovery
* Idempotent (CREATE OR REPLACE)
* Full schema with detailed comments
* Metadata tracking

---

### 02-silver-layer
**Purpose**: Apply data quality rules and create cleaned tables  
**Language**: SQL  
**Tables Created**:
* `liquidity_dev.silver.balances_cleaned`
* `liquidity_dev.silver.hqla_cleaned`
* `liquidity_dev.silver.collateral_cleaned`

**Data Quality Rules**:
* ✓ Null removal (key fields)
* ✓ String trimming
* ✓ Deduplication (by ID + date)
* ✓ Uppercase flags (Y/N)
* ✓ Category validation (HQLA levels: Level 1, 2A, 2B)
* ✓ Quality rating validation (A, B, C, D)
* ✓ Range validation (positive values, percentages 0-100%)

---

### 03-gold-layer
**Purpose**: Create dimensional model (star schema) for analytics  
**Language**: SQL  

**Dimensions Created** (4 tables):
* `liquidity_dev.gold.dim_date` - Time dimension
* `liquidity_dev.gold.dim_country` - Geographic attributes
* `liquidity_dev.gold.dim_subsidiary` - Organizational hierarchy
* `liquidity_dev.gold.dim_account` - Account attributes (Type 2 SCD)

**Facts Created** (4 tables):
* `liquidity_dev.gold.fact_intraday_liquidity` ⭐ - **LCR calculations & compliance**
* `liquidity_dev.gold.fact_hqla_position` - HQLA composition & concentration
* `liquidity_dev.gold.fact_funding_stability` - Funding maturity & stability
* `liquidity_dev.gold.fact_collateral_risk` - Collateral quality & risk

**Key Calculation**:
```sql
LCR = Total HQLA (after haircuts) / Total Net Cash Outflows over 30 days
Basel III Requirement: LCR >= 100%
```

---

## 🛠️ Supporting Files

### .gitignore
**Purpose**: Specifies files to exclude from version control  
**Excludes**:
* Python cache (`__pycache__`, `*.pyc`)
* Data files (`*.csv`, `*.parquet`)
* IDE files (`.vscode`, `.idea`)
* Databricks config (`.databrickscfg`)
* Environment variables (`.env`)
* Log files (`*.log`)

---

### LICENSE
**Type**: MIT License  
**Permissions**: Commercial use, modification, distribution, private use  
**Limitations**: No liability, no warranty  
**Conditions**: Include copyright notice

---

## 📊 Data Flow

```
┌─────────────────────┐
│ 00-data-generation │
│ (Python)            │
│ Generate synthetic  │
│ banking data        │
└─────────┬───────────┘
         │
         │ CSV files in landing zone
         │
         ▼
┌─────────────────────┐
│ 01-bronze-layer    │
│ (SQL)              │
│ Load raw data      │
│ into Delta tables  │
└─────────┬───────────┘
         │
         │ 3 bronze tables (raw)
         │
         ▼
┌─────────────────────┐
│ 02-silver-layer    │
│ (SQL)              │
│ Data quality       │
│ transformations    │
└─────────┬───────────┘
         │
         │ 3 silver tables (cleaned)
         │
         ▼
┌─────────────────────┐
│ 03-gold-layer      │
│ (SQL)              │
│ Dimensional model  │
│ Star schema        │
│ LCR calculations   │
└─────────┬───────────┘
         │
         │ 4 dimensions + 4 facts
         │
         ▼
┌─────────────────────┐
│ Analytics & BI     │
│ Dashboards         │
│ Reports            │
│ Regulatory         │
└─────────────────────┘
```

---

## 🛣️ Navigation Guide

### 🎯 I'm New - Where Do I Start?
1. Read **README.md** (sections: Executive Summary, Quick Start)
2. Read **SETUP.md** (run setup SQL)
3. Read **NOTEBOOK_COPY_INSTRUCTIONS.md** (copy notebooks)
4. Execute notebooks in order (00 → 01 → 02 → 03)
5. Run sample queries from **README.md** (Business Use Cases section)

### 🔧 I Want to Rebuild Everything from Scratch
1. Read **AGENT_INSTRUCTIONS.md**
2. Follow phases 0-5 step-by-step
3. Validate after each phase

### 🐛 I Have an Issue
1. Check **SETUP.md** (Troubleshooting section)
2. Check **README.md** (Troubleshooting section)
3. Check **AGENT_INSTRUCTIONS.md** (Troubleshooting section)

### 📊 I Want to Run Analytics
1. Ensure gold layer is built (03-gold-layer executed)
2. See **README.md** (Business Use Cases section)
3. Adapt sample queries to your needs

### 🤖 I'm an AI Agent
1. Read **AGENT_INSTRUCTIONS.md** first
2. Follow the step-by-step instructions exactly
3. Validate at each checkpoint
4. If errors occur, check Troubleshooting section

### 📦 I Want to Deploy to Production
1. Read **README.md** (Deployment Guide section)
2. Parameterize notebooks (add widgets)
3. Create Databricks Job with 4 tasks
4. Set up monitoring and alerts

---

## ✅ Quick Validation

After setup, run this query to confirm everything works:

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

**Expected Output**:
* Italy & Spain: LCR < 1.0 (High Risk, Non-Compliant)
* UK & Poland: LCR ~ 0.9-1.1 (Medium Risk)
* Germany, France, Switzerland, Sweden: LCR >= 1.0 (Low Risk, Compliant)

---

## 📦 What's Included vs. What You Need to Add

### ✅ Included (Ready to Use)
* Complete documentation (README, AGENT_INSTRUCTIONS, SETUP)
* Project structure
* .gitignore
* LICENSE
* Placeholder notebooks

### ⚠️ You Need to Add
* **Notebook content**: Copy from original `liquidity_analysis` folder OR rebuild using AGENT_INSTRUCTIONS.md
* **Unity Catalog setup**: Run SQL from SETUP.md
* **Data generation**: Execute 00-data-generation notebook

---

## 🔗 Related Files

All documentation cross-references:
* **README.md** links to AGENT_INSTRUCTIONS.md for rebuild instructions
* **AGENT_INSTRUCTIONS.md** references README.md for architecture context
* **SETUP.md** points to README.md for detailed documentation
* **NOTEBOOK_COPY_INSTRUCTIONS.md** suggests AGENT_INSTRUCTIONS.md as alternative

---

**This project is git-ready!** 🎉

Simply:
1. Copy notebook content (see NOTEBOOK_COPY_INSTRUCTIONS.md)
2. Initialize git repo: `git init`
3. Add files: `git add .`
4. Commit: `git commit -m "Initial commit: LCR Management Platform"`
5. Push to your remote repo

---

*Last Updated: June 27, 2026*  
*Version: 1.0.0*