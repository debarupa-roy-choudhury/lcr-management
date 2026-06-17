# Learn Data Engineering & Data Warehousing from Zero

> **Guide name:** `de.md`  
> **Audience:** Complete beginners — no prior tech, SQL, or cloud background required.  
> **Running example:** The **Treasury Liquidity Risk** platform from `instruction.md` — a real bank use case.  
> **Primary technology lens:** **Databricks** on **Azure**, with concepts that apply anywhere.  
> **Companion guides:** After concepts click, build hands-on with [`databricks.md`](databricks.md) or [`azure.md`](azure.md).

---

## How to use this guide

| If you want to… | Read… |
|-----------------|-------|
| Understand *why* and *what* before *how* | This guide (`de.md`) — start to finish |
| Build the full pipeline on Databricks | [`databricks.md`](databricks.md) |
| Build the full pipeline on Azure Portal (ADF, SQL, etc.) | [`azure.md`](azure.md) |
| Technical specification for the project | [`instruction.md`](instruction.md) |

**Suggested pace:** One part per day (≈ 30–60 minutes reading + optional mini-exercise). Complete Parts 1–8 before touching cloud tools.

---

## Table of contents

**Part A — The world you're entering**

1. [The business story: why banks care about liquidity](#part-1-the-business-story-why-banks-care-about-liquidity)
2. [What problem are we actually solving?](#part-2-what-problem-are-we-actually-solving)

**Part B — Foundations**

3. [What is data, really?](#part-3-what-is-data-really)
4. [What is data engineering?](#part-4-what-is-data-engineering)
5. [What is data warehousing?](#part-5-what-is-data-warehousing)

**Part C — Architecture & modeling**

6. [How data flows: from source to dashboard](#part-6-how-data-flows-from-source-to-dashboard)
7. [Layers of a modern data platform (Medallion)](#part-7-layers-of-a-modern-data-platform-medallion)
8. [Designing tables: dimensions, facts, and the star schema](#part-8-designing-tables-dimensions-facts-and-the-star-schema)
9. [Our liquidity data model explained](#part-9-our-liquidity-data-model-explained)

**Part D — The daily pipeline**

10. [Ingestion: getting data into the platform](#part-10-ingestion-getting-data-into-the-platform)
11. [Transformation: turning raw rows into trusted metrics](#part-11-transformation-turning-raw-rows-into-trusted-metrics)
12. [Calculating LCR: business logic in plain English](#part-12-calculating-lcr-business-logic-in-plain-english)
13. [Serving data: dashboards, reports, and alerts](#part-13-serving-data-dashboards-reports-and-alerts)

**Part E — Professional practice**

14. [Data quality: trust is everything](#part-14-data-quality-trust-is-everything)
15. [Orchestration: running jobs on a schedule](#part-15-orchestration-running-jobs-on-a-schedule)
16. [Governance, security, and audit](#part-16-governance-security-and-audit)
17. [Monitoring and when things go wrong](#part-17-monitoring-and-when-things-go-wrong)

**Part F — Technology map**

18. [Databricks and Azure: who does what](#part-18-databricks-and-azure-who-does-what)
19. [ETL vs ELT — which approach and why](#part-19-etl-vs-elt-which-approach-and-why)

**Part G — Your learning path**

20. [Guidelines every data engineer should follow](#part-20-guidelines-every-data-engineer-should-follow)
21. [Hands-on learning path (Level 0 → Level 3)](#part-21-hands-on-learning-path-level-0--level-3)
22. [Practice exercises (no cloud required)](#part-22-practice-exercises-no-cloud-required)
23. [Glossary](#part-23-glossary)
24. [What to read and build next](#part-24-what-to-read-and-build-next)

---

# Part A — The world you're entering

---

## Part 1: The business story — why banks care about liquidity

### Imagine you run a bank

Every day, customers deposit money, withdraw cash, and take loans. The bank also holds investments (bonds, securities) and pledges some assets as collateral for borrowing.

**Liquidity** means: *Can the bank pay its bills tomorrow if many customers withdraw at once?*

The **2008 financial crisis** taught regulators that banks must prove they hold enough **liquid assets** (cash and safe securities) to survive a short stress period. Banks now report metrics daily. Getting those numbers wrong can mean:

- Regulatory fines
- Trading restrictions
- Loss of customer trust
- Management fired

### Enter Treasury

Inside a bank, the **Treasury** team manages cash and funding. A sub-team focuses on **Liquidity Risk** — measuring and limiting the risk of running out of cash.

They need answers every morning:

- *How much high-quality liquid assets do we have?*
- *How much might flow out in a stress scenario?*
- *Are we above the regulatory minimum (LCR)?*
- *Are we above our stricter internal limit?*

### Our project (`instruction.md`)

We build the **data platform** that feeds those answers — not the trading desk itself, but the **plumbing** that:

1. Collects numbers from other systems
2. Cleans and combines them
3. Calculates LCR
4. Shows results on a dashboard
5. Alerts people when something is wrong

**You are learning to build that plumbing.** That is data engineering.

---

## Part 2: What problem are we actually solving?

### Three daily data feeds

Other bank systems (not built by us) produce CSV files each business day:

| Feed | From | Contains |
|------|------|----------|
| **Cash Balances** | Core banking / ledger | Account balances by entity and currency |
| **HQLA Holdings** | Markets / risk system | Liquid securities and their market values |
| **Collateral** | Collateral system | Assets pledged or encumbered (locked up) |

**HQLA** = High-Quality Liquid Assets — the "good stuff" regulators count toward survival.

### What the business needs out

| Output | Meaning |
|--------|---------|
| **Daily LCR** | One ratio per entity + currency per day |
| **Intraday positions** | How liquidity changed hour-by-hour (when timestamps exist) |
| **Limit flags** | Red alerts: below regulatory or internal LCR |
| **Feed status** | Did all three files arrive on time? |
| **Run log** | Did today's calculation job succeed? |

### The data engineer's job in one sentence

> **Make sure the right numbers reach the right people at the right time — and prove it.**

That requires **data engineering** (moving and processing data) and **data warehousing** (organizing data for analysis).

---

# Part B — Foundations

---

## Part 3: What is data, really?

### Data is recorded facts

In our project, a **row** might be:

```
BusinessDate: 2026-06-17
Entity:       BANK_UK
AccountId:    ACC001
Currency:     GBP
Balance:      50,000,000.00
```

Each column is an **attribute**. Each row is one **record**.

### Structured vs unstructured

| Type | Example | Our project |
|------|---------|-------------|
| **Structured** | Rows and columns in CSV, SQL tables | ✅ All three feeds are CSV |
| **Semi-structured** | JSON logs, XML | Not used here |
| **Unstructured** | PDFs, emails, images | Not used here |

Most enterprise data engineering starts with **structured** data.

### Source systems vs analytics platform

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Core Banking    │     │ Markets System  │     │ Collateral Sys  │
│ (source)        │     │ (source)        │     │ (source)        │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │ CSV                   │ CSV                   │ CSV
         └───────────────────────┼───────────────────────┘
                                 ▼
                    ┌────────────────────────┐
                    │  OUR PLATFORM          │
                    │  (data engineering)    │
                    └────────────────────────┘
                                 │
                                 ▼
                         Dashboard & alerts
```

**Rule:** Source systems **operate** the bank. Our platform **reports** on them. We rarely change source systems; we read from them.

### Batch vs real-time

| Pattern | When | Our project |
|---------|------|-------------|
| **Batch** | Files arrive once per day; job runs at 7 AM | ✅ Primary pattern |
| **Real-time / streaming** | Events processed in milliseconds | Optional for intraday updates later |

Beginners should master **batch** first — it is simpler and covers most regulatory reporting.

---

## Part 4: What is data engineering?

### Definition (plain English)

**Data engineering** is designing and building **reliable pipelines** that move data from sources to destinations, with cleaning and rules applied along the way.

### What data engineers do (vs other roles)

| Role | Focus | Analogy |
|------|-------|---------|
| **Data engineer** | Pipelines, storage, reliability | Build highways and water pipes |
| **Data analyst** | Questions, SQL, charts | Drive on highways to visit clients |
| **Data scientist** | Models, predictions | Experiment in a lab |
| **Software engineer** | Applications users click | Build houses and shops |

You can become a data engineer without being a data scientist. Strong SQL, basic Python, and **systems thinking** matter more than machine learning at the start.

### Core responsibilities (mapped to our project)

| Responsibility | Liquidity example |
|----------------|-------------------|
| **Ingest** | Read CSV files from cloud storage |
| **Store** | Save in organized tables (Delta Lake) |
| **Transform** | Clean balances, apply haircuts on HQLA |
| **Aggregate** | Sum by entity and currency |
| **Calculate** | Compute LCR and breach flags |
| **Orchestrate** | Run steps in order every day at 7 AM |
| **Monitor** | Log success/failure; alert on missing feeds |
| **Document** | Table definitions, lineage, runbooks |

### The pipeline mindset

Think in **steps**, not one giant script:

```
Validate → Ingest → Clean → Calculate → Publish → Alert
```

If step 2 fails, step 5 should not silently run with bad data. **Fail fast** is a key principle.

---

## Part 5: What is data warehousing?

### Definition (plain English)

A **data warehouse** is a **central store of data optimized for reporting and analysis** — not for processing customer transactions.

| | Operational database (OLTP) | Data warehouse (OLAP) |
|--|----------------------------|------------------------|
| **Purpose** | Run the bank (payments, accounts) | Report on the bank |
| **Queries** | Small, fast, many users | Large scans, aggregations |
| **Updates** | Row-by-row, constant | Batch loads, daily |
| **History** | Often current state only | Keeps history for trends |
| **Our project** | Core banking (source) | **Liquidity Risk Mart** (destination) |

**OLTP** = Online Transaction Processing  
**OLAP** = Online Analytical Processing

### What is a "data mart"?

A **data mart** is a **small warehouse focused on one subject** — here, liquidity risk.

Full bank warehouse might hold credit risk, market risk, finance, HR. Our **`Liquidity Risk Mart`** holds only liquidity-related tables.

### Kimball vs Inmon (you'll hear these names)

Two famous approaches to warehousing:

| Approach | Idea | Beginner takeaway |
|----------|------|-----------------|
| **Kimball** | Build subject marts with **star schemas** (facts + dimensions) | ✅ Most common in modern analytics; we use this |
| **Inmon** | Build one huge normalized enterprise warehouse first, then marts | Less common for greenfield cloud projects |

You do not need to pick a camp on day one. Learn **star schema** — it covers 80% of what you'll see.

### Modern twist: Lakehouse

Traditional path:

```
Data Lake (cheap files)  +  Data Warehouse (SQL tables)  =  two systems
```

**Lakehouse** (Databricks' model):

```
Delta Lake on cloud storage  =  files that behave like warehouse tables
```

One platform for engineering **and** warehousing. Our Databricks guide uses this model.

---

# Part C — Architecture & modeling

---

## Part 6: How data flows — from source to dashboard

### The classic journey

```
 SOURCES          LANDING           WAREHOUSE           CONSUMPTION
 (other systems)  (raw files)       (clean tables)      (humans & apps)

 Core Banking ──►  ADLS raw folder ──► Silver/Gold ──────► Dashboard
 Markets      ──►  /balances/...  ──► tables     ──────► SQL alerts
 Collateral   ──►                  ──►            ──────► Regulatory report
```

### Key zones explained

| Zone | Nickname | What's stored | Who uses it |
|------|----------|---------------|-------------|
| **Landing / Raw** | "The inbox" | Exact copy of source files | Data engineers (debugging) |
| **Staging / Silver** | "The clean room" | Typed, validated rows | Transform jobs |
| **Mart / Gold** | "The showroom" | Metrics (LCR, flags) | Treasury, regulators, dashboards |
| **Control** | "The logbook" | Run status, feed arrival | Operations, audit |

### One business day — timeline

```
05:00  Upstream systems finish overnight batch
06:00  CSV files appear in cloud storage (landing zone)
07:00  Our scheduled pipeline starts
07:05  Feeds validated → loaded → transformed → LCR calculated
07:10  Run summary written; alerts sent if needed
07:15  Treasury opens dashboard — numbers are ready
```

If files are late, the pipeline should **fail loudly**, not show yesterday's data as today's.

---

## Part 7: Layers of a modern data platform (Medallion)

The **Medallion Architecture** is the standard pattern on Databricks. Three layers:

```
                    ┌─────────────┐
                    │    GOLD     │  ← Business metrics (LCR, limits)
                    │  "Trusted"  │
                    └──────▲──────┘
                           │
                    ┌──────┴──────┐
                    │   SILVER    │  ← Cleaned, typed, deduplicated
                    │  "Refined"  │
                    └──────▲──────┘
                           │
                    ┌──────┴──────┐
                    │   BRONZE    │  ← Raw copy of source files
                    │  "Raw"      │
                    └──────▲──────┘
                           │
                    ┌──────┴──────┐
                    │  CSV files  │  ← Landing zone (ADLS)
                    └─────────────┘
```

### Why three layers?

| Layer | Preserve | Avoid |
|-------|----------|-------|
| **Bronze** | Original data for audit | Using raw data in reports |
| **Silver** | Clean records for reuse | Mixing business rules here |
| **Gold** | Final metrics everyone agrees on | Re-cleaning from scratch every time |

**Analogy:** Bronze = photocopy of receipts. Silver = sorted expenses in a spreadsheet. Gold = monthly budget summary.

### Mapping to our feeds

| Feed | Bronze table | Silver table | Gold output |
|------|--------------|--------------|-------------|
| Balances | `bronze.balances` | `silver.balances` | `fact_liquidity_positions`, intraday |
| HQLA | `bronze.hqla` | `silver.hqla` | contributes to `fact_lcr` |
| Collateral | `bronze.collateral` | `silver.collateral` | contributes to `fact_lcr` |

---

## Part 8: Designing tables — dimensions, facts, and the star schema

### The star schema (Kimball's gift to beginners)

Imagine a **star**:

- Center = **FACT** table (numbers you measure)
- Points = **DIMENSION** tables (context you filter by)

```
                    dim_entity
                        │
                        │
         dim_currency ──┼── fact_lcr ──── dim_time (BusinessDate)
                        │
                        │
                  dim_time_bucket
```

### Facts vs dimensions

| | Fact | Dimension |
|--|------|-----------|
| **Contains** | Measurements (amounts, ratios) | Descriptions (names, categories) |
| **Example** | LCR = 1.25, Balance = 50M | Entity = BANK_UK, Currency = GBP |
| **Size** | Usually huge (many rows) | Usually small (lookup lists) |
| **Changes** | Every day new rows | Rarely changes |

### Our fact tables (from `instruction.md`)

| Table | Measures |
|-------|----------|
| `Fact_LCR` | LCR, HQLA after haircut, net outflows, limit flags |
| `Fact_LiquidityPositions` | Cash flow amounts by time bucket |
| Intraday fact | Balance at each timestamp |

### Our dimension tables

| Table | Describes |
|-------|-----------|
| `Dim_Entity` | Legal entities (BANK_UK, BANK_EU) |
| `Dim_Currency` | GBP, EUR, USD |
| `Dim_TimeBucket` | 0–7 days, 8–30 days, etc. |

### Staging tables — not part of the star

**Staging** (`stg_Balances`, etc.) is temporary holding before silver/gold. Analysts should **not** query staging for official reports.

### Grain (an advanced word you'll need)

**Grain** = what one row represents.

| Table | Grain |
|-------|-------|
| `stg_Balances` | One row per account per day (maybe per intraday time) |
| `Fact_LCR` | One row per **BusinessDate + Entity + Currency** |
| `LiquidityRunSummary` | One row per **run + entity** (control, not a star fact) |

Getting grain wrong is a common beginner mistake — always ask: *"What does one row mean?"*

---

## Part 9: Our liquidity data model explained

### Entity-relationship story (no jargon version)

**Balances feed** says: *"Account ACC001 at BANK_UK holds £50M on June 17."*

**HQLA feed** says: *"BANK_UK holds £30M of UK government bonds (HQLA1, 0% haircut)."*

**Collateral feed** says: *"BANK_UK pledged £5M of assets — that money isn't freely available."*

**Gold layer combines them:**

- Total liquid assets (HQLA after haircuts)
- Minus / compared to expected outflows (negative balances, encumbrance)
- = **LCR** and buffer

### Control tables (not business facts)

| Table | Purpose |
|-------|---------|
| `LiquidityRunSummary` / `liquidity_run_summary` | Did today's job succeed? What was the LCR? |
| `feed_status` | Did each CSV arrive? How many rows? |

These answer **"Can we trust today's numbers?"** before anyone trusts the LCR itself.

### Naming conventions (good habit)

| Pattern | Meaning | Example |
|---------|---------|---------|
| `stg_` or `bronze.` | Raw / staging | `stg_Balances` |
| `Dim_` or `reference.` | Dimension | `Dim_Entity` |
| `Fact_` or `gold.fact_` | Fact | `Fact_LCR` |
| `control.` | Operations | `feed_status` |

Consistent naming helps teams find tables years later.

---

# Part D — The daily pipeline

---

## Part 10: Ingestion — getting data into the platform

### What is ingestion?

**Ingestion** = copying data from outside into **your** platform for the first time.

In our case: **CSV file → bronze Delta table** (or ADLS → SQL staging in the Azure path).

### Ingestion patterns

| Pattern | Description | Our project |
|---------|-------------|-------------|
| **Push** | Source system uploads files to our folder | ✅ Upstream drops CSV in ADLS |
| **Pull** | Our pipeline fetches from source API/FTP | Alternative design |
| **Full load** | Replace entire table each run | Sometimes used in staging |
| **Incremental** | Only new/changed rows | Advanced; use later |

### File naming and folders

Organize by **date** so you never overwrite history by accident:

```
raw/liquidity/balances/2026/06/17/balances_2026-06-17.csv
```

**Partitioning** by `BusinessDate` in tables matches this — queries for one day touch only that day's data.

### Ingestion checklist (guidelines)

1. ✅ Verify file exists before processing
2. ✅ Record `LoadTimestamp` and `SourceFile` (lineage)
3. ✅ Keep bronze immutable in spirit — don't "fix" source data silently
4. ✅ Count rows and compare to expectations
5. ❌ Don't skip validation because "it's usually fine"

### Databricks ingestion (concept)

```python
# Conceptual — not a full tutorial
df = spark.read.csv("path/to/balances.csv")
df.write.saveAsTable("liquidity_dev.bronze.balances")
```

**Azure alternative:** ADF **Copy activity** from ADLS to SQL — see `azure.md`.

---

## Part 11: Transformation — turning raw rows into trusted metrics

### What is transformation?

**Transformation** applies **business rules** to raw data:

- Cast strings to numbers
- Remove duplicates
- Filter invalid HQLA levels
- Join balances with HQLA
- Aggregate to entity level

Transformations belong mainly in **Silver → Gold**, not in bronze.

### Common transformation types

| Type | Example in liquidity |
|------|---------------------|
| **Cleaning** | Uppercase `PledgedFlag` to Y/N |
| **Filtering** | Keep only HQLA1, HQLA2A, HQLA2B |
| **Joining** | Combine HQLA + outflows by Entity + Currency |
| **Aggregating** | SUM(MarketValue) per entity |
| **Deriving** | `HQLAAfterHaircut = MarketValue × (1 - Haircut%)` |
| **Flagging** | `IsBelowRegulatoryLCR = LCR < 1.0` |

### Idempotency (important word)

A job is **idempotent** if running it **twice for the same day** gives the **same result** — not double the numbers.

**How:** Use `overwrite` with `replaceWhere BusinessDate = '2026-06-17'` instead of blind append.

### Transformation guidelines

1. **One responsibility per layer** — silver cleans; gold calculates metrics
2. **Document formulas** — especially LCR; regulators will ask
3. **Version control** — notebooks in Git, not only in someone's laptop
4. **Test edge cases** — missing currency, zero outflows, empty file

---

## Part 12: Calculating LCR — business logic in plain English

### What is LCR?

**Liquidity Coverage Ratio (LCR)** asks:

> *Over the next 30 days of stress, do we have enough liquid assets to cover net cash outflows?*

Simplified learning formula:

```
LCR = Total HQLA (after haircuts) / Total Net Cash Outflows
```

| Component | From which feed | Plain meaning |
|-----------|-----------------|---------------|
| **HQLA after haircut** | HQLA | Liquid assets reduced by regulatory discount |
| **Net cash outflows** | Balances + Collateral | Money that could leave under stress |

**Haircut example:** A £10M corporate bond with 15% haircut counts as £8.5M HQLA.

**Regulatory minimum:** LCR ≥ **100%** (written as 1.0).

**Internal limit:** Bank may require 110% (1.1) for safety margin.

### Limit flags (outputs)

| Flag | Meaning |
|------|---------|
| `IsBelowRegulatoryLCR` | LCR < 100% — regulatory breach |
| `IsBelowInternalLCRLimit` | LCR < internal policy |
| `IsLiquidityBufferBelowLimit` | Absolute buffer too low |

### Intraday liquidity

When `IntradayTime` is present on balances, treasury tracks **how liquidity evolved during the day** — not just end-of-day snapshot.

Use **window functions** (running sum ordered by time) — taught in `databricks.md` notebook 3.

### Who owns the formula?

- **Data engineer:** builds pipeline that *executes* the calculation reliably
- **Treasury / quants:** *define* the regulatory formula
- **Compliance:** signs off

Never invent LCR math in production without business approval. Learning projects use simplified formulas.

---

## Part 13: Serving data — dashboards, reports, and alerts

### Consumption layer

After gold tables exist, **humans and systems consume** them:

| Consumer | Needs | Tool in our stack |
|----------|-------|-------------------|
| Treasury analyst | LCR by entity, trend | Lakeview Dashboard (Databricks) or Web App (Azure) |
| Operations | Did pipeline succeed? | Run summary table + job monitor |
| Risk manager | Breach notification | Email / Teams alert |
| Auditor | Proof feeds arrived | `feed_status`, logs, Delta history |

### Dashboard design principles

1. **One screen — three questions:** What is LCR? Did data arrive? Did the job succeed?
2. **Red highlighting** for breaches — don't make users hunt
3. **Show BusinessDate prominently** — avoid reporting stale data
4. **Link to evidence** — run ID, feed counts

### Alerts vs dashboards

| | Dashboard | Alert |
|--|-----------|-------|
| **User looks when** | They choose | System pushes when rule fires |
| **Example** | LCR table | Email: "LCR below 100% for BANK_UK" |

Alert when **action is required**. Too many alerts = people ignore them.

---

# Part E — Professional practice

---

## Part 14: Data quality — trust is everything

### Dimensions of data quality

| Dimension | Question | Liquidity example |
|-----------|----------|-------------------|
| **Completeness** | Is all expected data present? | All 3 feeds arrived? |
| **Timeliness** | Was it on time? | Files before 7 AM job? |
| **Accuracy** | Are values correct? | Balances match source system |
| **Consistency** | Do joins make sense? | Same entity codes everywhere |
| **Validity** | Allowed values only? | Currency = 3-letter ISO code |

### Quality techniques (beginner → intermediate)

| Technique | When | Example |
|-----------|------|---------|
| **Row counts** | Every run | Expect ~5 balance rows; flag if 0 |
| **Schema checks** | Ingestion | Required columns exist |
| **Null checks** | Silver | BusinessDate never null |
| **Referential checks** | Gold | Every Entity in fact exists in Dim_Entity |
| **Reconciliation** | Monthly | Sum of balances vs finance general ledger |

### Fail fast vs fail soft

| Strategy | Behavior | When |
|----------|----------|------|
| **Fail fast** | Stop pipeline; alert | Missing feed for regulatory report |
| **Fail soft** | Continue with partial; mark "Partial" | Non-critical optional feed |

For LCR, missing HQLA feed → **fail fast**.

---

## Part 15: Orchestration — running jobs on a schedule

### What is orchestration?

**Orchestration** = coordinating **multiple steps** in the right **order** at the right **time**, with **retries** and **dependencies**.

Our daily job:

```
1. Validate feeds
2. Ingest bronze      (only if 1 OK)
3. Transform silver   (only if 2 OK)
4. Calculate LCR      (only if 3 OK)
5. Write run summary  (only if 4 OK)
6. Send alerts        (always if reached)
```

### Orchestration tools

| Tool | Platform |
|------|----------|
| **Databricks Workflows** | Databricks jobs with task DAG |
| **Azure Data Factory** | Azure-native pipelines |
| **Apache Airflow** | Open-source (common elsewhere) |

Concepts are the same: **DAG** (Directed Acyclic Graph) = flowchart of tasks with no loops.

### Scheduling

**Cron** = timetable language. `0 0 7 * * ?` = 7:00 AM daily.

Pick schedule based on **when upstream data is ready**, not when you wake up.

### Parameters

Pass **`BusinessDate`** into every step — usually **prior business day** or **same day** depending on bank cut-off. Document the rule clearly.

---

## Part 16: Governance, security, and audit

### Why governance matters in banks

Regulators ask: *"Show us how you calculated LCR on March 15."* You need:

- Raw files (bronze)
- Transformation code (Git history)
- Output numbers (gold)
- Proof job ran (control tables + logs)

### Unity Catalog (Databricks)

**Unity Catalog** provides:

- **Catalog / schema / table** hierarchy
- **Permissions** (who can read/write)
- **Lineage** (where did this column come from)

Hierarchy:

```
liquidity_dev          ← catalog (project)
  ├── bronze           ← schema (layer)
  ├── silver
  ├── gold
  ├── reference
  └── control
```

### Security basics

| Principle | Practice |
|-----------|----------|
| **Least privilege** | Analysts read gold; only engineers write bronze |
| **No secrets in code** | Use secret scopes / Key Vault |
| **Encrypt data** | Azure encrypts storage and SQL by default |
| **Audit access** | Enable diagnostic logs |

Beginners: don't share storage keys in chat or Git.

---

## Part 17: Monitoring and when things go wrong

### What to monitor

| Signal | Tool |
|--------|------|
| Job succeeded/failed | Databricks Workflows run history |
| Row counts per feed | `feed_status` table |
| LCR breaches | SQL alerts / gold table flags |
| Infrastructure logs | Azure Log Analytics (Azure path) |
| Table changes over time | Delta `DESCRIBE HISTORY` |

### Common failures (and what they mean)

| Symptom | Likely cause | First action |
|---------|--------------|--------------|
| Job failed at validate | CSV missing or empty | Check ADLS folder for BusinessDate |
| Job failed at ingest | Permission or path typo | Verify external location / IAM |
| LCR looks wrong | Formula or join bug | Query silver tables manually |
| Dashboard empty | Wrong date or warehouse stopped | Run SQL in editor first |
| Duplicate rows | Append instead of idempotent overwrite | Fix write mode |

### Runbook mindset

A **runbook** is a short document: *"If X happens, do Y."* Example:

> **Missing balances file:** Check upstream SLA → contact core banking ops → re-run job after file lands → update run summary.

---

# Part F — Technology map

---

## Part 18: Databricks and Azure — who does what

You don't need every Azure service on day one. Here's a **learner's map**:

```
┌─────────────────────────────────────────────────────────────────┐
│                        AZURE CLOUD                               │
│  ┌──────────────┐    ┌─────────────────────────────────────┐   │
│  │  ADLS Gen2   │◄───│         DATABRICKS WORKSPACE         │   │
│  │  (files)     │    │  Notebooks, Jobs, SQL, Dashboards   │   │
│  └──────────────┘    │  Unity Catalog + Delta Lake           │   │
│                      └─────────────────────────────────────┘   │
│  Optional: Azure DevOps (Git), Key Vault (secrets), Monitor      │
└─────────────────────────────────────────────────────────────────┘
```

| Component | Role | Beginner priority |
|-----------|------|-------------------|
| **Azure subscription** | Billing and resource container | Required |
| **Resource group** | Organize resources | Required |
| **ADLS Gen2** | Store CSV landing files | Required |
| **Databricks workspace** | Run notebooks and jobs | Required |
| **Unity Catalog** | Govern tables | Required (Premium) |
| **Delta Lake** | Reliable table format | Built-in |
| **SQL Warehouse** | Dashboards and SQL | Required for Lakeview |
| **Azure DevOps** | Git + CI/CD | Learn after first pipeline works |
| **Azure Data Factory** | Alternative orchestrator | See `azure.md` — not needed for Databricks path |
| **Azure SQL Database** | Alternative warehouse | See `azure.md` — not needed for Databricks path |

### Two valid paths — same concepts

| Concept | Databricks path | Azure path (`azure.md`) |
|---------|-----------------|-------------------------|
| Storage | ADLS + Delta | ADLS + Azure SQL |
| Transform | PySpark notebooks | SQL stored procedures |
| Orchestrate | Workflows | Data Factory |
| Dashboard | Lakeview | App Service web app |
| Alerts | SQL Alerts + email | Logic Apps |

**Learn concepts once.** Tools are interchangeable with practice.

---

## Part 19: ETL vs ELT — which approach and why

### Definitions

| Term | Order | Meaning |
|------|-------|---------|
| **ETL** | Extract → Transform → Load | Transform *before* loading warehouse |
| **ELT** | Extract → Load → Transform | Load raw first, transform *inside* warehouse |

```
ETL:  Source ──► Transform engine ──► Warehouse

ELT:  Source ──► Warehouse (bronze) ──► Transform in SQL/Spark ──► Gold
```

### Modern cloud bias: ELT

With cheap storage and powerful engines (Spark, SQL), **load raw first (bronze)**, then transform — matches **Medallion**.

Our Databricks design is **ELT**:

1. **Extract** — read CSV
2. **Load** — bronze Delta tables
3. **Transform** — silver and gold notebooks

### When ETL still appears

- Heavy privacy masking before data enters cloud
- Very small databases where staging outside warehouse is simpler

As a beginner on Databricks, think **ELT + Medallion**.

---

# Part G — Your learning path

---

## Part 20: Guidelines every data engineer should follow

### The ten commandments (liquidity-flavored)

1. **Know your grain** — one row = one meaning; document it.
2. **Never trust silent failure** — alert when feeds or jobs fail.
3. **Keep raw data** — bronze/landing is your audit defense.
4. **Make jobs idempotent** — re-running a day doesn't double counts.
5. **Separate layers** — don't mix cleaning and business metrics.
6. **Name things clearly** — `fact_lcr` beats `table_final_v2`.
7. **Version control everything** — notebooks, SQL, job configs.
8. **Test with bad data** — missing file, empty file, wrong date.
9. **Explain formulas** — LCR logic must be traceable.
10. **Start simple** — batch daily pipeline before real-time streaming.

### Design guidelines for warehousing

| Guideline | Rationale |
|-----------|-----------|
| **Star schema for marts** | Fast queries; intuitive for analysts |
| **Conformed dimensions** | Same `Dim_Entity` across all facts |
| **Surrogate keys** | Integer IDs for dimensions (optional at small scale) |
| **Avoid wide staging** | Staging mirrors source; don't over-model early |
| **Partition large facts by date** | Performance and easy overwrite |

### Collaboration guidelines

- **Data contract** with upstream: file format, delivery time, column definitions
- **SLA** documented: "Feeds by 6 AM; dashboard by 7:30 AM"
- **Change process**: schema changes announced before deployment

---

## Part 21: Hands-on learning path (Level 0 → Level 3)

### Level 0 — Concepts only (you are here)

- [ ] Read this entire `de.md` guide
- [ ] Explain to a friend: LCR, bronze/silver/gold, fact vs dimension
- [ ] Draw the pipeline on paper from memory
- [ ] Complete [Part 22 exercises](#part-22-practice-exercises-no-cloud-required)

**Time:** 3–5 days of reading

---

### Level 1 — Cloud foundations

- [ ] Create Azure subscription / free account
- [ ] Create resource group + ADLS storage account
- [ ] Upload one sample CSV manually
- [ ] Create Databricks workspace; open a notebook
- [ ] Run: `display(spark.read.csv("path"))` and see your data

**Guide:** [`databricks.md`](databricks.md) Sections 2–7

**Time:** 2–3 days

---

### Level 2 — Build the liquidity pipeline

- [ ] Create Unity Catalog and all tables (DDL)
- [ ] Write and test notebooks 01–06 one at a time
- [ ] Create Workflow job with dependencies
- [ ] Run end-to-end for `BusinessDate = 2026-06-17`
- [ ] Query `fact_lcr` and verify numbers make sense

**Guide:** [`databricks.md`](databricks.md) Sections 8–20

**Time:** 1–2 weeks

---

### Level 3 — Production habits

- [ ] Add Lakeview dashboard
- [ ] Configure SQL alerts for breaches
- [ ] Schedule daily job at 7 AM
- [ ] Connect Git repo; commit notebooks
- [ ] Run negative tests (missing feed, forced breach)
- [ ] Optional: compare with Azure ADF path in [`azure.md`](azure.md)

**Guide:** [`databricks.md`](databricks.md) Sections 16–19

**Time:** 1–2 weeks

---

### Level 4 — Career depth (ongoing)

- SQL mastery (joins, windows, CTEs)
- PySpark for transforms
- Data modeling (Kimball books)
- Cloud certification (Databricks DA, Azure DP)
- Second project in another domain (e-commerce, healthcare)

---

## Part 22: Practice exercises (no cloud required)

### Exercise 1 — Explain the story

Write 5 sentences: Why does BANK_UK need a liquidity pipeline? What happens if it fails?

<details>
<summary>Sample answer</summary>

BANK_UK must report LCR daily to prove it can survive a liquidity stress event. The pipeline ingests balances, HQLA, and collateral files, calculates LCR by entity and currency, and shows results on a dashboard. If the pipeline fails silently, treasury might report stale or wrong LCR — leading to regulatory breach or bad decisions. Control tables and alerts exist so failures are visible immediately. Data engineering ensures the numbers are timely, complete, and auditable.

</details>

---

### Exercise 2 — Fact or dimension?

Classify each:

1. `Currency = GBP`
2. `LCR = 1.25`
3. `EntityName = UK Banking Entity`
4. `EncumberedAmount = 5,000,000`
5. `BusinessDate = 2026-06-17`

<details>
<summary>Answers</summary>

1. Dimension attribute  
2. Fact measure  
3. Dimension attribute  
4. Fact measure (or staging detail before aggregation)  
5. Dimension / date key (also a fact grain component)

</details>

---

### Exercise 3 — Draw the medallion

On paper, draw bronze → silver → gold for the **HQLA feed** with table names and one transformation at each layer.

<details>
<summary>Sample</summary>

- **Bronze:** raw CSV columns + LoadTimestamp  
- **Silver:** filter valid HQLALevel; cast MarketValue to decimal; dedupe  
- **Gold:** sum HQLAAfterHaircut by Entity + Currency → feeds into `fact_lcr`

</details>

---

### Exercise 4 — Manual LCR

Given:

- HQLA after haircut: **£39,500,000**
- Net cash outflows: **£17,000,000**

Calculate LCR. Is it above 100%?

<details>
<summary>Answer</summary>

LCR = 39.5 / 17.0 ≈ **2.32 (232%)** — well above 100% regulatory minimum.

</details>

---

### Exercise 5 — Design a feed validation rule

List three checks you'd run on the balances CSV before loading.

<details>
<summary>Sample</summary>

1. File exists and row count > 0  
2. All rows have same BusinessDate  
3. No null Entity or Currency; Balance is numeric  

</details>

---

### Exercise 6 — Spot the mistake

A pipeline **appends** to `fact_lcr` every day without deleting old rows for the same BusinessDate. You re-run the job twice for June 17. What goes wrong?

<details>
<summary>Answer</summary>

Duplicate rows for the same BusinessDate + Entity + Currency. Dashboard might double-count or show wrong aggregates. Fix: idempotent overwrite for that date partition.

</details>

---

## Part 23: Glossary

| Term | Simple definition |
|------|-------------------|
| **ADLS** | Azure Data Lake Storage — cloud folder for big files |
| **Batch** | Processing data in scheduled chunks (e.g. daily) |
| **Bronze** | Raw ingested data layer |
| **BusinessDate** | Reporting date for financial data |
| **Catalog** | Top-level container for tables in Unity Catalog |
| **CSV** | Comma-separated text file format |
| **DAG** | Directed graph of job tasks with dependencies |
| **Dashboard** | Visual display of metrics |
| **Data engineer** | Builds data pipelines and platforms |
| **Data lake** | Storage for files (structured and unstructured) |
| **Data mart** | Subject-focused warehouse (liquidity mart) |
| **Data warehouse** | Central store optimized for analytics |
| **Delta Lake** | Transactional file format on cloud storage |
| **Dimension** | Descriptive context (entity, currency) |
| **ELT** | Extract, Load, Transform |
| **ETL** | Extract, Transform, Load |
| **Fact** | Numeric measurements (LCR, amounts) |
| **Feed** | Incoming data file from a source system |
| **Gold** | Business-ready metrics layer |
| **Grain** | What one row in a table represents |
| **HQLA** | High-Quality Liquid Assets |
| **Idempotent** | Safe to run multiple times with same result |
| **Ingestion** | Loading data into the platform |
| **Lakehouse** | Lake + warehouse unified (Databricks model) |
| **LCR** | Liquidity Coverage Ratio |
| **Lineage** | Trace of where data came from and how it changed |
| **Medallion** | Bronze / silver / gold layering pattern |
| **OLAP** | Analytical query workload |
| **OLTP** | Transactional query workload |
| **Orchestration** | Scheduling and coordinating pipeline steps |
| **Partition** | Splitting table data by column (e.g. date) for speed |
| **Pipeline** | Automated sequence of data steps |
| **Schema** | Structure of columns in a table |
| **Silver** | Cleaned and validated data layer |
| **Staging** | Temporary holding area before mart |
| **Star schema** | Fact table surrounded by dimension tables |
| **Transformation** | Applying business rules to data |
| **Unity Catalog** | Databricks governance for tables and permissions |
| **Upstream** | Source systems that send data to you |

---

## Part 24: What to read and build next

### When concepts feel clear

| Next step | Resource |
|-----------|----------|
| Build on Databricks | [`databricks.md`](databricks.md) — full step-by-step |
| Build on Azure Portal | [`azure.md`](azure.md) — ADF + SQL path |
| Read technical spec | [`instruction.md`](instruction.md) |

### Free external learning

| Resource | Topic |
|----------|-------|
| [Databricks Academy](https://www.databricks.com/learn/training/home) | Free courses (lakehouse fundamentals) |
| *The Kimball Group Reader* | Dimensional modeling (classic) |
| Microsoft Learn — Azure Data Fundamentals | Cloud basics (DP-900 path) |
| SQLBolt or Mode SQL Tutorial | SQL for queries |

### Concepts → skills matrix

| Concept (de.md) | Skill (practice) |
|-----------------|------------------|
| Part 7 Medallion | Create bronze/silver/gold tables in Databricks |
| Part 8 Star schema | Write SQL joins fact to dimensions |
| Part 12 LCR | Implement calculation notebook |
| Part 14 Quality | Add validate-feeds notebook |
| Part 15 Orchestration | Create 6-task Workflow job |
| Part 16 Governance | Unity Catalog grants |

### Final encouragement

Data engineering is **learnable** without a computer science degree. You need:

- Curiosity about how data moves
- Patience when jobs fail (they will)
- Habits: document, test, automate

The liquidity platform in `instruction.md` is a **realistic portfolio project**. Understand it with `de.md`, build it with `databricks.md`, and you will have a story to tell in interviews: *"I built a daily regulatory metrics pipeline from raw CSV to dashboard with alerts and audit controls."*

---

## Quick reference — one page summary

```
BUSINESS:  Treasury needs daily LCR by entity and currency

SOURCES:   3 CSV feeds (balances, HQLA, collateral)

FLOW:      Landing (ADLS) → Bronze → Silver → Gold → Dashboard + Alerts

MODEL:     Star schema — Fact_LCR + dimensions (entity, currency, time)

ENGINE:    Databricks notebooks + Delta Lake + Unity Catalog

SCHEDULE:  Daily job ~7 AM with BusinessDate parameter

TRUST:     feed_status + run_summary + fail-fast validation

LEARN:     de.md (concepts) → databricks.md (build) → iterate
```

Welcome to data engineering. Start with Part 1, take notes, and build when ready.
