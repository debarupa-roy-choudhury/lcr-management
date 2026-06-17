# Treasury Liquidity Risk Platform — Full Databricks Implementation Guide

> **Who this guide is for:** Beginners to data engineering who want to learn by building a complete, working liquidity risk pipeline on **Azure Databricks**. No prior Databricks, Spark, or Python experience is assumed — concepts are explained as we go.

This guide implements the **same business objectives** as `instruction.md` entirely on Databricks:

1. Ingest daily liquidity feeds (Cash Balances, HQLA, Collateral).
2. Load and transform into a **Liquidity Risk Mart** (Delta Lake + Unity Catalog).
3. Calculate **LCR** and intraday liquidity metrics.
4. Raise alerts for missing feeds, failed runs, and limit breaches.
5. Expose metrics via a **Lakeview Dashboard**.
6. Orchestrate with **Databricks Workflows** and manage with **Repos + Asset Bundles**.

> **Note:** This is a Databricks-native architecture. It does not use ADF, Azure SQL, Logic Apps, or App Service. See `azure.md` for the alternative Azure Portal path.

**Default region:** `West Europe`  
**Environment:** Dev (`liquidity_dev` catalog)  
**Estimated time:** 3–5 days for a first-time learner

---

## Table of Contents

0. [Beginner's Introduction — Read This First](#0-beginners-introduction--read-this-first)
1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites and Azure Resources](#2-prerequisites-and-azure-resources)
3. [Create Databricks Workspace](#3-create-databricks-workspace)
4. [Configure Unity Catalog and Storage](#4-configure-unity-catalog-and-storage)
5. [Create Raw Landing Zone (ADLS)](#5-create-raw-landing-zone-adls)
6. [Create the Liquidity Risk Mart (Delta Tables)](#6-create-the-liquidity-risk-mart-delta-tables)
7. [Upload Sample Feed Files](#7-upload-sample-feed-files)
8. [Configure Secrets, Cluster, and SQL Warehouse](#8-configure-secrets-cluster-and-sql-warehouse)
9. [Notebook 1 — Validate Feeds](#9-notebook-1--validate-feeds)
10. [Notebook 2 — Ingest Bronze Layer](#10-notebook-2--ingest-bronze-layer)
11. [Notebook 3 — Transform Silver Layer](#11-notebook-3--transform-silver-layer)
12. [Notebook 4 — Calculate Gold LCR Metrics](#12-notebook-4--calculate-gold-lcr-metrics)
13. [Notebook 5 — Update Run Summary](#13-notebook-5--update-run-summary)
14. [Notebook 6 — Send Alerts](#14-notebook-6--send-alerts)
15. [Create the Master Workflow Job](#15-create-the-master-workflow-job)
16. [Schedule the Daily Trigger](#16-schedule-the-daily-trigger)
17. [Build the Lakeview Dashboard](#17-build-the-lakeview-dashboard)
18. [Configure SQL Alerts](#18-configure-sql-alerts)
19. [Repos, Asset Bundles, and CI/CD](#19-repos-asset-bundles-and-cicd)
20. [Run End-to-End Test](#20-run-end-to-end-test)
21. [Acceptance Criteria Checklist](#21-acceptance-criteria-checklist)
22. [Glossary](#22-glossary)
23. [Troubleshooting FAQ](#23-troubleshooting-faq)

---

## 0. Beginner's Introduction — Read This First

### What is data engineering?

**Data engineering** is designing systems that move and transform data reliably from source systems to reports and regulators. You build **pipelines** — automated sequences that run every day without manual intervention.

In this project, you are the engineer who makes sure treasury staff see accurate **LCR (Liquidity Coverage Ratio)** numbers every morning.

### What is Databricks?

**Azure Databricks** is a cloud platform for data engineering and analytics built on **Apache Spark** (a system for processing large datasets in parallel). Instead of clicking through Azure Data Factory, you write **notebooks** (mix of code and documentation) and schedule them as **Jobs**.

**Why Databricks for learning data engineering?**

- You see the **actual transformation code** (Python/SQL), not just drag-and-drop boxes.
- **Delta Lake** gives you database-like reliability on files.
- **Unity Catalog** gives you a governed data catalog (who owns what tables).
- One platform handles ingest, transform, metrics, dashboard, and scheduling.

### What you will build (plain English)

Every business day:

1. Three **CSV files** land in cloud storage (ADLS).
2. A **scheduled job** wakes up at 7 AM and runs six **notebooks** in order.
3. Data flows through **bronze → silver → gold** layers (explained below).
4. **LCR** is calculated per entity and currency.
5. **Alerts** fire if feeds are missing or limits breached.
6. A **dashboard** shows results to treasury staff.

### The Medallion Architecture (bronze / silver / gold)

This is the most important data engineering pattern in this guide:

| Layer | Name | What it holds | Analogy |
|-------|------|---------------|---------|
| **Bronze** | Raw | Exact copy of CSV data + metadata | Photocopy of original documents |
| **Silver** | Cleansed | Typed, deduplicated, validated data | Edited draft — errors fixed |
| **Gold** | Business | Metrics and facts (LCR, positions) | Final published report numbers |

**Why three layers?**

- **Bronze** preserves raw data for audit ("what did the source system actually send?").
- **Silver** isolates cleaning logic from business logic.
- **Gold** is what dashboards and regulators read — trusted, aggregated metrics.

### Key business terms

| Term | Meaning |
|------|---------|
| **LCR** | Liquidity Coverage Ratio = HQLA ÷ net cash outflows. Must stay above 100% (1.0) per regulation. |
| **HQLA** | High-Quality Liquid Assets — cash and safe securities. |
| **Entity** | Legal banking unit (e.g. `BANK_UK`). |
| **BusinessDate** | The date the data refers to (parameter driving the whole pipeline). |
| **Feed** | One CSV file from an upstream system (balances, hqla, or collateral). |
| **Delta Lake** | File format (like Parquet) with ACID transactions — you can UPDATE/DELETE reliably. |
| **Unity Catalog** | Databricks' governance layer — catalogs, schemas, tables, permissions. |
| **Notebook** | Interactive document with code cells — the unit of work in Databricks. |
| **Workflow / Job** | Scheduled multi-step run of one or more notebooks. |
| **Widget** | Notebook input parameter (e.g. `business_date`). |
| **SQL Warehouse** | Compute for running SQL queries and dashboards. |

### How this guide differs from `azure.md`

| Concern | azure.md | This guide (databricks.md) |
|---------|----------|----------------------------|
| Storage | ADLS + Azure SQL | ADLS + Delta Lake tables |
| Orchestration | Azure Data Factory | Databricks Workflows |
| Transform logic | SQL stored procedures | PySpark notebooks |
| Alerts | Logic Apps | Notebook + SQL Alerts + email |
| Dashboard | Custom web app (App Service) | Lakeview Dashboard |
| CI/CD | Azure DevOps for ADF + app | Repos + Asset Bundles |

Both achieve the same business outcome — choose one path to learn, or both to compare approaches.

### How to use this guide

1. Read Section 0 and Section 1 fully before creating anything.
2. Follow sections **in order** — each builds on the previous.
3. **Run notebooks one at a time** before wiring the full job.
4. Keep a secrets file (never commit to Git) for storage keys, webhook URLs, etc.
5. Use Section 23 when stuck — most beginner issues are listed there.

---

## 1. Architecture Overview

### Visual diagram

```
Upstream bank systems
        │  (drop 3 CSV files daily)
        ▼
┌───────────────────────────────────────────────────────────────┐
│  ADLS Gen2  (stliquiditydbxdev001 / container: datalake)      │
│  raw/liquidity/{balances|hqla|collateral}/{yyyy}/{MM}/{dd}/   │
└───────────────────────────────────────────────────────────────┘
        │
        ▼  Databricks Workflow: job_liq_daily_master (07:00 daily)
┌───────────────────────────────────────────────────────────────┐
│  01_validate_feeds    →  Did all 3 files arrive?              │
│  02_ingest_bronze     →  bronze.* tables (raw Delta)          │
│  03_transform_silver  →  silver.* + some gold tables        │
│  04_calculate_gold_lcr →  gold.fact_lcr (LCR metrics)         │
│  05_run_summary       →  control.liquidity_run_summary        │
│  06_send_alerts       →  Email / Teams webhook                │
└───────────────────────────────────────────────────────────────┘
        │
        ├──────────────────────┬──────────────────────┐
        ▼                      ▼                      ▼
  Lakeview Dashboard    SQL Alerts            Job run history
  (LCR, runs, feeds)    (email on breach)     (audit trail)
```

### Unity Catalog layout

Think of Unity Catalog like a folder tree for data:

```
liquidity_dev                    ← catalog (top-level project)
├── bronze                       ← raw ingested feeds
│   ├── balances
│   ├── hqla
│   └── collateral
├── silver                       ← cleansed staging
│   ├── balances
│   ├── hqla
│   └── collateral
├── gold                         ← business metrics
│   ├── fact_lcr
│   ├── fact_liquidity_positions
│   └── fact_intraday_liquidity
├── reference                    ← dimension/lookup tables
│   ├── dim_entity
│   ├── dim_currency
│   └── dim_time_bucket
└── control                      ← pipeline audit
    ├── liquidity_run_summary
    └── feed_status
```

**Full table name format:** `liquidity_dev.gold.fact_lcr` (catalog.schema.table)

---

## 2. Prerequisites and Azure Resources

### What you need

| Requirement | Why | Notes |
|-------------|-----|-------|
| Azure subscription | Hosts all cloud resources | Free trial works for learning |
| Contributor access | Create resources | Ask admin if using company subscription |
| Email address | Job failure notifications, SQL alerts | Any email you can check |
| Basic Python reading ability | Notebooks use Python | You don't need to be an expert — copy the code provided |
| Premium Databricks SKU | Unity Catalog requires Premium | ~$0.55/DBU + compute costs |

### Create a credentials notebook (on your laptop)

Save locally as `liquidity-dbx-secrets.txt` — **never commit to Git**:

```
Resource group:      rg-liquidity-dbx-dev
Storage account:     stliquiditydbxdev001
Databricks workspace: dbw-liquidity-dev
Catalog:             liquidity_dev
Your email:          (for alerts)
Webhook URL:         (optional, Section 14)
```

### Naming (Dev environment)

| Resource | Name | Notes |
|----------|------|-------|
| Resource group | `rg-liquidity-dbx-dev` | Separate from azure.md resources |
| ADLS storage account | `stliquiditydbxdev001` | Globally unique — adjust suffix |
| Databricks workspace | `dbw-liquidity-dev` | |
| Unity Catalog | `liquidity_dev` | Underscore, not hyphen |
| Master workflow job | `job_liq_daily_master` | |
| SQL Warehouse | `wh-liquidity-dev` | For dashboard SQL |

**Estimated Dev cost:** $100–200/month if left running 24/7 — **stop SQL Warehouse** and use job clusters (they terminate after each run) to save money.

---

## 3. Create Databricks Workspace

### What is a Databricks workspace?

A **workspace** is your team's private Databricks environment — notebooks, jobs, dashboards, and data catalog all live here. It is an Azure resource you create in the portal, then "launch" into a web UI.

### Step-by-step (Azure Portal)

1. Sign in to [Azure Portal](https://portal.azure.com).
2. Top search bar → **Azure Databricks** → Enter.
3. Click **+ Create**.
4. **Basics** tab:
   - **Subscription:** yours
   - **Resource group:** click **Create new** → type `rg-liquidity-dbx-dev`
   - **Workspace name:** `dbw-liquidity-dev`
   - **Region:** **(Europe) West Europe**
   - **Pricing Tier:** **Premium** ← required for Unity Catalog; do not pick Standard
5. **Review + create** → **Create**.
6. Wait ~3–5 minutes. Click **Go to resource**.
7. Click **Launch workspace** — opens Databricks UI in a new tab.

**What success looks like:** You land on the Databricks home page with "Welcome" and left sidebar (Workspace, Recents, Catalog, etc.).

### Enable Unity Catalog (first-time setup)

If a setup wizard appears:

1. Select **Quickstart** (fastest) or **Manual**.
2. **Metastore region:** West Europe (must match workspace region).
3. If asked to create a metastore — click **Create** (metastore is the top-level container for all catalogs in your organization).
4. Assign metastore to `dbw-liquidity-dev`.
5. Confirm your user has **Metastore Admin** role (Account Console → User management if not).

**What is Unity Catalog?** A centralized governance system — you register tables once, control permissions, and query them from anywhere in Databricks.

**If no wizard appears:** Unity Catalog may already be enabled. Check left sidebar for **Catalog** icon — if present, proceed to Section 4.

---

## 4. Configure Unity Catalog and Storage

This section connects Databricks to your data lake and creates the catalog structure.

### 4.1 Create ADLS storage account

**What is ADLS here?** The landing zone where upstream CSV files sit before Databricks reads them. Same concept as in `azure.md`, but Databricks reads files directly via Spark.

1. Azure Portal → **Storage accounts** → **+ Create**.
2. Fill in:
   - **Resource group:** `rg-liquidity-dbx-dev`
   - **Storage account name:** `stliquiditydbxdev001` (lowercase, no hyphens)
   - **Region:** West Europe
   - **Performance:** Standard
   - **Redundancy:** LRS (cheapest for Dev)
3. **Advanced** tab:
   - **Enable hierarchical namespace:** **ON** ← critical for ADLS Gen2
4. **Review + create** → **Create**.

**Verify:** Storage account → **Settings → Configuration** → Hierarchical namespace = **Enabled**.

### 4.2 Create storage credential and external location

This tells Unity Catalog **how to authenticate** to your storage account.

**In Databricks workspace:**

1. Left sidebar → **Catalog** → click **External Data** (gear or catalog explorer).
2. **Credentials** tab → **Create credential**:
   - **Type:** Azure Managed Identity (recommended — no keys to rotate)
   - **Name:** `cred-liquidity-adls`
   - Follow UI to create — note the **Access Connector** name shown.

3. **Grant storage permission (Azure Portal):**
   - Open `stliquiditydbxdev001` → **Access control (IAM)** → **+ Add → Add role assignment**
   - **Role:** Storage Blob Data Contributor
   - **Members:** search for the Databricks Access Connector name from step 2
   - **Save** (propagation takes 1–5 minutes)

4. Back in Databricks → **External locations** → **Create**:
   - **Name:** `el-liquidity-datalake`
   - **URL:** `abfss://datalake@stliquiditydbxdev001.dfs.core.windows.net/`
     - `abfss://` = Azure Blob File System Secure (how Spark addresses ADLS)
     - `datalake` = container name (you create it in Section 5)
   - **Credential:** `cred-liquidity-adls`
   - **Create**

**Common beginner mistake:** Forgetting IAM role assignment — you'll get "403 Forbidden" when reading files later.

### 4.3 Create catalog and schemas

**Where to run SQL:** Databricks → **SQL** → **SQL Editor** (or create a notebook with `%sql` cells).

Select a SQL Warehouse (create one in Section 8 if prompted) or use **hive_metastore** preview for DDL only.

Run this script **line by line or all at once**:

```sql
CREATE CATALOG IF NOT EXISTS liquidity_dev
MANAGED LOCATION 'abfss://datalake@stliquiditydbxdev001.dfs.core.windows.net/unity/liquidity_dev';

USE CATALOG liquidity_dev;

CREATE SCHEMA IF NOT EXISTS bronze   COMMENT 'Raw ingested feeds';
CREATE SCHEMA IF NOT EXISTS silver   COMMENT 'Cleansed staging layer';
CREATE SCHEMA IF NOT EXISTS gold     COMMENT 'Business metrics and facts';
CREATE SCHEMA IF NOT EXISTS reference COMMENT 'Dimension tables';
CREATE SCHEMA IF NOT EXISTS control  COMMENT 'Run summary and feed tracking';
```

**Grant yourself permissions** (replace with your Databricks login email):

```sql
GRANT USE CATALOG ON CATALOG liquidity_dev TO `your.email@company.com`;
GRANT ALL PRIVILEGES ON SCHEMA bronze TO `your.email@company.com`;
GRANT ALL PRIVILEGES ON SCHEMA silver TO `your.email@company.com`;
GRANT ALL PRIVILEGES ON SCHEMA gold TO `your.email@company.com`;
GRANT ALL PRIVILEGES ON SCHEMA reference TO `your.email@company.com`;
GRANT ALL PRIVILEGES ON SCHEMA control TO `your.email@company.com`;
```

**Verify:** Catalog explorer (left sidebar → Catalog) → expand `liquidity_dev` → see five schemas.

---

## 5. Create Raw Landing Zone (ADLS)

### What is a landing zone?

The **landing zone** is where files arrive **before** any processing. Upstream systems (or you, for testing) upload CSV files here. Databricks notebooks read from these paths.

### Step-by-step (Azure Portal)

1. Portal → `stliquiditydbxdev001` → **Storage browser**.
2. **+ Container** → Name: `datalake` → Create.
3. Inside `datalake`, create folder structure using **Add directory**:

```
raw/
  liquidity/
    balances/
    hqla/
    collateral/
```

Date subfolders (`2026/06/17/`) are created when you upload files in Section 7.

**Path convention:**

```
abfss://datalake@stliquiditydbxdev001.dfs.core.windows.net/raw/liquidity/balances/2026/06/17/balances_2026-06-17.csv
         ^container  ^storage account                              ^folder path inside container
```

---

## 6. Create the Liquidity Risk Mart (Delta Tables)

### What are Delta tables?

**Delta Lake** stores data as Parquet files but adds a transaction log — so you get:

- Reliable **overwrites** (replace one day's data without breaking the table)
- **Time travel** (query yesterday's version)
- **Schema enforcement** (reject bad columns)

In SQL you write `USING DELTA` — Databricks handles the rest.

### How to run DDL

1. Databricks → **SQL Editor**.
2. Ensure catalog context shows `liquidity_dev` (dropdown at top).
3. Paste each block below and click **Run**.

### 6.1 Reference (dimension) tables

**Dimensions** are lookup tables — entities, currencies, time buckets. They rarely change.

```sql
USE CATALOG liquidity_dev;
USE SCHEMA reference;

CREATE TABLE IF NOT EXISTS dim_entity (
  EntityId     INT GENERATED ALWAYS AS IDENTITY,
  EntityCode   STRING NOT NULL,
  EntityName   STRING NOT NULL
) USING DELTA;

CREATE TABLE IF NOT EXISTS dim_currency (
  CurrencyCode STRING NOT NULL,
  Description  STRING NOT NULL
) USING DELTA;

CREATE TABLE IF NOT EXISTS dim_time_bucket (
  BucketId        INT GENERATED ALWAYS AS IDENTITY,
  BucketName      STRING NOT NULL,
  StartDayOffset  INT NOT NULL,
  EndDayOffset    INT NOT NULL
) USING DELTA;

-- Seed reference data (run once)
INSERT INTO dim_entity (EntityCode, EntityName) VALUES
  ('BANK_UK', 'UK Banking Entity'),
  ('BANK_EU', 'EU Banking Entity');

INSERT INTO dim_currency (CurrencyCode, Description) VALUES
  ('GBP', 'British Pound'),
  ('EUR', 'Euro'),
  ('USD', 'US Dollar');

INSERT INTO dim_time_bucket (BucketName, StartDayOffset, EndDayOffset) VALUES
  ('0-7 days',   0,  7),
  ('8-30 days',  8, 30),
  ('31-90 days', 31, 90);
```

**Verify:** `SELECT * FROM liquidity_dev.reference.dim_entity;` returns 2 rows.

### 6.2 Bronze tables

Bronze = raw ingested data. Extra columns: `LoadTimestamp` (when loaded), `SourceFile` (where it came from).

```sql
USE SCHEMA bronze;

CREATE TABLE IF NOT EXISTS balances (
  BusinessDate  DATE,
  Entity        STRING,
  AccountId     STRING,
  Currency      STRING,
  Balance       DECIMAL(18,2),
  IntradayTime  TIMESTAMP,
  LoadTimestamp TIMESTAMP,
  SourceFile    STRING
) USING DELTA
PARTITIONED BY (BusinessDate);

CREATE TABLE IF NOT EXISTS hqla (
  BusinessDate       DATE,
  Entity             STRING,
  SecurityId         STRING,
  Currency           STRING,
  MarketValue        DECIMAL(18,2),
  HQLALevel          STRING,
  HaircutPercentage  DECIMAL(5,2),
  LoadTimestamp      TIMESTAMP,
  SourceFile         STRING
) USING DELTA
PARTITIONED BY (BusinessDate);

CREATE TABLE IF NOT EXISTS collateral (
  BusinessDate       DATE,
  Entity             STRING,
  AssetId            STRING,
  Currency           STRING,
  PledgedFlag        STRING,
  EncumberedAmount   DECIMAL(18,2),
  LoadTimestamp      TIMESTAMP,
  SourceFile         STRING
) USING DELTA
PARTITIONED BY (BusinessDate);
```

**What is PARTITIONED BY?** Data is physically grouped by `BusinessDate` — queries for one day are faster and overwrites affect only that partition.

### 6.3 Silver tables

Silver = cleansed data. Same business columns as bronze minus audit columns like `SourceFile`.

```sql
USE SCHEMA silver;

CREATE TABLE IF NOT EXISTS balances (
  BusinessDate  DATE,
  Entity        STRING,
  AccountId     STRING,
  Currency      STRING,
  Balance       DECIMAL(18,2),
  IntradayTime  TIMESTAMP,
  LoadTimestamp TIMESTAMP
) USING DELTA
PARTITIONED BY (BusinessDate);

CREATE TABLE IF NOT EXISTS hqla (
  BusinessDate       DATE,
  Entity             STRING,
  SecurityId         STRING,
  Currency           STRING,
  MarketValue        DECIMAL(18,2),
  HQLALevel          STRING,
  HaircutPercentage  DECIMAL(5,2),
  LoadTimestamp      TIMESTAMP
) USING DELTA
PARTITIONED BY (BusinessDate);

CREATE TABLE IF NOT EXISTS collateral (
  BusinessDate       DATE,
  Entity             STRING,
  AssetId            STRING,
  Currency           STRING,
  PledgedFlag        STRING,
  EncumberedAmount   DECIMAL(18,2),
  LoadTimestamp      TIMESTAMP
) USING DELTA
PARTITIONED BY (BusinessDate);
```

### 6.4 Gold fact tables

Gold = business-ready metrics consumed by dashboards and regulators.

```sql
USE SCHEMA gold;

CREATE TABLE IF NOT EXISTS fact_liquidity_positions (
  BusinessDate     DATE,
  Entity           STRING,
  Currency         STRING,
  BucketId         INT,
  CashFlowAmount   DECIMAL(18,2),
  IsInflow         BOOLEAN,
  IsOutflow        BOOLEAN
) USING DELTA
PARTITIONED BY (BusinessDate);

CREATE TABLE IF NOT EXISTS fact_intraday_liquidity (
  BusinessDate      DATE,
  Entity            STRING,
  Currency          STRING,
  IntradayTime      TIMESTAMP,
  Balance           DECIMAL(18,2),
  CumulativeBalance DECIMAL(18,2)
) USING DELTA
PARTITIONED BY (BusinessDate);

CREATE TABLE IF NOT EXISTS fact_lcr (
  BusinessDate                DATE,
  Entity                      STRING,
  Currency                    STRING,
  TotalHQLAAfterHaircut       DECIMAL(18,2),
  TotalNetCashOutflows        DECIMAL(18,2),
  LiquidityBuffer             DECIMAL(18,2),
  LCR                         DECIMAL(9,4),
  RegulatoryLimit             DECIMAL(9,4),
  InternalLimit               DECIMAL(9,4),
  IsBelowRegulatoryLCR        BOOLEAN,
  IsBelowInternalLCRLimit     BOOLEAN,
  IsLiquidityBufferBelowLimit BOOLEAN,
  CalculatedAt                TIMESTAMP
) USING DELTA
PARTITIONED BY (BusinessDate);
```

**fact_lcr** is the star table — daily LCR per entity and currency with breach flags.

### 6.5 Control tables

Control tables track **pipeline health** — did feeds arrive? did the job succeed?

```sql
USE SCHEMA control;

CREATE TABLE IF NOT EXISTS liquidity_run_summary (
  RunId                       BIGINT GENERATED ALWAYS AS IDENTITY,
  BusinessDate                DATE,
  Entity                      STRING,
  Status                      STRING,
  AllFeedsReceived            BOOLEAN,
  LCR                         DECIMAL(9,4),
  IsBelowRegulatoryLCR        BOOLEAN,
  IsBelowInternalLCRLimit     BOOLEAN,
  IsLiquidityBufferBelowLimit BOOLEAN,
  ExecutionStartTime          TIMESTAMP,
  ExecutionEndTime            TIMESTAMP,
  ErrorMessage                STRING,
  JobRunId                    STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS feed_status (
  BusinessDate   DATE,
  FeedName       STRING,
  Received       BOOLEAN,
  RecordCount    BIGINT,
  SourceFile     STRING,
  CheckedAt      TIMESTAMP
) USING DELTA
PARTITIONED BY (BusinessDate);
```

**Checkpoint:** Catalog explorer shows all tables under `liquidity_dev`. Count should be 14+ tables.

---

## 7. Upload Sample Feed Files

You need real files to test the pipeline. Create them on your computer.

### How to create CSV files

1. Open Notepad, VS Code, or Excel.
2. First row = column headers (exact spelling matters).
3. Save as `.csv` (UTF-8).
4. Upload via Azure Portal or [Azure Storage Explorer](https://azure.microsoft.com/products/storage/storage-explorer/) (recommended for beginners).

### 7.1 Balances file

**Local file name:** `balances_2026-06-17.csv`  
**Upload to:** `datalake/raw/liquidity/balances/2026/06/17/`

Create folders `2026`, `06`, `17` if they don't exist.

```csv
BusinessDate,Entity,AccountId,Currency,Balance,IntradayTime
2026-06-17,BANK_UK,ACC001,GBP,50000000.00,2026-06-17T09:00:00
2026-06-17,BANK_UK,ACC002,GBP,-12000000.00,2026-06-17T09:00:00
2026-06-17,BANK_UK,ACC003,USD,8000000.00,2026-06-17T12:00:00
2026-06-17,BANK_EU,ACC101,EUR,35000000.00,2026-06-17T09:00:00
2026-06-17,BANK_EU,ACC102,EUR,-5000000.00,
```

**Column notes:**
- `Balance` can be negative (overdraft / outflow).
- `IntradayTime` can be empty if not an intraday update.

### 7.2 HQLA file

**Path:** `datalake/raw/liquidity/hqla/2026/06/17/hqla_2026-06-17.csv`

```csv
BusinessDate,Entity,SecurityId,Currency,MarketValue,HQLALevel,HaircutPercentage
2026-06-17,BANK_UK,GBR_GOV_001,GBP,30000000.00,HQLA1,0.00
2026-06-17,BANK_UK,CORP_BOND_01,GBP,10000000.00,HQLA2A,15.00
2026-06-17,BANK_EU,DEU_GOV_001,EUR,25000000.00,HQLA1,0.00
2026-06-17,BANK_EU,CORP_BOND_02,EUR,8000000.00,HQLA2B,25.00
```

**HQLALevel:** Regulators classify assets as HQLA1 (best), HQLA2A, HQLA2B (more haircuts).

**HaircutPercentage:** Percentage reduction in value for liquidity purposes (15% haircut → only 85% counts).

### 7.3 Collateral file

**Path:** `datalake/raw/liquidity/collateral/2026/06/17/collateral_2026-06-17.csv`

```csv
BusinessDate,Entity,AssetId,Currency,PledgedFlag,EncumberedAmount
2026-06-17,BANK_UK,ASSET001,GBP,Y,5000000.00
2026-06-17,BANK_UK,ASSET002,GBP,N,0.00
2026-06-17,BANK_EU,ASSET101,EUR,Y,3000000.00
2026-06-17,BANK_EU,ASSET102,EUR,N,0.00
```

**PledgedFlag:** Y = asset is encumbered ( pledged as collateral, reduces available liquidity).

**Verify upload:** Storage browser → click file → Preview → rows look correct.

---

## 8. Configure Secrets, Cluster, and SQL Warehouse

### 8.1 Secret scope (optional — for webhooks)

**Secrets** store sensitive values (API keys, webhook URLs) securely — code references them by name, not plain text.

1. Databricks → **Settings** (user or admin) → **Developer** → **Secret scopes**.
2. **Create scope** → Name: `liquidity-secrets`.
3. Add secret (via CLI or UI if available):
   - Key: `alert-webhook-url`
   - Value: your Teams/Slack incoming webhook URL (optional — skip if using email only)

**Note:** With Managed Identity for ADLS, you do **not** need storage keys in secrets.

### 8.2 Job cluster (for pipeline runs)

When you create a Workflow job (Section 15), configure a **Job cluster** — a temporary cluster that starts for the job and stops afterward (saves money).

Recommended settings:

| Setting | Value | Why |
|---------|-------|-----|
| Runtime | 15.4 LTS | Long-term support — stable for learning |
| Node type | Standard_DS3_v2 | Enough memory for sample data |
| Workers | 2 | Parallelism for Spark |
| Mode | USER_ISOLATION or SINGLE_USER | Unity Catalog compatibility |

You don't need to create this separately — define it when creating the job.

### 8.3 SQL Warehouse (for dashboard and SQL Editor)

**SQL Warehouses** are compute for SQL queries and Lakeview dashboards — separate from notebook clusters.

1. Left sidebar → **SQL** → **SQL Warehouses**.
2. **Create SQL Warehouse**:
   - **Name:** `wh-liquidity-dev`
   - **Cluster size:** 2X-Small (fine for sample data)
   - **Auto stop:** 10 minutes (saves cost)
3. Click **Start** (warehouse must be running to query in SQL Editor).

**Cost tip:** Stop the warehouse when not using the dashboard.

---

## 9. Notebook 1 — Validate Feeds

### What does this notebook do?

Before processing, check that all three CSV files exist and contain data. Results are written to `control.feed_status`. If any feed is missing, the pipeline should fail early (fail-fast pattern).

### How to create a notebook

1. Workspace → **Create** → **Notebook**.
2. Name: `01_validate_feeds`
3. Default language: **Python**
4. Cluster: attach any small interactive cluster (or SQL warehouse for `%sql` only notebooks)

### Add a widget (input parameter)

At the top of the notebook, Databricks can show a text box for parameters:

```python
dbutils.widgets.text("business_date", "2026-06-17")
```

When the job runs, it passes `business_date` automatically. When you test manually, you type in the widget.

### Full notebook code

Copy into one or more cells and run:

```python
# Databricks notebook source
import json
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, LongType, BooleanType, TimestampType, DateType

dbutils.widgets.text("business_date", "2026-06-17")
business_date = dbutils.widgets.get("business_date")
yyyy, mm, dd = business_date[:4], business_date[5:7], business_date[8:10]

STORAGE = "stliquiditydbxdev001"
base = f"abfss://datalake@{STORAGE}.dfs.core.windows.net/raw/liquidity"

feeds = {
    "balances":   f"{base}/balances/{yyyy}/{mm}/{dd}/balances_{business_date}.csv",
    "hqla":       f"{base}/hqla/{yyyy}/{mm}/{dd}/hqla_{business_date}.csv",
    "collateral": f"{base}/collateral/{yyyy}/{mm}/{dd}/collateral_{business_date}.csv",
}

results = []
all_ok = True

for name, path in feeds.items():
    try:
        df = spark.read.option("header", True).csv(path)
        count = df.count()
        received = count > 0
        if not received:
            all_ok = False
        results.append((business_date, name, received, count, path))
        print(f"OK  {name}: {count} rows at {path}")
    except Exception as e:
        all_ok = False
        results.append((business_date, name, False, 0, path))
        print(f"ERROR — {name}: {e}")

schema = StructType([
    StructField("BusinessDate", DateType()),
    StructField("FeedName", StringType()),
    StructField("Received", BooleanType()),
    StructField("RecordCount", LongType()),
    StructField("SourceFile", StringType()),
])

feed_df = spark.createDataFrame(results, schema) \
    .withColumn("CheckedAt", F.current_timestamp())

feed_df.write.format("delta").mode("overwrite") \
    .option("replaceWhere", f"BusinessDate = '{business_date}'") \
    .saveAsTable("liquidity_dev.control.feed_status")

if not all_ok:
    raise Exception(f"Missing feeds for BusinessDate={business_date}")
else:
    print("All feeds validated successfully.")
```

### Line-by-line explanation (key parts)

| Code | Meaning |
|------|---------|
| `dbutils.widgets.get(...)` | Read the `business_date` parameter |
| `abfss://datalake@...` | Path to ADLS file in Spark |
| `spark.read.csv(...)` | Read CSV into a DataFrame (distributed table in memory) |
| `.count()` | Number of rows — triggers actual file read |
| `.saveAsTable(...)` | Write results to Unity Catalog Delta table |
| `replaceWhere` | Overwrite only rows for this BusinessDate, keep other dates |
| `raise Exception(...)` | Fail the notebook — stops downstream job tasks |

### Test manually

1. Run all cells with `business_date = 2026-06-17`.
2. SQL Editor: `SELECT * FROM liquidity_dev.control.feed_status;`
3. Expect 3 rows, all `Received = true`.

---

## 10. Notebook 2 — Ingest Bronze Layer

### What does this notebook do?

Reads each CSV from ADLS and writes a **typed copy** into bronze Delta tables. This is the **Extract + Load** part of ETL (transform happens in notebook 3).

Create notebook `02_ingest_bronze` and paste:

```python
# Databricks notebook source
from pyspark.sql import functions as F

dbutils.widgets.text("business_date", "2026-06-17")
business_date = dbutils.widgets.get("business_date")
yyyy, mm, dd = business_date[:4], business_date[5:7], business_date[8:10]

STORAGE = "stliquiditydbxdev001"
base = f"abfss://datalake@{STORAGE}.dfs.core.windows.net/raw/liquidity"
load_ts = F.current_timestamp()

feed_config = [
    ("balances",   f"{base}/balances/{yyyy}/{mm}/{dd}/balances_{business_date}.csv",   "liquidity_dev.bronze.balances"),
    ("hqla",       f"{base}/hqla/{yyyy}/{mm}/{dd}/hqla_{business_date}.csv",           "liquidity_dev.bronze.hqla"),
    ("collateral", f"{base}/collateral/{yyyy}/{mm}/{dd}/collateral_{business_date}.csv", "liquidity_dev.bronze.collateral"),
]

for name, path, table in feed_config:
    df = spark.read.option("header", True).csv(path)
    df = df.withColumn("BusinessDate", F.to_date(F.lit(business_date))) \
           .withColumn("LoadTimestamp", load_ts) \
           .withColumn("SourceFile", F.lit(path))

    if name == "balances":
        df = df.withColumn("Balance", F.col("Balance").cast("decimal(18,2)")) \
               .withColumn("IntradayTime", F.to_timestamp("IntradayTime"))
    elif name == "hqla":
        df = df.withColumn("MarketValue", F.col("MarketValue").cast("decimal(18,2)")) \
               .withColumn("HaircutPercentage", F.col("HaircutPercentage").cast("decimal(5,2)"))
    elif name == "collateral":
        df = df.withColumn("EncumberedAmount", F.col("EncumberedAmount").cast("decimal(18,2)"))

    df.write.format("delta").mode("overwrite") \
        .option("replaceWhere", f"BusinessDate = '{business_date}'") \
        .saveAsTable(table)

    print(f"Ingested {name} → {table}: {df.count()} rows")
```

**Why cast columns?** CSV reads everything as strings — casting ensures `Balance` is numeric for math later.

**Verify:** `SELECT COUNT(*) FROM liquidity_dev.bronze.balances WHERE BusinessDate = '2026-06-17';` → 5 rows.

---

## 11. Notebook 3 — Transform Silver Layer

### What does this notebook do?

1. Copies bronze → silver with cleaning (dedup, valid HQLA levels, uppercase flags).
2. Builds `fact_liquidity_positions` (cash flows by time bucket).
3. Builds `fact_intraday_liquidity` (cumulative balance through the day).

Create notebook `03_transform_silver`:

```python
# Databricks notebook source
from pyspark.sql import functions as F
from pyspark.sql.window import Window

dbutils.widgets.text("business_date", "2026-06-17")
business_date = dbutils.widgets.get("business_date")

def bronze_to_silver(bronze_table, silver_table, extra_transform=None):
    df = spark.table(bronze_table).filter(F.col("BusinessDate") == business_date)
    df = df.drop("SourceFile")
    if extra_transform:
        df = extra_transform(df)
    df = df.dropDuplicates()
    df.write.format("delta").mode("overwrite") \
        .option("replaceWhere", f"BusinessDate = '{business_date}'") \
        .saveAsTable(silver_table)
    return df.count()

n1 = bronze_to_silver("liquidity_dev.bronze.balances", "liquidity_dev.silver.balances")
n2 = bronze_to_silver(
    "liquidity_dev.bronze.hqla", "liquidity_dev.silver.hqla",
    lambda df: df.filter(F.col("HQLALevel").isin("HQLA1", "HQLA2A", "HQLA2B"))
)
n3 = bronze_to_silver(
    "liquidity_dev.bronze.collateral", "liquidity_dev.silver.collateral",
    lambda df: df.withColumn("PledgedFlag", F.upper(F.col("PledgedFlag")))
)

balances = spark.table("liquidity_dev.silver.balances").filter(F.col("BusinessDate") == business_date)
buckets = spark.table("liquidity_dev.reference.dim_time_bucket")

positions = balances.groupBy("BusinessDate", "Entity", "Currency").agg(
    F.sum("Balance").alias("NetBalance")
).join(buckets.filter(F.col("BucketId") == 1)) \
 .select(
    "BusinessDate", "Entity", "Currency",
    F.col("BucketId"),
    F.abs("NetBalance").alias("CashFlowAmount"),
    (F.col("NetBalance") >= 0).alias("IsInflow"),
    (F.col("NetBalance") < 0).alias("IsOutflow")
)

positions.write.format("delta").mode("overwrite") \
    .option("replaceWhere", f"BusinessDate = '{business_date}'") \
    .saveAsTable("liquidity_dev.gold.fact_liquidity_positions")

w = Window.partitionBy("BusinessDate", "Entity", "Currency").orderBy("IntradayTime")
intraday = balances.filter(F.col("IntradayTime").isNotNull()) \
    .withColumn("CumulativeBalance", F.sum("Balance").over(w))

intraday.select("BusinessDate", "Entity", "Currency", "IntradayTime",
                "Balance", "CumulativeBalance") \
    .write.format("delta").mode("overwrite") \
    .option("replaceWhere", f"BusinessDate = '{business_date}'") \
    .saveAsTable("liquidity_dev.gold.fact_intraday_liquidity")

print(f"Silver transform complete: balances={n1}, hqla={n2}, collateral={n3}")
```

**Window function explained:** `F.sum("Balance").over(w)` computes a **running total** ordered by `IntradayTime` — "how much cash did we have at each point during the day?"

---

## 12. Notebook 4 — Calculate Gold LCR Metrics

### What is LCR (simplified)?

```
LCR = Total HQLA (after haircuts) / Total Net Cash Outflows over 30 days
```

- **LCR ≥ 100% (1.0):** Regulatory minimum met.
- **Internal limit** (e.g. 110%): Bank's stricter policy.

This notebook implements a **learning simplified formula** — real banks use detailed regulatory formulas.

Create notebook `04_calculate_gold_lcr`:

```python
# Databricks notebook source
from pyspark.sql import functions as F

dbutils.widgets.text("business_date", "2026-06-17")
business_date = dbutils.widgets.get("business_date")

REGULATORY_LIMIT = 1.0000
INTERNAL_LIMIT   = 1.1000
BUFFER_MINIMUM   = 0.00

hqla = spark.table("liquidity_dev.silver.hqla").filter(F.col("BusinessDate") == business_date)
balances = spark.table("liquidity_dev.silver.balances").filter(F.col("BusinessDate") == business_date)
collateral = spark.table("liquidity_dev.silver.collateral").filter(F.col("BusinessDate") == business_date)

hqla_adj = hqla.withColumn(
    "HQLAAfterHaircut",
    F.col("MarketValue") * (1 - F.col("HaircutPercentage") / 100)
)
hqla_agg = hqla_adj.groupBy("BusinessDate", "Entity", "Currency").agg(
    F.sum("HQLAAfterHaircut").alias("TotalHQLAAfterHaircut")
)

outflows_bal = balances.groupBy("BusinessDate", "Entity", "Currency").agg(
    F.sum(F.when(F.col("Balance") < 0, F.abs(F.col("Balance"))).otherwise(0))
     .alias("BalanceOutflows")
)
encumbered = collateral.filter(F.col("PledgedFlag") == "Y") \
    .groupBy("BusinessDate", "Entity", "Currency").agg(
        F.sum("EncumberedAmount").alias("EncumberedOutflows")
    )

outflows = outflows_bal.join(encumbered, ["BusinessDate", "Entity", "Currency"], "left") \
    .withColumn("EncumberedOutflows", F.coalesce(F.col("EncumberedOutflows"), F.lit(0))) \
    .withColumn("TotalNetCashOutflows",
        F.col("BalanceOutflows") + F.col("EncumberedOutflows"))

lcr_df = hqla_agg.join(outflows, ["BusinessDate", "Entity", "Currency"], "outer") \
    .withColumn("TotalHQLAAfterHaircut", F.coalesce(F.col("TotalHQLAAfterHaircut"), F.lit(0))) \
    .withColumn("TotalNetCashOutflows", F.coalesce(F.col("TotalNetCashOutflows"), F.lit(0))) \
    .withColumn("LiquidityBuffer",
        F.col("TotalHQLAAfterHaircut") - F.col("TotalNetCashOutflows")) \
    .withColumn("LCR",
        F.when(F.col("TotalNetCashOutflows") > 0,
               F.col("TotalHQLAAfterHaircut") / F.col("TotalNetCashOutflows"))
         .otherwise(F.lit(9999.0))) \
    .withColumn("RegulatoryLimit", F.lit(REGULATORY_LIMIT)) \
    .withColumn("InternalLimit", F.lit(INTERNAL_LIMIT)) \
    .withColumn("IsBelowRegulatoryLCR", F.col("LCR") < F.col("RegulatoryLimit")) \
    .withColumn("IsBelowInternalLCRLimit", F.col("LCR") < F.col("InternalLimit")) \
    .withColumn("IsLiquidityBufferBelowLimit", F.col("LiquidityBuffer") < F.lit(BUFFER_MINIMUM)) \
    .withColumn("CalculatedAt", F.current_timestamp())

lcr_df.select(
    "BusinessDate", "Entity", "Currency",
    "TotalHQLAAfterHaircut", "TotalNetCashOutflows", "LiquidityBuffer",
    "LCR", "RegulatoryLimit", "InternalLimit",
    "IsBelowRegulatoryLCR", "IsBelowInternalLCRLimit", "IsLiquidityBufferBelowLimit",
    "CalculatedAt"
).write.format("delta").mode("overwrite") \
    .option("replaceWhere", f"BusinessDate = '{business_date}'") \
    .saveAsTable("liquidity_dev.gold.fact_lcr")

display(lcr_df)
print("LCR calculation complete.")
```

**Verify:** `SELECT Entity, Currency, LCR, IsBelowRegulatoryLCR FROM liquidity_dev.gold.fact_lcr;`

Expected approximate results with sample data:

| Entity | Currency | ~LCR |
|--------|----------|------|
| BANK_UK | GBP | 2.3 (230%) |
| BANK_EU | EUR | 3.9 (387%) |

---

## 13. Notebook 5 — Update Run Summary

### What does this notebook do?

Writes one row per entity into `liquidity_run_summary` — the audit log answering: "Did today's job succeed? What was the LCR?"

Create notebook `05_run_summary`:

```python
# Databricks notebook source
import json
from datetime import datetime, timezone
from pyspark.sql import functions as F

dbutils.widgets.text("business_date", "2026-06-17")
business_date = dbutils.widgets.get("business_date")

job_run_id = dbutils.notebook.entry_point.getDbutils().notebook().getContext().currentRunId().get()
start_time = datetime.now(timezone.utc)

feed_status = spark.table("liquidity_dev.control.feed_status") \
    .filter(F.col("BusinessDate") == business_date)
all_feeds = feed_status.filter(F.col("Received") == False).count() == 0

lcr = spark.table("liquidity_dev.gold.fact_lcr") \
    .filter(F.col("BusinessDate") == business_date)

end_time = datetime.now(timezone.utc)

rows = []
for row in lcr.collect():
    rows.append((
        business_date,
        row["Entity"],
        "Succeeded" if all_feeds else "Partial",
        all_feeds,
        float(row["LCR"]),
        bool(row["IsBelowRegulatoryLCR"]),
        bool(row["IsBelowInternalLCRLimit"]),
        bool(row["IsLiquidityBufferBelowLimit"]),
        start_time,
        end_time,
        None,
        str(job_run_id)
    ))

if not rows:
    rows.append((
        business_date, "ALL", "Failed", all_feeds,
        None, None, None, None,
        start_time, end_time,
        "No LCR rows calculated", str(job_run_id)
    ))

schema = """BusinessDate DATE, Entity STRING, Status STRING, AllFeedsReceived BOOLEAN,
            LCR DECIMAL(9,4), IsBelowRegulatoryLCR BOOLEAN, IsBelowInternalLCRLimit BOOLEAN,
            IsLiquidityBufferBelowLimit BOOLEAN, ExecutionStartTime TIMESTAMP,
            ExecutionEndTime TIMESTAMP, ErrorMessage STRING, JobRunId STRING"""

summary_df = spark.createDataFrame(rows, schema=schema)
summary_df.write.format("delta").mode("append").saveAsTable("liquidity_dev.control.liquidity_run_summary")

alert_payload = {
    "business_date": business_date,
    "all_feeds_received": all_feeds,
    "breaches": lcr.filter(
        F.col("IsBelowRegulatoryLCR") | F.col("IsBelowInternalLCRLimit") | F.col("IsLiquidityBufferBelowLimit")
    ).count(),
    "status": "Succeeded" if all_feeds and lcr.count() > 0 else "Partial"
}
dbutils.notebook.exit(json.dumps(alert_payload))
```

---

## 14. Notebook 6 — Send Alerts

### What does this notebook do?

Builds a human-readable alert message and optionally sends it to a Teams/Slack webhook. Also rely on **job email notifications** (Section 15) for failures.

Create notebook `06_send_alerts`:

```python
# Databricks notebook source
import json
import urllib.request
from pyspark.sql import functions as F

dbutils.widgets.text("business_date", "2026-06-17")
business_date = dbutils.widgets.get("business_date")

summary = spark.sql(f"""
    SELECT * FROM liquidity_dev.control.liquidity_run_summary
    WHERE BusinessDate = '{business_date}'
    ORDER BY RunId DESC LIMIT 10
""")

lcr = spark.table("liquidity_dev.gold.fact_lcr").filter(F.col("BusinessDate") == business_date)
feed = spark.table("liquidity_dev.control.feed_status").filter(F.col("BusinessDate") == business_date)

any_failed = summary.filter(F.col("Status") == "Failed").count() > 0
missing_feeds = feed.filter(F.col("Received") == False).count() > 0
any_breach = lcr.filter(
    F.col("IsBelowRegulatoryLCR") | F.col("IsBelowInternalLCRLimit") | F.col("IsLiquidityBufferBelowLimit")
).count() > 0

if any_failed or missing_feeds:
    subject = f"[HIGH] Liquidity Run {business_date} — Failed or Missing Feeds"
elif any_breach:
    subject = f"[RISK] Liquidity Run {business_date} — LCR Limit Breach"
else:
    subject = f"[INFO] Liquidity Run {business_date} — Completed Successfully"

body_lines = [subject, "", "LCR Summary:"]
for r in lcr.collect():
    body_lines.append(
        f"  {r['Entity']}/{r['Currency']}: LCR={float(r['LCR']):.2%} "
        f"(Reg breach={r['IsBelowRegulatoryLCR']})"
    )
body_lines.append("", "Feed Status:")
for r in feed.collect():
    body_lines.append(f"  {r['FeedName']}: received={r['Received']}, records={r['RecordCount']}")

message = "\n".join(body_lines)
print(message)

try:
    webhook = dbutils.secrets.get(scope="liquidity-secrets", key="alert-webhook-url")
    payload = json.dumps({"text": message}).encode("utf-8")
    req = urllib.request.Request(webhook, data=payload, headers={"Content-Type": "application/json"})
    urllib.request.urlopen(req)
    print("Webhook alert sent.")
except Exception as e:
    print(f"Webhook not configured or failed: {e}")
```

---

## 15. Create the Master Workflow Job

### What is a Databricks Job?

A **Job** runs one or more notebooks/tasks on a schedule or on demand. **Task dependencies** ensure notebook 2 only runs after notebook 1 succeeds.

### Step-by-step (UI)

1. Left sidebar → **Workflows** → **Create Job**.
2. **Job name:** `job_liq_daily_master`

### 15.1 Job parameter

Click **Job parameters** → **Add**:
- **Key:** `business_date`
- **Default:** `2026-06-17` (for testing; change to `{{job.start_time.iso_date}}` for production)

### 15.2 Add tasks

Click **Add task** for each row:

| Task key | Type | Notebook path | Depends on |
|----------|------|---------------|------------|
| `validate_feeds` | Notebook | `/Users/.../01_validate_feeds` | — |
| `ingest_bronze` | Notebook | `02_ingest_bronze` | `validate_feeds` |
| `transform_silver` | Notebook | `03_transform_silver` | `ingest_bronze` |
| `calculate_lcr` | Notebook | `04_calculate_gold_lcr` | `transform_silver` |
| `run_summary` | Notebook | `05_run_summary` | `calculate_lcr` |
| `send_alerts` | Notebook | `06_send_alerts` | `run_summary` |

For each task:
- **Compute:** select **Job cluster** → configure new cluster (Runtime 15.4 LTS, 2 workers, Standard_DS3_v2).
- **Parameters:** `business_date` = `{{job.parameters.business_date}}`

**To set dependency:** Task → **Depends on** → select upstream task.

### 15.3 Email on failure

Job → **Job details** → **Notifications** → **On failure** → add your email.

**What success looks like:** Job graph shows 6 tasks in a chain. "Run now" executes all green.

---

## 16. Schedule the Daily Trigger

1. Job page → **Add trigger** → **Scheduled**.
2. **Cron schedule:** `0 0 7 * * ?` = 07:00:00 every day.
3. **Timezone:** Europe/London (or your local).
4. **Status:** Unpause / Activate after successful manual test.

**Cron tip for beginners:** `0 0 7 * * ?` = second minute hour day month day-of-week. Databricks uses Quartz cron format.

---

## 17. Build the Lakeview Dashboard

### What is Lakeview?

**Lakeview** is Databricks' built-in dashboard tool — you write SQL, drag visualizations, share with colleagues. No custom web app needed.

### 17.1 Create dashboard

1. **New** → **Dashboard**.
2. Name: `Liquidity Risk Dashboard`.
3. Attach warehouse: `wh-liquidity-dev`.

### 17.2 Create datasets (SQL queries)

Click **Create from SQL** for each:

**Dataset 1 — Daily LCR View**

```sql
SELECT BusinessDate, Entity, Currency, LCR, RegulatoryLimit, InternalLimit,
       IsBelowRegulatoryLCR, IsBelowInternalLCRLimit, IsLiquidityBufferBelowLimit,
       TotalHQLAAfterHaircut, TotalNetCashOutflows, LiquidityBuffer
FROM liquidity_dev.gold.fact_lcr
ORDER BY BusinessDate DESC, Entity, Currency;
```

**Dataset 2 — Run Status**

```sql
SELECT RunId, BusinessDate, Entity, Status, AllFeedsReceived, LCR,
       ExecutionStartTime, ExecutionEndTime, ErrorMessage, JobRunId
FROM liquidity_dev.control.liquidity_run_summary
ORDER BY RunId DESC LIMIT 50;
```

**Dataset 3 — Feed Status**

```sql
SELECT BusinessDate, FeedName, Received, RecordCount, SourceFile, CheckedAt
FROM liquidity_dev.control.feed_status
WHERE BusinessDate = (SELECT MAX(BusinessDate) FROM liquidity_dev.control.feed_status)
ORDER BY FeedName;
```

**Dataset 4 — Intraday Liquidity**

```sql
SELECT BusinessDate, Entity, Currency, IntradayTime, Balance, CumulativeBalance
FROM liquidity_dev.gold.fact_intraday_liquidity
WHERE BusinessDate = (SELECT MAX(BusinessDate) FROM liquidity_dev.gold.fact_intraday_liquidity)
ORDER BY Entity, Currency, IntradayTime;
```

### 17.3 Add visualizations (beginner layout)

| Widget | Chart type | How to configure |
|--------|------------|------------------|
| LCR by Entity | Bar | X = Entity, Y = LCR, Color = IsBelowRegulatoryLCR |
| LCR Detail | Table | All columns; add conditional formatting on IsBelowRegulatoryLCR |
| Run Status | Table | Status, AllFeedsReceived, ExecutionStartTime |
| Feed Status | Table | FeedName, Received, RecordCount |
| Intraday line | Line | X = IntradayTime, Y = CumulativeBalance, Series = Entity |

### 17.4 Share

**Share** button → add colleagues → set **Can View** or **Can Edit**.

---

## 18. Configure SQL Alerts

### What are SQL Alerts?

Scheduled SQL queries that email you when a condition is true — e.g. "any entity below LCR limit today."

1. **SQL** → **Alerts** → **Create alert**.
2. Pick warehouse `wh-liquidity-dev`.
3. Write query returning a number.
4. Set condition (e.g. `> 0`).
5. Add email destination.
6. Set schedule (hourly or daily after job runs).

**Alert 1 — Regulatory LCR breach**

```sql
SELECT COUNT(*) AS breach_count
FROM liquidity_dev.gold.fact_lcr
WHERE BusinessDate = CURRENT_DATE()
  AND IsBelowRegulatoryLCR = true;
```

Condition: `breach_count > 0`

**Alert 2 — Missing feeds**

```sql
SELECT COUNT(*) AS missing_count
FROM liquidity_dev.control.feed_status
WHERE BusinessDate = CURRENT_DATE() AND Received = false;
```

Condition: `missing_count > 0`

**Alert 3 — Failed run**

```sql
SELECT COUNT(*) AS failed_runs
FROM liquidity_dev.control.liquidity_run_summary
WHERE BusinessDate = CURRENT_DATE() AND Status = 'Failed';
```

Condition: `failed_runs > 0`

---

## 19. Repos, Asset Bundles, and CI/CD

### Why version control?

Notebooks in the UI are hard to track. **Repos** connect Databricks to Git — every change is committed, reviewed, and deployable.

### 19.1 Create repo in Databricks

1. **Workspace** → **Repos** → **Add Repo**.
2. Connect Git provider (GitHub or Azure DevOps).
3. Clone URL: your `liquidity-databricks` repository.
4. Move notebooks into `/Repos/liquidity-databricks/notebooks/`.

### 19.2 Asset Bundle (infrastructure-as-code for Databricks)

`databricks.yml` defines jobs, clusters, and schedules in YAML — deploy with CLI:

```bash
pip install databricks-databricks-sdk
databricks configure --token
databricks bundle validate
databricks bundle deploy -t dev
```

See full `databricks.yml` in repo template (job definition with all 6 tasks, schedule, email notifications).

### 19.3 Azure DevOps pipeline

Store `DATABRICKS_HOST` and `DATABRICKS_TOKEN` as secrets. Pipeline runs `databricks bundle deploy` on every merge to `main`.

---

## 20. Run End-to-End Test

### Pre-flight checklist

- [ ] All 14+ Delta tables exist
- [ ] Sample CSV files uploaded for 2026-06-17
- [ ] Each notebook runs green individually
- [ ] SQL Warehouse started

### Manual job run

1. **Workflows** → `job_liq_daily_master` → **Run now**.
2. Parameter: `business_date = 2026-06-17`.
3. Watch run graph — all 6 tasks should succeed (~5–15 minutes first run due to cluster startup).

### Verification queries

```sql
SELECT COUNT(*) FROM liquidity_dev.silver.balances WHERE BusinessDate = '2026-06-17';
SELECT * FROM liquidity_dev.gold.fact_lcr WHERE BusinessDate = '2026-06-17';
SELECT * FROM liquidity_dev.control.liquidity_run_summary ORDER BY RunId DESC LIMIT 5;
SELECT * FROM liquidity_dev.control.feed_status WHERE BusinessDate = '2026-06-17';
```

### Negative tests (learn debugging)

1. **Missing feed:** Delete one CSV, re-run job → `validate_feeds` should fail, email arrives.
2. **LCR breach:** Edit HQLA CSV to very low values, re-run → SQL alert should fire.

---

## 21. Acceptance Criteria Checklist

| # | Objective | How to verify |
|---|-----------|---------------|
| 1 | Daily scheduled pipeline | Job trigger active; run history shows daily execution |
| 2 | Three feeds loaded | Silver tables have rows for BusinessDate |
| 3 | LCR calculated | `gold.fact_lcr` populated |
| 4 | Run summary written | `control.liquidity_run_summary` has rows |
| 5 | Alerts work | Email/webhook on failure or breach |
| 6 | Dashboard works | Lakeview shows LCR, runs, feeds |
| 7 | CI/CD | `databricks bundle deploy` succeeds |
| 8 | Audit trail | `DESCRIBE HISTORY liquidity_dev.gold.fact_lcr` shows versions |

---

## Recommended Build Order

1. Azure resources (RG, ADLS, Databricks workspace, Unity Catalog)
2. DDL — all tables
3. Upload sample CSVs
4. Notebooks 01 → 06 — test each alone
5. Workflow job with dependencies
6. Schedule trigger
7. Dashboard + SQL alerts
8. Repos + Asset Bundle

---

## 22. Glossary

| Term | Definition |
|------|------------|
| **abfss** | URI scheme for accessing ADLS from Spark |
| **Bronze layer** | Raw ingested data |
| **Catalog** | Top-level Unity Catalog container (like a database server) |
| **Cluster** | Compute resources running Spark |
| **DataFrame** | Spark table in memory — distributed rows and columns |
| **Delta Lake** | ACID transactional storage layer on Parquet files |
| **Gold layer** | Business-level aggregated metrics |
| **Job cluster** | Temporary cluster created per job run |
| **Lakeview** | Databricks dashboard product |
| **LCR** | Liquidity Coverage Ratio |
| **Medallion architecture** | Bronze → silver → gold layering pattern |
| **Metastore** | Unity Catalog root metadata store |
| **Notebook** | Databricks document with executable code cells |
| **Partition** | Physical grouping of data by column value (e.g. date) |
| **PySpark** | Python API for Spark |
| **Schema** | Namespace inside a catalog (like a SQL schema) |
| **Silver layer** | Cleansed, validated data |
| **SQL Warehouse** | Serverless SQL compute for queries/dashboards |
| **Unity Catalog** | Unified governance for tables and permissions |
| **Widget** | Notebook parameter input |
| **Workflow** | Databricks job with multiple tasks |

---

## 23. Troubleshooting FAQ

### "403 Forbidden" reading ADLS files

1. Check Managed Identity has **Storage Blob Data Contributor** on storage account.
2. Wait 5 minutes after IAM role assignment.
3. Verify external location URL matches container name (`datalake`).

### "Table not found" in notebook

1. Check three-part name: `liquidity_dev.bronze.balances`.
2. Run `SHOW TABLES IN liquidity_dev.bronze;`
3. Ensure DDL from Section 6 ran successfully.

### Cluster fails to start

1. Check subscription quota for cores in region.
2. Try smaller node type (Standard_DS3_v2).
3. Check if workspace is Premium and Unity Catalog enabled.

### Notebook works interactively but fails in job

1. Job must pass `business_date` parameter explicitly.
2. Job cluster needs same Unity Catalog access as your user.
3. Check job uses correct notebook path (Repos path vs workspace path).

### `replaceWhere` error on write

BusinessDate in data must match `replaceWhere` predicate exactly. Ensure `BusinessDate` column is DATE type, not string.

### SQL Warehouse won't start

Check subscription billing/credits. Try 2X-Small size. Contact admin if policy blocks warehouses.

### Dashboard shows no data

1. SQL Warehouse running?
2. Query returns rows in SQL Editor first?
3. Dataset pointing to correct catalog (`liquidity_dev`)?

### Job succeeds but LCR looks wrong

Expected for learning — simplified formula. Trace intermediate values:

```sql
SELECT * FROM liquidity_dev.silver.hqla;
SELECT * FROM liquidity_dev.gold.fact_lcr;
```

Compare `TotalHQLAAfterHaircut` and `TotalNetCashOutflows` manually.

### How to reduce costs

- Stop SQL Warehouse when not using dashboard.
- Use job clusters (auto-terminate) not all-purpose clusters 24/7.
- Delete Dev resources when not learning for extended periods.

### Where to learn more

- [Databricks Academy (free)](https://www.databricks.com/learn/training/home)
- [Delta Lake docs](https://docs.delta.io/)
- [Unity Catalog docs](https://docs.databricks.com/en/data-governance/unity-catalog/index.html)

---

## Quick Reference — vs azure.md

| Capability | azure.md | databricks.md |
|------------|----------|---------------|
| File landing | ADLS | ADLS |
| Data mart | Azure SQL | Delta + Unity Catalog |
| Transform | SQL stored procedures | PySpark notebooks |
| Orchestration | ADF | Workflows |
| Alerts | Logic Apps | SQL Alerts + webhook |
| Dashboard | App Service web app | Lakeview |
| CI/CD | Azure DevOps | Asset Bundles |

Both teach the same data engineering lifecycle — **ingest → transform → metric → alert → visualize → automate**.
