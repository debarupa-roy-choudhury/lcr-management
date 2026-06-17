# Azure Portal Step-by-Step Guide — Treasury Liquidity Risk Platform

> **Who this guide is for:** Complete beginners to data engineering who want to learn by building a real bank-style liquidity risk platform on Microsoft Azure. No prior Azure or SQL experience is assumed — every concept is explained as we go.

This guide walks you through implementing the **Treasury Liquidity Risk Platform** exactly as defined in `instruction.md`, using the **Azure Portal** (the web UI at [portal.azure.com](https://portal.azure.com)).

**Default region (per spec):** `West Europe` (pick one region and stay consistent).

**Environments:** Dev, Test, Prod — you will start with **Dev** only. Repeat the same steps later for Test and Prod when you are comfortable.

**Estimated time:** 2–4 days for a first-time learner (spread over several sessions).

---

## Table of Contents

0. [Beginner's Introduction — Read This First](#0-beginners-introduction--read-this-first)
1. [Prerequisites](#1-prerequisites)
2. [Create Resource Group](#2-create-resource-group)
3. [Create ADLS Gen2 Storage Account](#3-create-adls-gen2-storage-account)
4. [Create Azure SQL Database (Liquidity Risk Mart)](#4-create-azure-sql-database-liquidity-risk-mart)
5. [Create Database Schema and Stored Procedures](#5-create-database-schema-and-stored-procedures)
6. [Create Azure Data Factory](#6-create-azure-data-factory)
7. [Configure ADF Linked Services](#7-configure-adf-linked-services)
8. [Configure ADF Datasets](#8-configure-adf-datasets)
9. [Create ADF Pipelines](#9-create-adf-pipelines)
10. [Create ADF Schedule Trigger](#10-create-adf-schedule-trigger)
11. [Create Azure Logic App (Alerts)](#11-create-azure-logic-app-alerts)
12. [Create App Service (Dashboard)](#12-create-app-service-dashboard)
13. [Create Log Analytics Workspace](#13-create-log-analytics-workspace)
14. [Configure Diagnostic Settings](#14-configure-diagnostic-settings)
15. [Upload Sample Feed Files to ADLS](#15-upload-sample-feed-files-to-adls)
16. [Test the End-to-End Pipeline](#16-test-the-end-to-end-pipeline)
17. [Azure DevOps Setup](#17-azure-devops-setup)
18. [ADF Git Integration and CI/CD](#18-adf-git-integration-and-cicd)
19. [App Service CI/CD](#19-app-service-cicd)
20. [Optional: Infrastructure as Code](#20-optional-infrastructure-as-code)
21. [Acceptance Criteria Checklist](#21-acceptance-criteria-checklist)
22. [Glossary](#22-glossary)
23. [Troubleshooting FAQ](#23-troubleshooting-faq)

---

## 0. Beginner's Introduction — Read This First

### What is data engineering?

**Data engineering** is the work of moving, cleaning, storing, and preparing data so that analysts, dashboards, and regulators can trust it. Think of it like plumbing for data:

- **Sources** (upstream bank systems) produce files every day.
- **Pipes** (pipelines) move those files into a warehouse.
- **Filters and transforms** turn raw numbers into meaningful metrics (like LCR).
- **Taps** (dashboards) let people see the results.
- **Alarms** (alerts) notify the team when something breaks or a limit is breached.

You are not building a mobile app or a trading system here — you are building the **infrastructure that delivers reliable liquidity numbers every morning**.

### What you will build (in plain English)

Every business day, three CSV files arrive from other bank systems:

1. **Cash balances** — how much money is in each account.
2. **HQLA holdings** — high-quality liquid assets (government bonds, etc.) the bank can sell quickly in a crisis.
3. **Collateral** — assets pledged or encumbered (locked up as security).

Your platform will:

1. **Store** those files in a data lake (ADLS).
2. **Load** them into a SQL database.
3. **Calculate** the **Liquidity Coverage Ratio (LCR)** — a regulatory metric that answers: *"If we had a sudden run on deposits, could we survive for 30 days?"*
4. **Alert** treasury staff if data is missing or LCR falls below limits.
5. **Show** results on a web dashboard.
6. **Log** everything for audit and troubleshooting.

### The end-to-end flow (story of one business day)

```
 6:00 AM  Upstream systems drop 3 CSV files into ADLS
    │
 7:00 AM  Azure Data Factory trigger fires automatically
    │
    ├─► Check: did all 3 files arrive?
    ├─► Copy CSV → SQL staging tables
    ├─► Run SQL transforms + LCR calculation
    ├─► Write run summary (success/failure)
    └─► Call Logic App → send email/Teams alert
    │
 7:15 AM  Treasury opens dashboard → sees LCR by entity/currency
    │
 All day  Log Analytics collects logs from every component
```

### Azure services you will learn (and what each one does)

| Service | Think of it as… | Role in this project |
|---------|-----------------|----------------------|
| **Resource Group** | A folder that holds related Azure items | Organizes all Dev resources together |
| **ADLS Gen2** | A very large, cheap file cabinet in the cloud | Landing zone for daily CSV files |
| **Azure SQL Database** | A structured spreadsheet database | Stores tables, runs LCR calculations |
| **Azure Data Factory (ADF)** | A visual workflow scheduler / ETL tool | Orchestrates the daily pipeline |
| **Logic App** | An automated if-this-then-that for the cloud | Sends alerts when rules are violated |
| **App Service** | A host for a website | Shows the liquidity dashboard |
| **Log Analytics** | A central log search engine | Audit trail and monitoring |
| **Azure DevOps** | Git repos + automated deploy pipelines | CI/CD — deploy code without manual clicks |

### Key business terms (don't skip these)

| Term | Meaning |
|------|---------|
| **LCR (Liquidity Coverage Ratio)** | Ratio of high-quality liquid assets to net cash outflows over 30 days. Regulatory minimum is typically **100%** (1.0). |
| **HQLA** | High-Quality Liquid Assets — cash and securities that regulators accept as " truly liquid." |
| **Entity** | A legal banking unit (e.g. UK branch vs EU branch). |
| **BusinessDate** | The reporting date for the data (not necessarily "today"). |
| **Feed** | One incoming data file from an upstream system. |
| **Staging table** | Temporary "inbox" table where raw loaded data sits before transforms. |
| **Fact table** | Table of calculated metrics (e.g. daily LCR numbers). |
| **Dimension table** | Lookup/reference table (entities, currencies, time buckets). |
| **ETL** | Extract (read data) → Transform (clean/calculate) → Load (write results). |
| **Pipeline** | A sequence of automated steps that runs on a schedule. |

### How to use this guide

1. **Follow sections in order** — later steps depend on earlier ones.
2. **Keep a notebook** (paper or digital) with passwords, connection strings, and URLs.
3. **Don't rush** — if a step fails, use [Section 23: Troubleshooting](#23-troubleshooting-faq) before moving on.
4. **Checkpoint yourself** — after each major section, verify the "What success looks like" bullet.

### Azure Portal navigation tips

- The **search bar at the top** is your best friend — type "Storage accounts", "SQL", "Data factories", etc.
- **Resource groups** → click your group → see every resource you created in one place.
- Names in `monospace` (like `rg-liquidity-dev`) must be typed **exactly** unless the guide says to customize.
- After creating a resource, wait until status shows **Succeeded** before configuring it.

---

## 1. Prerequisites

### What you need before starting

| Requirement | Why you need it | How to get it |
|-------------|-----------------|---------------|
| **Azure subscription** | Azure charges for resources (Dev can cost ~$50–150/month depending on SKUs) | [Free trial](https://azure.microsoft.com/free/) or company subscription |
| **Contributor role** | Permission to create resources | Ask your Azure admin, or use your own subscription |
| **Azure DevOps account** | For Git repos and CI/CD (Sections 17–19) | [dev.azure.com](https://dev.azure.com) — free tier is fine |
| **Office 365 email** | Logic App email notifications | Your work or personal Outlook account |
| **Text editor** | Save connection strings and keys | Notepad, VS Code, or Notes app |

### Optional but helpful

- **Azure Storage Explorer** — easier file uploads to ADLS than the portal.
- **Azure Data Studio** or **SSMS** — alternative SQL client (Query Editor in portal is enough for this guide).

### Create a credentials document

Create a file called `liquidity-dev-secrets.txt` on your computer (**never commit this to Git**). Fill it in as you go:

```
Resource group:     rg-liquidity-dev
Storage account:    stliquiditydev001
Storage key:        (Section 3.3)
SQL Server:         sqlsvr-liquidity-dev.database.windows.net
SQL Database:       sqldb-liquidity-dev
SQL admin user:     
SQL admin password: 
Logic App URL:      (Section 11.2)
```

### Naming for Dev (from spec)

| Resource | Dev name (example) | Notes |
|----------|-------------------|-------|
| Resource group | `rg-liquidity-dev` | Logical container |
| Storage account | `stliquiditydev001` | Must be **globally unique** — add digits if taken |
| SQL Server | `sqlsvr-liquidity-dev` | Hosts the database |
| SQL Database | `sqldb-liquidity-dev` | The actual data mart |
| Data Factory | `adf-liquidity-dev` | Pipeline orchestrator |
| Logic App | `la-liquidity-notify-dev` | Alert workflow |
| App Service Plan | `asp-liquidity-dev` | Compute plan for web app |
| Web App | `app-liquidity-dashboard-dev` | Dashboard URL will be `https://app-liquidity-dashboard-dev.azurewebsites.net` |
| Log Analytics | `law-liquidity-dev` | Central logging |

**What success looks like:** You have an Azure subscription, a place to store secrets, and you understand the overall architecture from Section 0.

---

## 2. Create Resource Group

### What is a resource group?

A **resource group** is a logical container in Azure. All resources for the liquidity platform (storage, SQL, ADF, etc.) will live in one group so you can manage, monitor, and delete them together.

### Why start here?

Every Azure resource must belong to a resource group. Creating it first avoids confusion later.

### Step-by-step

1. Sign in to [Azure Portal](https://portal.azure.com).
2. In the top search bar, type **Resource groups** and press Enter.
3. Click **+ Create** (top left).
4. Fill in the **Basics** tab:
   - **Subscription:** select your subscription (only one if you have a free trial).
   - **Resource group:** type `rg-liquidity-dev` exactly.
   - **Region:** select **(Europe) West Europe**.
5. Click **Review + create** at the bottom.
6. On the review screen, click **Create**.
7. Wait ~10 seconds. Click **Go to resource group** when deployment completes.

### What you should see

- An empty resource group page with **Overview** showing zero resources (that is correct — you will add them next).
- Region: West Europe.

### Common mistakes

| Mistake | Fix |
|---------|-----|
| Wrong region | Delete the group and recreate in West Europe — mixing regions causes latency and billing complexity |
| Typo in name | Names are hard to rename — delete and recreate if needed |

**Checkpoint:** Can you see `rg-liquidity-dev` in the portal with zero resources?

Repeat later for `rg-liquidity-test` and `rg-liquidity-prod` when you expand to other environments.

---

## 3. Create ADLS Gen2 Storage Account

### What is ADLS?

**Azure Data Lake Storage Gen2 (ADLS Gen2)** is cloud storage optimized for analytics workloads. Upstream systems "drop" daily CSV files here — like a shared network drive, but in the cloud.

It is a **Storage Account** with **hierarchical namespace** enabled (folders, not just flat blobs).

### Why do we need it?

Banks rarely load files directly into a database. Files land in a **landing zone** (the data lake) first. This decouples upstream systems from downstream processing and gives you an audit copy of raw files.

### 3.1 Create the storage account

1. Portal search bar → type **Storage accounts** → Enter.
2. Click **+ Create**.
3. **Basics** tab:
   - **Resource group:** `rg-liquidity-dev`
   - **Storage account name:** `stliquiditydev001` (lowercase, no hyphens; if "name already taken", try `stliquiditydev002`)
   - **Region:** West Europe (must match resource group region)
   - **Performance:** Standard
   - **Redundancy:** Locally-redundant storage (LRS) — cheapest for learning
4. Click **Advanced** tab (or **Next** until you reach Advanced):
   - Find **Enable hierarchical namespace**
   - Set it to **checked / Enabled**
   - This is what makes it ADLS Gen2 — **do not skip this**
5. Click **Review + create** → **Create**.
6. Wait ~1 minute for deployment.

**What success looks like:** Storage account status = Succeeded. Hierarchical namespace = Enabled (verify under **Settings → Configuration**).

### 3.2 Create container and folder paths

A **container** is like a top-level drive. **Folders** (directories) organize files by feed and date.

1. Open your storage account (`stliquiditydev001`).
2. Left menu → **Storage browser** (or **Data storage → Containers**).
3. Click **+ Container**:
   - Name: `datalake`
   - Public access: leave as **Private**
   - Click **Create**
4. Click into the `datalake` container.
5. Create folders using **Add directory** — you must create each level one at a time:

**For balances (example date 2026-06-17):**

```
Click "Add directory" → type: raw          → OK
Open raw → Add directory → liquidity      → OK
Open liquidity → Add directory → balances → OK
Open balances → Add directory → 2026      → OK
Open 2026 → Add directory → 06            → OK
Open 06 → Add directory → 17              → OK
```

Repeat for `hqla` and `collateral` under `raw/liquidity/`.

**Full path pattern (for any date):**

```
raw/liquidity/balances/{yyyy}/{MM}/{dd}/
raw/liquidity/hqla/{yyyy}/{MM}/{dd}/
raw/liquidity/collateral/{yyyy}/{MM}/{dd}/
```

**Optional (for later):** `curated/liquidity/`

**Why date folders?** Partitioning by date makes it easy to find, reprocess, or archive one day's data without touching other days.

### 3.3 Note credentials for ADF

ADF needs permission to read/write this storage.

1. Storage account → left menu **Security + networking → Access keys**.
2. Click **Show** next to **key1**.
3. Copy and save in your secrets file:
   - **Storage account name:** `stliquiditydev001`
   - **key1** value (long string)

> **Production note:** `instruction.md` recommends **Managed Identity** instead of keys. Keys are fine for learning but should be rotated and replaced with Managed Identity in a real bank.

**Checkpoint:** Container `datalake` exists with folder paths for at least one date. You have the access key saved.

---

## 4. Create Azure SQL Database (Liquidity Risk Mart)

### What is the Liquidity Risk Mart?

A **data mart** is a focused database for one business area (here: liquidity risk). It holds staging tables (raw loads), dimension tables (lookups), fact tables (metrics like LCR), and control tables (run logs).

### Why Azure SQL?

Structured relational data with SQL is ideal for regulated metrics, joins, and stored procedures. ADF integrates natively with Azure SQL.

### 4.1 Create SQL Server

The **SQL Server** is the logical server (hostname). The **database** sits on it.

1. Portal search → **SQL servers** → **+ Create**.
2. Fill in:
   - **Resource group:** `rg-liquidity-dev`
   - **Server name:** `sqlsvr-liquidity-dev` (must be globally unique — add suffix if needed)
   - **Region:** West Europe
   - **Authentication method:** **Use SQL authentication**
   - **Server admin login:** e.g. `liquidityadmin` (no spaces)
   - **Password:** strong password (12+ chars, upper/lower/number/symbol) — **save it now**
3. **Review + create** → **Create** (~2 minutes).

### 4.2 Create SQL Database

1. Go to the SQL server resource (search `sqlsvr-liquidity-dev`).
2. Click **+ Create database** (overview page or left menu).
3. Fill in:
   - **Database name:** `sqldb-liquidity-dev`
   - **Want to use SQL elastic pool?** No
   - **Compute + storage:** click **Configure database**
     - For learning: **Basic** (~$5/month) or **General Purpose, Serverless, Gen5, 1 vCore** (can pause to save cost)
   - **Backup redundancy:** Local redundancy (Dev)
4. **Review + create** → **Create** (~2–5 minutes).

### 4.3 Configure firewall (critical for access)

By default, Azure SQL blocks all external connections. You must allow Azure services and your own IP.

1. SQL Server resource → **Security → Networking** (may be labeled "Firewalls and virtual networks").
2. Under **Firewall rules**:
   - Set **Allow Azure services and resources to access this server** → **Yes**
     - This lets ADF and App Service connect.
   - Click **+ Add your client IPv4 address** (button may say "Add current client IP address").
     - This lets **you** use Query Editor from your laptop.
3. Click **Save** at the top. Wait for "Successfully updated".

### 4.4 Note connection details

Save in your secrets file:

```
Server:   sqlsvr-liquidity-dev.database.windows.net
Database: sqldb-liquidity-dev
User:     liquidityadmin
Password: (your password)
```

**Full connection string format (you will use this later):**

```
Server=tcp:sqlsvr-liquidity-dev.database.windows.net,1433;Initial Catalog=sqldb-liquidity-dev;User ID=liquidityadmin;Password=YOUR_PASSWORD;Encrypt=True;TrustServerCertificate=False;
```

**Checkpoint:** Open SQL Server → Query editor → sign in → you can connect (even if no tables yet — connection success is enough for now).

---

## 5. Create Database Schema and Stored Procedures

### What are we doing here?

You are creating the **empty tables** (schema) that will hold liquidity data. Think of this as designing the columns in a spreadsheet before any data arrives.

**Table types in this project:**

| Type | Prefix / name | Purpose | Analogy |
|------|---------------|---------|---------|
| **Staging** | `stg_*` | Raw loaded data from CSV | Inbox — data just arrived |
| **Dimension** | `Dim_*` | Reference/lookup data | Dropdown lists (entities, currencies) |
| **Fact** | `Fact_*` | Calculated business metrics | Report numbers (LCR, positions) |
| **Control** | `LiquidityRunSummary` | Pipeline run audit log | Job diary — did today's run succeed? |

**Stored procedures** are saved SQL scripts (like macros) that ADF will call to transform data and calculate LCR.

### How to run SQL scripts

1. Portal → SQL Server `sqlsvr-liquidity-dev` → **Query editor** (left menu).
2. Sign in with SQL authentication (`liquidityadmin` + password).
3. At the top, select database **`sqldb-liquidity-dev`** from the dropdown.
4. Paste each script below into the editor.
5. Click **Run**. You should see "Query succeeded" for each block.

Run the following scripts **in order**.

### 5.1 Staging tables

These mirror the CSV columns from upstream feeds, plus a `LoadTimestamp` column (when the row was loaded).

```sql
CREATE TABLE stg_Balances (
    BusinessDate     date            NOT NULL,
    Entity           nvarchar(100)   NOT NULL,
    AccountId        nvarchar(100)   NOT NULL,
    Currency         nvarchar(3)     NOT NULL,
    Balance          decimal(18,2)   NOT NULL,
    IntradayTime     datetime        NULL,
    LoadTimestamp    datetime        NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE stg_HQLA (
    BusinessDate       date            NOT NULL,
    Entity             nvarchar(100)   NOT NULL,
    SecurityId         nvarchar(100)   NOT NULL,
    Currency           nvarchar(3)     NOT NULL,
    MarketValue        decimal(18,2)   NOT NULL,
    HQLALevel          nvarchar(10)    NOT NULL,
    HaircutPercentage  decimal(5,2)    NOT NULL,
    LoadTimestamp      datetime        NOT NULL DEFAULT GETUTCDATE()
);

CREATE TABLE stg_Collateral (
    BusinessDate       date            NOT NULL,
    Entity             nvarchar(100)   NOT NULL,
    AssetId            nvarchar(100)   NOT NULL,
    Currency           nvarchar(3)     NOT NULL,
    PledgedFlag        nvarchar(1)     NOT NULL,
    EncumberedAmount   decimal(18,2)   NOT NULL,
    LoadTimestamp      datetime        NOT NULL DEFAULT GETUTCDATE()
);
```

**Verify:** Left menu in Query editor → **Tables** → expand → you should see `stg_Balances`, `stg_HQLA`, `stg_Collateral`.

### 5.2 Dimension tables

```sql
CREATE TABLE Dim_Entity (
    EntityId     int IDENTITY(1,1) PRIMARY KEY,
    EntityCode   nvarchar(100) NOT NULL,
    EntityName   nvarchar(200) NOT NULL
);

CREATE TABLE Dim_Currency (
    CurrencyCode nvarchar(3) PRIMARY KEY,
    Description  nvarchar(200) NOT NULL
);

CREATE TABLE Dim_TimeBucket (
    BucketId        int IDENTITY(1,1) PRIMARY KEY,
    BucketName      nvarchar(100) NOT NULL,
    StartDayOffset  int NOT NULL,
    EndDayOffset    int NOT NULL
);
```

**What is a dimension?** Entities (BANK_UK), currencies (GBP), and time buckets (0–7 days) are attributes you join to facts for reporting.

### 5.3 Fact tables

```sql
CREATE TABLE Fact_LiquidityPositions (
    BusinessDate     date            NOT NULL,
    Entity           nvarchar(100)   NOT NULL,
    Currency         nvarchar(3)     NOT NULL,
    BucketId         int             NOT NULL,
    CashFlowAmount   decimal(18,2)   NOT NULL,
    IsInflow         bit             NOT NULL,
    IsOutflow        bit             NOT NULL
);

CREATE TABLE Fact_LCR (
    BusinessDate              date            NOT NULL,
    Entity                    nvarchar(100)   NOT NULL,
    Currency                  nvarchar(3)     NOT NULL,
    TotalHQLAAfterHaircut     decimal(18,2)   NOT NULL,
    TotalNetCashOutflows      decimal(18,2)   NOT NULL,
    LCR                       decimal(9,4)    NOT NULL,
    RegulatoryLimit           decimal(9,4)    NOT NULL,
    InternalLimit             decimal(9,4)    NOT NULL,
    IsBelowRegulatoryLCR      bit             NOT NULL,
    IsBelowInternalLCRLimit   bit             NOT NULL
);
```

**Fact_LCR** is the main output table — one row per BusinessDate + Entity + Currency with the calculated LCR and breach flags.

### 5.4 Run summary / control table

```sql
CREATE TABLE LiquidityRunSummary (
    RunId                     int IDENTITY(1,1) PRIMARY KEY,
    BusinessDate              date            NOT NULL,
    Entity                    nvarchar(100)   NOT NULL,
    Status                    nvarchar(20)    NOT NULL,
    AllFeedsReceived          bit             NOT NULL,
    LCR                       decimal(9,4)    NULL,
    IsBelowRegulatoryLCR      bit             NULL,
    IsBelowInternalLCRLimit   bit             NULL,
    ExecutionStartTime        datetime        NOT NULL,
    ExecutionEndTime          datetime        NOT NULL,
    ErrorMessage              nvarchar(max)   NULL
);
```

**Status values:** `Succeeded`, `Failed`, or `Partial` (some feeds missing but pipeline continued).

### 5.5 Stored procedure stubs

Per spec, create **stubs** now — empty shells that ADF can call. Domain experts add real LCR math later.

```sql
CREATE OR ALTER PROCEDURE sp_Liquidity_Load_Balances
AS
BEGIN
    -- Stub: merge/load from stg_Balances into intermediate or fact structure
    SET NOCOUNT ON;
END;
GO

CREATE OR ALTER PROCEDURE sp_Liquidity_Load_HQLA
AS
BEGIN
    SET NOCOUNT ON;
END;
GO

CREATE OR ALTER PROCEDURE sp_Liquidity_Load_Collateral
AS
BEGIN
    SET NOCOUNT ON;
END;
GO

CREATE OR ALTER PROCEDURE sp_Liquidity_Calculate_LCR
AS
BEGIN
    -- Stub: compute Fact_LCR from balances, HQLA, collateral, time buckets
    SET NOCOUNT ON;
END;
GO

CREATE OR ALTER PROCEDURE sp_Liquidity_Update_RunSummary
    @BusinessDate date,
    @Entity nvarchar(100),
    @Status nvarchar(20),
    @AllFeedsReceived bit,
    @LCR decimal(9,4) = NULL,
    @IsBelowRegulatoryLCR bit = NULL,
    @IsBelowInternalLCRLimit bit = NULL,
    @ExecutionStartTime datetime,
    @ExecutionEndTime datetime,
    @ErrorMessage nvarchar(max) = NULL
AS
BEGIN
    INSERT INTO LiquidityRunSummary (
        BusinessDate, Entity, Status, AllFeedsReceived,
        LCR, IsBelowRegulatoryLCR, IsBelowInternalLCRLimit,
        ExecutionStartTime, ExecutionEndTime, ErrorMessage
    )
    VALUES (
        @BusinessDate, @Entity, @Status, @AllFeedsReceived,
        @LCR, @IsBelowRegulatoryLCR, @IsBelowInternalLCRLimit,
        @ExecutionStartTime, @ExecutionEndTime, @ErrorMessage
    );
END;
GO

CREATE OR ALTER PROCEDURE sp_Liquidity_Check_MissingFeeds
    @BusinessDate date
AS
BEGIN
    -- Stub: assert each expected feed has records for @BusinessDate
    SET NOCOUNT ON;
END;
GO
```

**Note:** Each procedure block ends with `GO` which tells SQL Server to execute it as a separate batch. If Query Editor complains about `GO`, run each procedure one at a time.

**Checkpoint:** Run `SELECT name FROM sys.tables ORDER BY name;` — you should see all tables listed.

---

## 6. Create Azure Data Factory

### What is Azure Data Factory (ADF)?

**ADF** is Microsoft's cloud ETL and orchestration service. You design **pipelines** (workflows) visually or in JSON. ADF moves data between systems and runs activities on a schedule.

In this project, ADF is the **brain** of the daily job — it decides what runs, in what order, and what to do on failure.

### Step-by-step

1. Portal search → **Data factories** → **+ Create**.
2. Fill in:
   - **Resource group:** `rg-liquidity-dev`
   - **Name:** `adf-liquidity-dev` (globally unique — add suffix if needed)
   - **Region:** West Europe
   - **Version:** V2 (default — always use V2)
3. **Git configuration** tab: leave **Configure Git later** checked (Section 18 covers Git).
4. **Review + create** → **Create**.
5. When done, click **Go to resource**.
6. Click **Open Azure Data Factory Studio** (blue button) — opens a new tab at `adf.azure.com`.

### ADF Studio layout (get oriented)

| Area | Icon / location | What it is |
|------|-----------------|------------|
| **Author** | Pencil icon (left) | Design pipelines, datasets, data flows |
| **Monitor** | Eye icon | See pipeline run history, successes/failures |
| **Manage** | Toolbox icon | Linked services, triggers, Git settings |

**Checkpoint:** ADF Studio opens without error. You see an empty factory.

---

## 7. Configure ADF Linked Services

### What is a linked service?

A **linked service** is a **connection profile** — it stores how ADF connects to an external system (storage account, SQL database, etc.). You define it once and reuse it in many datasets and pipelines.

Think: saved Wi-Fi password for a device your pipelines use every day.

### Where to go

ADF Studio → **Manage** (toolbox) → **Linked services** → **+ New**

### 7.1 `ls_adls_liquidity` (connection to data lake)

1. In the search box, type **Azure Data Lake Storage Gen2** → select it → **Continue**.
2. Fill in:
   - **Name:** `ls_adls_liquidity`
   - **Connect via:** **Account key** (simplest for learning)
   - **Storage account name:** `stliquiditydev001`
   - **Storage account key:** paste key1 from Section 3.3
3. Click **Test connection** — must show green check / Succeeded.
4. Click **Create**.

**If test fails:** Double-check storage account name, key, and that hierarchical namespace is enabled.

### 7.2 `ls_sqldb_liquidity` (connection to SQL database)

1. **+ New** → search **Azure SQL Database** → **Continue**.
2. Fill in:
   - **Name:** `ls_sqldb_liquidity`
   - **Server name:** click dropdown → select `sqlsvr-liquidity-dev`
   - **Database name:** `sqldb-liquidity-dev`
   - **Authentication type:** SQL Authentication
   - **User name:** `liquidityadmin`
   - **Password:** your SQL password
3. **Test connection** → **Create**.

**If test fails:** Verify firewall allows Azure services (Section 4.3). Wait 2 minutes after saving firewall rules.

### 7.3 Optional linked services

- **Key Vault:** store secrets securely (recommended for production).
- **HTTP/Logic App:** usually not needed — Web activity uses URL directly.

**Checkpoint:** Two linked services visible under Manage → Linked services.

---

## 8. Configure ADF Datasets

### What is a dataset?

A **dataset** describes the **shape and location** of data — e.g. "a CSV file at this path" or "this SQL table". Pipelines reference datasets; datasets reference linked services.

Analogy: a dataset is an address label; a linked service is the courier company.

### Where to go

ADF Studio → **Author** (pencil) → **+** (plus icon) → **Dataset**

### 8.1 ADLS CSV datasets

You need three datasets — one per feed. Below is detailed steps for **balances**; repeat for **hqla** and **collateral** with path/name changes.

**`ds_adls_liq_balances`**

1. **New dataset** → search **DelimitedText** (CSV) → **Continue**.
2. **Linked service:** select `ls_adls_liquidity` → **Continue**.
3. **File path:**
   - Check **Enter manually** or browse to set base path.
   - Container/file system: `datalake`
   - For a static test path: `raw/liquidity/balances/2026/06/17/balances_2026-06-17.csv`
4. **Column delimiter:** Comma
5. **First row as header:** checked
6. Click **OK** → name the dataset: `ds_adls_liq_balances`

**Add parameter for dynamic dates:**

1. Open the dataset → **Parameters** tab → **+ New**.
2. Name: `BusinessDate`, Type: String, Default: `2026-06-17`
3. Go to **Connection** tab → check **Dynamic file path** (or edit JSON).
4. Set file path expression:

```
@concat('raw/liquidity/balances/', substring(dataset().BusinessDate, 1, 4), '/', substring(dataset().BusinessDate, 6, 2), '/', substring(dataset().BusinessDate, 9, 2), '/balances_', dataset().BusinessDate, '.csv')
```

**What this expression does (for beginners):**

- `dataset().BusinessDate` reads the parameter (e.g. `2026-06-17`).
- `substring(..., 1, 4)` extracts `2026` (year).
- `concat(...)` builds the full path: `raw/liquidity/balances/2026/06/17/balances_2026-06-17.csv`.

**Repeat for:**

| Dataset | File name pattern |
|---------|-------------------|
| `ds_adls_liq_hqla` | `hqla_{BusinessDate}.csv` under `raw/liquidity/hqla/...` |
| `ds_adls_liq_collateral` | `collateral_{BusinessDate}.csv` under `raw/liquidity/collateral/...` |

### 8.2 SQL staging datasets

For each staging table, create an dataset pointing to SQL:

1. **+ Dataset** → **Azure SQL Database** → Continue.
2. **Linked service:** `ls_sqldb_liquidity`
3. **Table name:** select from dropdown (e.g. `stg_Balances`)
4. Name the dataset to match:

| Dataset name | Table |
|--------------|-------|
| `ds_sql_stg_Balances` | `stg_Balances` |
| `ds_sql_stg_HQLA` | `stg_HQLA` |
| `ds_sql_stg_Collateral` | `stg_Collateral` |

**Checkpoint:** Six datasets created (3 ADLS + 3 SQL). Click each and verify connection preview works where available.

---

## 9. Create ADF Pipelines

### What is a pipeline?

A **pipeline** is a workflow — a sequence of **activities** (copy data, run SQL, call webhook). Pipelines can call other pipelines (child pipelines) and accept **parameters** (like `BusinessDate`).

### Pipeline parameters (used by all load pipelines)

When you create each pipeline, go to **Parameters** tab (empty canvas top) → **+ New**:

- **Name:** `BusinessDate`
- **Type:** String
- **Default:** `2026-06-17`

---

### 9.2 `pl_liq_load_balances` (copy one CSV into SQL)

**Purpose:** Move balances CSV from ADLS → `stg_Balances` table.

1. **Author** → **+** → **Pipeline** → name: `pl_liq_load_balances`
2. Add parameter `BusinessDate` (above).
3. From **Activities** pane, drag **Copy data** onto canvas.
4. Click the Copy activity → **Source** tab:
   - **Source dataset:** `ds_adls_liq_balances`
   - Click **Dataset properties** → pass parameter `BusinessDate` = `@pipeline().parameters.BusinessDate`
5. **Sink** tab:
   - **Sink dataset:** `ds_sql_stg_Balances`
6. **Mapping** tab → **Import schemas** → map columns:
   - CSV columns → SQL columns (names should match: BusinessDate, Entity, AccountId, Currency, Balance, IntradayTime)
7. **Settings** tab (optional):
   - Pre-copy script: `TRUNCATE TABLE stg_Balances;` (only if you want full replace each run — discuss with team in production)
8. Click **Debug** (top toolbar) to test with `BusinessDate = 2026-06-17` after uploading sample file (Section 15).

**Repeat** for `pl_liq_load_hqla` and `pl_liq_load_collateral` with matching source/sink datasets.

---

### 9.3 `pl_liq_master_daily_liquidity` (the main daily orchestrator)

This is the **master pipeline** — the full daily job. Create pipeline named **`pl_liq_master_daily_liquidity`** with parameter `BusinessDate`.

Add activities and connect with green arrows (dependencies flow left-to-right or top-to-bottom):

```
[Check Feeds] → [Load Balances] ─┐
              → [Load HQLA]     ─┼→ [Transform SPs] → [Calculate LCR] → [Run Summary] → [Notify Logic App]
              → [Load Collateral]┘
```

#### Step 1 — Check feeds / pre-validation

**Option A (from spec):** Drag **Stored Procedure** activity.

- **Linked service:** `ls_sqldb_liquidity`
- **Stored procedure name:** `sp_Liquidity_Check_MissingFeeds`
- **Parameter:** `@BusinessDate` = `@pipeline().parameters.BusinessDate`

**Option B (beginner-friendly alternative):** Use **Get Metadata** activity on ADLS to check file exists, then **If Condition**. Start with Option A for spec compliance.

#### Step 2 — Execute child pipelines

Drag three **Execute Pipeline** activities:

| Activity name | Pipeline | Parameter |
|---------------|----------|-----------|
| Execute Load Balances | `pl_liq_load_balances` | BusinessDate = `@pipeline().parameters.BusinessDate` |
| Execute Load HQLA | `pl_liq_load_hqla` | same |
| Execute Load Collateral | `pl_liq_load_collateral` | same |

Connect green arrow from Check Feeds → each Execute Pipeline (loads can run **in parallel** after check passes).

#### Step 3 — Transform and calculate (Stored Procedure activities)

Add four **Stored Procedure** activities **in sequence** (each depends on previous):

1. `sp_Liquidity_Load_Balances`
2. `sp_Liquidity_Load_HQLA`
3. `sp_Liquidity_Load_Collateral`
4. `sp_Liquidity_Calculate_LCR`

Each depends on all three load pipelines completing.

#### Step 4 — Update run summary

**Stored Procedure:** `sp_Liquidity_Update_RunSummary`

Map parameters (use pipeline variables or static values for learning):

| Parameter | Example value |
|-----------|---------------|
| `@BusinessDate` | `@pipeline().parameters.BusinessDate` |
| `@Entity` | `'ALL'` or specific entity |
| `@Status` | `'Succeeded'` |
| `@AllFeedsReceived` | `1` (true) |
| `@ExecutionStartTime` | `@utcnow()` |
| `@ExecutionEndTime` | `@utcnow()` |

#### Step 5 — Notify Logic App

Drag **Web** activity (depends on Run Summary):

- **Method:** POST
- **URL:** Logic App HTTP trigger URL (from Section 11 — create Logic App first, or add URL later)
- **Body:**

```json
{
  "BusinessDate": "@{pipeline().parameters.BusinessDate}",
  "Entity": "ALL",
  "Status": "Succeeded",
  "LCR": 1.25,
  "IsBelowRegulatoryLCR": false,
  "IsBelowInternalLCRLimit": false,
  "AllFeedsReceived": true,
  "RunId": 1
}
```

Replace static values with dynamic expressions as you mature the pipeline.

#### Publish

Click **Publish all** (top bar). Unpublished changes do not run in production triggers.

**Checkpoint:** Master pipeline canvas shows all activities connected. Publish succeeds.

---

## 10. Create ADF Schedule Trigger

### What is a trigger?

A **trigger** starts a pipeline automatically on a schedule (like a cron job or Windows Task Scheduler).

### Step-by-step

1. ADF Studio → **Manage** → **Triggers** → **+ New trigger** → **New/Edit**.
2. Fill in:
   - **Name:** `tr_liq_daily_run`
   - **Type:** Schedule
   - **Start date:** today
   - **Time zone:** e.g. GMT Standard Time / your local zone
   - **Recurrence:** Every 1 day
   - **At these times:** 7:00 AM (Treasury often wants numbers before markets open)
3. **Associate pipeline:**
   - Pipeline: `pl_liq_master_daily_liquidity`
   - Parameters: `BusinessDate` = `@formatDateTime(adddays(pipeline().TriggerTime, -1), 'yyyy-MM-dd')`
     - This example uses **yesterday** as BusinessDate (common bank cut-off). Adjust per your bank's rules.
4. Click **OK** → **Publish all**.
5. Back in Triggers list, toggle trigger to **Started** (triggers are created **Stopped** by default).

**Important:** A stopped trigger will never fire. Always verify status = Started after publishing.

---

## 11. Create Azure Logic App (Alerts)

### What is a Logic App?

A **Logic App** runs a visual workflow when something happens — here, when ADF sends an HTTP POST with run results. It can send emails, Teams messages, etc.

This replaces a human checking the pipeline every morning.

### 11.1 Create Logic App resource

1. Portal → search **Logic apps** → **+ Create**.
2. Fill in:
   - **Resource group:** `rg-liquidity-dev`
   - **Name:** `la-liquidity-notify-dev`
   - **Region:** West Europe
   - **Plan type:** Consumption (pay per execution — fine for learning)
3. **Review + create** → **Create**.

### 11.2 Design workflow

1. Open Logic App → **Logic app designer** (opens automatically for new app).
2. Choose trigger: search **When a HTTP request is received** → select it.
3. Click **Use sample payload to generate schema** and paste:

```json
{
  "BusinessDate": "2026-06-17",
  "Entity": "ALL",
  "Status": "Succeeded",
  "LCR": 1.25,
  "IsBelowRegulatoryLCR": false,
  "IsBelowInternalLCRLimit": false,
  "AllFeedsReceived": true,
  "RunId": 1
}
```

4. Click **Save** at the top (required before URL appears).
5. Click the HTTP trigger box again → **copy the HTTP POST URL** → save in secrets file.

**This URL is secret** — anyone with it can trigger your Logic App. Do not commit to Git.

### 11.3 Add actions (alert logic)

After the trigger, add steps:

**Step A — Parse JSON**

- Action: **Parse JSON**
- Content: `@triggerBody()`
- Schema: auto-generated from sample above

**Step B — Condition (branching)**

- Action: **Condition**
- Logic (from spec):

```
IF Status = 'Failed' OR AllFeedsReceived = false
  → Send HIGH priority email/Teams

ELSE IF IsBelowRegulatoryLCR = true OR IsBelowInternalLCRLimit = true
  → Send RISK alert email

ELSE
  → Send optional INFO email (pipeline succeeded, all good)
```

**Step C — Send email (inside each branch)**

- Action: **Office 365 Outlook → Send an email (V2)**
- Sign in with your Microsoft account when prompted.
- **To:** your email (for testing)
- **Subject:** `Liquidity Run @{body('Parse_JSON')?['BusinessDate']} - Status: @{body('Parse_JSON')?['Status']}`
- **Body:** include LCR, entity, link to ADF Monitor and dashboard URL.

**Save** the Logic App.

**Test manually:** Use Postman or curl to POST sample JSON to the HTTP URL. Check your email arrives.

---

## 12. Create App Service (Dashboard)

### What is App Service?

**Azure App Service** hosts web applications. Here it will serve a **dashboard** that reads LCR numbers from SQL and displays them to treasury users.

The spec allows any language (.NET, Python, Node.js). You will deploy application code via DevOps (Section 19).

### 12.1 App Service Plan (the server)

1. Portal → **App Service plans** → **+ Create**.
2. Fill in:
   - **Resource group:** `rg-liquidity-dev`
   - **Name:** `asp-liquidity-dev`
   - **Operating System:** Linux (good for Python/Node) or Windows (.NET)
   - **Region:** West Europe
   - **Pricing tier:** Dev/Test → **B1** (~$13/month)
3. **Create**.

### 12.2 Web App (the website)

1. Portal → **App Services** → **+ Create** → **Web App**.
2. Fill in:
   - **Resource group:** `rg-liquidity-dev`
   - **Name:** `app-liquidity-dashboard-dev` (this becomes your URL subdomain)
   - **Publish:** Code
   - **Runtime stack:** e.g. Python 3.11 or .NET 8 — match what you will code in
   - **App Service plan:** `asp-liquidity-dev`
3. **Create**.

Your dashboard URL will be: `https://app-liquidity-dashboard-dev.azurewebsites.net`

### 12.3 Connection string (how the app finds SQL)

1. Open Web App → **Settings → Configuration**.
2. **Connection strings** tab → **+ New connection string**:
   - **Name:** `LiquidityDb`
   - **Value:** full SQL connection string from Section 4.4
   - **Type:** SQLAzure
3. Click **Save** → **Continue** (app restarts).

### 12.4 Dashboard features (minimum per spec)

Your application code (built separately) must show:

1. **Daily LCR View** — table/chart: BusinessDate, Entity, Currency, LCR, limits; **red highlight** when below regulatory limit.
2. **Run Status View** — latest rows from `LiquidityRunSummary`.
3. **Feed Status Summary** — for latest BusinessDate, show if Balances, HQLA, Collateral feeds arrived.

**For learning:** Even a simple Python Flask app with three SQL queries satisfies the spec. Deploy via Section 19.

---

## 13. Create Log Analytics Workspace

### What is Log Analytics?

**Log Analytics** collects logs from all Azure resources in one searchable place. When a pipeline fails at 7 AM, you query logs here instead of checking each service individually.

### Step-by-step

1. Portal → **Log Analytics workspaces** → **+ Create**.
2. Fill in:
   - **Resource group:** `rg-liquidity-dev`
   - **Name:** `law-liquidity-dev`
   - **Region:** West Europe
3. **Review + create** → **Create**.

---

## 14. Configure Diagnostic Settings

### What are diagnostic settings?

Each Azure service generates logs internally. **Diagnostic settings** forward those logs to Log Analytics so you can search them.

### How to configure (repeat for each resource)

1. Open the resource (e.g. `adf-liquidity-dev`).
2. Left menu → **Monitoring → Diagnostic settings**.
3. Click **+ Add diagnostic setting**.
4. **Diagnostic setting name:** e.g. `send-to-law-liquidity-dev`
5. **Logs:** check the categories listed below for that resource type.
6. **Metrics:** optional but recommended.
7. **Destination details:** **Send to Log Analytics workspace** → select `law-liquidity-dev`.
8. **Save**.

| Resource | Where to find it | Log categories to enable |
|----------|------------------|--------------------------|
| Storage account | `stliquiditydev001` | StorageRead, StorageWrite, StorageDelete |
| Data Factory | `adf-liquidity-dev` | ActivityRuns, PipelineRuns, TriggerRuns |
| Logic App | `la-liquidity-notify-dev` | WorkflowRuntime |
| App Service | `app-liquidity-dashboard-dev` | AppServiceHTTPLogs, AppServiceConsoleLogs |
| SQL Database | `sqldb-liquidity-dev` | Errors, QueryStoreRuntimeStatistics (if available) |

### 14.1 Optional saved KQL queries

In Log Analytics workspace → **Logs** → run and save:

**Failed ADF pipelines:**

```kusto
ADFPipelineRun
| where Status == "Failed"
| where TimeGenerated > ago(7d)
| project TimeGenerated, PipelineName, FailureType, ErrorMessage
| order by TimeGenerated desc
```

**Checkpoint:** After running a test pipeline, you can find `PipelineRuns` logs in Log Analytics within ~5–15 minutes.

---

## 15. Upload Sample Feed Files to ADLS

You cannot test the pipeline without data. Create CSV files on your computer and upload them.

### How to create CSV files

Use Excel, Google Sheets, or a text editor. **First row must be column headers.** Save as CSV (UTF-8).

### 15.1 Cash Balances Feed

**File name:** `balances_2026-06-17.csv`  
**Upload path:** `datalake` → `raw/liquidity/balances/2026/06/17/`

**Columns:** `BusinessDate`, `Entity`, `AccountId`, `Currency`, `Balance`, `IntradayTime`

**Sample content:**

```csv
BusinessDate,Entity,AccountId,Currency,Balance,IntradayTime
2026-06-17,BANK_UK,ACC001,GBP,50000000.00,2026-06-17T09:00:00
2026-06-17,BANK_UK,ACC002,GBP,-12000000.00,2026-06-17T09:00:00
2026-06-17,BANK_EU,ACC101,EUR,35000000.00,2026-06-17T09:00:00
```

### 15.2 HQLA Feed

**File:** `hqla_2026-06-17.csv`  
**Path:** `datalake/raw/liquidity/hqla/2026/06/17/`

```csv
BusinessDate,Entity,SecurityId,Currency,MarketValue,HQLALevel,HaircutPercentage
2026-06-17,BANK_UK,GBR_GOV_001,GBP,30000000.00,HQLA1,0.00
2026-06-17,BANK_EU,DEU_GOV_001,EUR,25000000.00,HQLA1,0.00
```

### 15.3 Collateral Feed

**File:** `collateral_2026-06-17.csv`  
**Path:** `datalake/raw/liquidity/collateral/2026/06/17/`

```csv
BusinessDate,Entity,AssetId,Currency,PledgedFlag,EncumberedAmount
2026-06-17,BANK_UK,ASSET001,GBP,Y,5000000.00
2026-06-17,BANK_EU,ASSET101,EUR,Y,3000000.00
```

### Upload steps (Portal)

1. Storage account → **Storage browser** → container `datalake`.
2. Navigate to the dated folder (create folders if missing).
3. Click **Upload** → select your CSV file → **Upload**.

**Verify:** Click the file → **Preview** — headers and rows look correct.

---

## 16. Test the End-to-End Pipeline

This is the most important learning moment — you prove the whole system works together.

### 16.1 Pre-flight checklist

- [ ] Sample CSV files uploaded for `2026-06-17`
- [ ] ADF linked services test OK
- [ ] Logic App HTTP URL saved in ADF Web activity
- [ ] All pipelines published

### 16.2 Run the master pipeline manually

1. ADF Studio → **Author** → open `pl_liq_master_daily_liquidity`.
2. Click **Add trigger** → **Trigger now**.
3. Enter `BusinessDate`: `2026-06-17` → **OK**.
4. Go to **Monitor** → **Pipeline runs** → watch your run.

**What to watch:**

| Step | Success signal |
|------|----------------|
| Load pipelines | Green check; rows in staging tables |
| Stored procedures | Green check (stubs run without error) |
| Run summary | Green check; row in `LiquidityRunSummary` |
| Web activity | Green check; Logic App run history shows execution |

### 16.3 Verify in SQL

Query editor:

```sql
SELECT TOP 10 * FROM stg_Balances;
SELECT TOP 10 * FROM stg_HQLA;
SELECT TOP 10 * FROM stg_Collateral;
SELECT TOP 10 * FROM LiquidityRunSummary ORDER BY RunId DESC;
SELECT TOP 10 * FROM Fact_LCR;
```

**Expected for sample data:** Staging tables have rows. Run summary has at least one row. Fact_LCR may be empty until stored procedures contain real logic (stubs don't insert yet — that is OK for infrastructure testing).

### 16.4 Verify alerts and dashboard

- Logic App → **Run history** → latest run succeeded.
- Check email inbox for notification.
- Open dashboard URL (after deploying app code).

**If something fails:** Go to Monitor → click failed activity → read **Error** tab. See [Section 23](#23-troubleshooting-faq).

---

## 17. Azure DevOps Setup

### What is Azure DevOps?

**Azure DevOps** provides Git repositories and **pipelines** that automatically build and deploy code when you push changes — **CI/CD** (Continuous Integration / Continuous Deployment).

Instead of manually clicking "deploy" in the portal, you push code to Git and the pipeline deploys it.

### 17.1 Create project

1. Go to [dev.azure.com](https://dev.azure.com).
2. **New project** → Name: **`treasury-liquidity-risk`** → **Create**.

### 17.2 Create repositories

**Repos** → **New repository** — create:

| Repo | Contents |
|------|----------|
| `liquidity-app` | Web dashboard code + `azure-pipelines.yml` |
| `liquidity-adf` | ADF JSON exports + ADF CI/CD YAML |
| `liquidity-infra` (optional) | Bicep/ARM infrastructure templates |

### 17.3 Service connection (links DevOps to Azure)

1. **Project settings** (bottom left) → **Service connections** → **New service connection**.
2. Choose **Azure Resource Manager** → **Service principal (automatic)**.
3. **Scope level:** Subscription (or resource group for tighter security).
4. **Name:** `sc-azure-liquidity`
5. **Grant access to all pipelines:** checked → **Save**.

---

## 18. ADF Git Integration and CI/CD

### Why Git for ADF?

Without Git, pipeline changes live only in the portal. With Git integration, every change is version-controlled and deployable to Test/Prod automatically.

### 18.1 Enable Git in Dev ADF

ADF Studio → **Manage** → **Git configuration** → **Setup**:

| Setting | Value |
|---------|-------|
| Repository type | Azure DevOps Git |
| Organization | your org |
| Project | `treasury-liquidity-risk` |
| Repository | `liquidity-adf` |
| Collaboration branch | `main` |
| Publish branch | `adf_publish` |
| Root folder | `/` |

Click **Save**. ADF now shows branch name in status bar.

**Workflow:**

1. Edit pipelines on `main` branch in ADF.
2. **Publish** → ADF pushes ARM templates to `adf_publish` branch.
3. CI pipeline validates and packages ARM artifact.

### 18.2 ADF CI pipeline

In `liquidity-adf` repo, create `.azure-pipelines/adf-ci.yml` — triggers on `adf_publish`, validates ARM, publishes artifact `adf_liquidity_arm`.

### 18.3 ADF CD pipeline

Deploy artifact to Test/Prod ADF instances with manual approval gates for Prod.

---

## 19. App Service CI/CD

In `liquidity-app` repo, create `azure-pipelines.yml`:

- **Trigger:** push to `main`
- **Build:** compile/test/package web app → artifact `drop`
- **Deploy_Dev:** deploy to `app-liquidity-dashboard-dev`
- **Deploy_Test / Deploy_Prod:** with approvals

Use `AzureWebApp@1` task with service connection `sc-azure-liquidity`.

---

## 20. Optional: Infrastructure as Code

**Infrastructure as Code (IaC)** means defining Azure resources in text files (Bicep/ARM) instead of clicking the portal. Enables repeatable Dev/Test/Prod environments.

See `liquidity-infra` repo and `infra-deploy.yml` pipeline in `instruction.md` Section 6.

---

## 21. Acceptance Criteria Checklist

From `instruction.md` Section 8:

- [ ] Daily trigger `tr_liq_daily_run` runs `pl_liq_master_daily_liquidity`
- [ ] All three feeds load into SQL staging
- [ ] Transform and LCR procedures run without error
- [ ] Record in `LiquidityRunSummary` with status and metrics
- [ ] Logic App sends notifications on violations
- [ ] Dashboard shows LCR, run status, feed status
- [ ] DevOps CI for `liquidity-app` publishes artifact
- [ ] DevOps CI for `liquidity-adf` publishes ARM artifact
- [ ] CD deploys to Test/Prod without manual portal changes
- [ ] Log Analytics contains ADF, Logic App, App Service, SQL logs

---

## Recommended Order of Creation

1. Infra: RG → Storage → SQL → ADF → Logic Apps → App Service → Log Analytics  
2. SQL schema (tables + procedures)  
3. ADF linked services, datasets, pipelines  
4. Logic App workflow  
5. Upload sample files → test pipeline  
6. App Service deployment  
7. DevOps pipelines  

---

## 22. Glossary

| Term | Definition |
|------|------------|
| **ADLS Gen2** | Azure Data Lake Storage — cloud file storage with folder hierarchy for big data |
| **ADF** | Azure Data Factory — cloud ETL and orchestration |
| **Activity** | Single step in an ADF pipeline (copy, stored proc, web call) |
| **App Service** | Azure web hosting platform |
| **BusinessDate** | Reporting date for liquidity data |
| **CI/CD** | Automated build, test, and deploy on code changes |
| **Copy activity** | ADF activity that moves data source → sink |
| **CSV** | Comma-separated values text file format |
| **Dataset** | ADF definition of data location and format |
| **Dimension table** | Reference/lookup table (entity, currency) |
| **ETL** | Extract, Transform, Load |
| **Fact table** | Table of measurable metrics (LCR values) |
| **Feed** | One incoming data file from an upstream system |
| **HQLA** | High-Quality Liquid Assets |
| **KQL** | Kusto Query Language — used in Log Analytics |
| **LCR** | Liquidity Coverage Ratio — HQLA divided by net cash outflows |
| **Linked service** | ADF connection credentials to external system |
| **Logic App** | Azure workflow automation (if-this-then-that) |
| **Pipeline** | Sequence of automated data engineering steps |
| **Resource group** | Azure container for related resources |
| **Staging table** | Temporary table for newly loaded raw data |
| **Stored procedure** | Saved SQL script callable by name |
| **Trigger** | Scheduler that starts ADF pipelines |
| **Webhook** | HTTP URL that receives POST requests to start a workflow |

---

## 23. Troubleshooting FAQ

### "Storage account name already taken"

Storage names are globally unique. Try `stliquiditydev002`, `stliquiditydevyourname`, etc.

### "Cannot connect to SQL" from ADF or Query Editor

1. Check firewall: **Allow Azure services** = Yes.
2. Add your client IP for Query Editor.
3. Wait 2–5 minutes after saving firewall rules.
4. Verify username/password — no typos.

### ADF Copy activity fails "File not found"

1. Confirm CSV exists at exact path (case-sensitive).
2. Confirm `BusinessDate` parameter matches folder date.
3. Browse storage in portal — path must be `raw/liquidity/balances/2026/06/17/balances_2026-06-17.csv` inside container `datalake` (not including `datalake` in ADF path if container is set separately).

### ADF linked service test fails for ADLS

1. Verify hierarchical namespace enabled.
2. Re-copy access key from portal.
3. Check storage account name has no typos.

### Logic App never sends email

1. Did you **Save** the Logic App after adding trigger? URL only appears after save.
2. Check **Run history** — is trigger firing?
3. Office 365 connector requires valid Microsoft account sign-in.
4. Check spam folder.

### Trigger does not fire at 7 AM

1. Trigger must be **Started** (not Stopped).
2. Changes must be **Published**.
3. Check time zone on trigger matches your expectation.

### Pipeline succeeds but staging tables empty

1. Open Copy activity output — check rows copied count.
2. Verify column mapping matches CSV headers exactly.
3. Check for pre-copy script truncating then failing silently.

### Where to get help

- ADF activity error message (Monitor → failed run → Error tab) — always read this first.
- [Microsoft Learn — Azure Data Factory](https://learn.microsoft.com/en-us/azure/data-factory/)
- [Microsoft Learn — Azure SQL](https://learn.microsoft.com/en-us/azure/azure-sql/)
