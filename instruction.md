# Treasury Liquidity Risk Platform – Azure Implementation Specification

## 0. Overview

This document defines a complete Azure solution for a **Treasury Liquidity Risk** platform using:

- Azure Data Lake Storage (ADLS)
- Azure SQL Database
- Azure Data Factory (ADF)
- Azure Logic Apps
- Azure App Service (Web App)
- Azure Log Analytics
- Azure DevOps (Repos + Pipelines)

The goal is to implement an **end-to-end daily liquidity pipeline** that:

1. Ingests daily liquidity input data from upstream systems into ADLS.
2. Loads and transforms it into an Azure SQL **Liquidity Risk Mart**.
3. Calculates key liquidity metrics (e.g., LCR and intraday buffers).
4. Raises alerts for missing data or limit breaches.
5. Exposes metrics and status via a web dashboard.
6. Is fully managed with DevOps practices (Git, CI/CD, IaC-friendly design).

The document is written so that a coding/automation agent can create the resources, folder structures, pipelines, and DevOps assets in a repeatable way.

---

## 1. Business Domain and Use Case

### 1.1 Business Context

The team works in a bank’s **Treasury** function and is responsible for **Liquidity Risk Management**.

Core objectives:

- Monitor daily and intraday **Liquidity Coverage Ratio (LCR)**.
- Track liquidity buffers by entity and currency.
- Ensure adequate liquidity for regulatory and internal limits.
- Provide transparent audit and monitoring of the data pipeline feeding these metrics.

### 1.2 Data Feeds

Each business day, upstream systems produce data files and drop them into ADLS:

1. **Cash Balances Feed**
   - Source: Core banking / general ledger.
   - Example columns:
     - `BusinessDate`
     - `Entity`
     - `AccountId`
     - `Currency`
     - `Balance`
     - `IntradayTime` (for intraday updates, if available).

2. **HQLA / Securities Holdings Feed**
   - Source: Markets / risk system.
   - Example columns:
     - `BusinessDate`
     - `Entity`
     - `SecurityId`
     - `Currency`
     - `MarketValue`
     - `HQLALevel` (e.g. HQLA1, HQLA2A, HQLA2B)
     - `HaircutPercentage`.

3. **Collateral / Encumbrance Feed**
   - Source: Collateral management system.
   - Example columns:
     - `BusinessDate`
     - `Entity`
     - `AssetId`
     - `Currency`
     - `PledgedFlag` (Y/N)
     - `EncumberedAmount`.

These feeds are delivered as CSV files.

### 1.3 Business Outputs

The platform must produce:

- **Daily LCR metrics** by `BusinessDate`, `Entity`, `Currency`.
- **Intraday liquidity positions** where intraday timestamps are available.
- **Limit flags**:
  - `IsBelowRegulatoryLCR`
  - `IsBelowInternalLCRLimit`
  - `IsLiquidityBufferBelowLimit`.

- Status and evidence:
  - Whether each feed arrived on time.
  - Whether calculations ran successfully.
  - Historical log of runs and alerts.

---

## 2. Azure Resource Design

All resources should, by default, be created in a single Azure region (e.g., `West Europe`), but the design must support multi-environment (Dev, Test, Prod).

### 2.1 Resource Group

Create a resource group per environment:

- Dev: `rg-liquidity-dev`
- Test: `rg-liquidity-test`
- Prod: `rg-liquidity-prod`

Each environment’s resources live in the corresponding resource group.

### 2.2 ADLS (Storage Account)

For each environment:

- **Resource Type**: Storage Account (with hierarchical namespace).
- **Name pattern**: `stliquidity{env}{uniqueSuffix}`
  - Example Dev: `stliquiditydev001`
- **Enable Hierarchical Namespace** (ADLS Gen2).

#### 2.2.1 Containers and Folder Structure

Create container: `datalake`

Under `datalake`, create paths:

- Raw input (landing):
  - `/raw/liquidity/balances/{yyyy}/{MM}/{dd}/`
  - `/raw/liquidity/hqla/{yyyy}/{MM}/{dd}/`
  - `/raw/liquidity/collateral/{yyyy}/{MM}/{dd}/`

- Optional processed/curated areas if needed later:
  - `/curated/liquidity/...`

### 2.3 Azure SQL Database (Liquidity Risk Mart)

For each environment:

1. **SQL Server**
   - Name pattern: `sqlsvr-liquidity-{env}`
     - Example Dev: `sqlsvr-liquidity-dev`
   - Authentication: SQL auth (for simplicity) and/or AAD.

2. **SQL Database**
   - Name pattern: `sqldb-liquidity-{env}`
     - Example Dev: `sqldb-liquidity-dev`.

#### 2.3.1 Database Schema (Core tables)

The agent should create the following example schema (can be adjusted):

**Staging Tables**:

- `stg_Balances`
  - `BusinessDate` (date)
  - `Entity` (nvarchar)
  - `AccountId` (nvarchar)
  - `Currency` (nvarchar(3))
  - `Balance` (decimal(18,2))
  - `IntradayTime` (datetime, nullable)
  - `LoadTimestamp` (datetime)

- `stg_HQLA`
  - `BusinessDate` (date)
  - `Entity` (nvarchar)
  - `SecurityId` (nvarchar)
  - `Currency` (nvarchar(3))
  - `MarketValue` (decimal(18,2))
  - `HQLALevel` (nvarchar(10))
  - `HaircutPercentage` (decimal(5,2))
  - `LoadTimestamp` (datetime)

- `stg_Collateral`
  - `BusinessDate` (date)
  - `Entity` (nvarchar)
  - `AssetId` (nvarchar)
  - `Currency` (nvarchar(3))
  - `PledgedFlag` (nvarchar(1))
  - `EncumberedAmount` (decimal(18,2))
  - `LoadTimestamp` (datetime)

**Dimension Tables** (examples):

- `Dim_Entity`
  - `EntityId` (int, identity)
  - `EntityCode` (nvarchar)
  - `EntityName` (nvarchar)

- `Dim_Currency`
  - `CurrencyCode` (nvarchar(3)) (PK)
  - `Description` (nvarchar)

- `Dim_TimeBucket`
  - `BucketId` (int, identity)
  - `BucketName` (nvarchar)   (e.g., "0–7 days", "8–30 days")
  - `StartDayOffset` (int)
  - `EndDayOffset` (int)

**Fact Tables**:

- `Fact_LiquidityPositions`
  - `BusinessDate` (date)
  - `Entity` (nvarchar)
  - `Currency` (nvarchar(3))
  - `BucketId` (int)
  - `CashFlowAmount` (decimal(18,2))
  - `IsInflow` (bit)
  - `IsOutflow` (bit)

- `Fact_LCR`
  - `BusinessDate` (date)
  - `Entity` (nvarchar)
  - `Currency` (nvarchar(3))
  - `TotalHQLAAfterHaircut` (decimal(18,2))
  - `TotalNetCashOutflows` (decimal(18,2))
  - `LCR` (decimal(9,4))
  - `RegulatoryLimit` (decimal(9,4))
  - `InternalLimit` (decimal(9,4))
  - `IsBelowRegulatoryLCR` (bit)
  - `IsBelowInternalLCRLimit` (bit)

**Run Summary / Control Table**:

- `LiquidityRunSummary`
  - `RunId` (int, identity, PK)
  - `BusinessDate` (date)
  - `Entity` (nvarchar)
  - `Status` (nvarchar(20))  (e.g. Succeeded, Failed, Partial)
  - `AllFeedsReceived` (bit)
  - `LCR` (decimal(9,4), nullable)
  - `IsBelowRegulatoryLCR` (bit, nullable)
  - `IsBelowInternalLCRLimit` (bit, nullable)
  - `ExecutionStartTime` (datetime)
  - `ExecutionEndTime` (datetime)
  - `ErrorMessage` (nvarchar(max), nullable)

#### 2.3.2 Stored Procedures (example set)

Create stored procedures for:

- **Load/Transform procedures**:
  - `sp_Liquidity_Load_Balances`:
    - Inserts/merges from `stg_Balances` into an intermediate or fact structure.
  - `sp_Liquidity_Load_HQLA`.
  - `sp_Liquidity_Load_Collateral`.

- **Calculation procedures**:
  - `sp_Liquidity_Calculate_LCR`:
    - Uses balances, HQLA, collateral, time buckets to compute `Fact_LCR`.
  - `sp_Liquidity_Update_RunSummary`:
    - Writes a record into `LiquidityRunSummary` based on the outcome and computed metrics.

- **Data quality / missing feed checks**:
  - `sp_Liquidity_Check_MissingFeeds`:
    - For a given `BusinessDate`, asserts each expected feed has records; returns flags or raises errors.

The exact SQL logic can be added later by domain experts; the agent should create procedure stubs.

### 2.4 Azure Data Factory (ADF)

For each environment:

- Name pattern: `adf-liquidity-{env}`
  - Example Dev: `adf-liquidity-dev`.

ADF is responsible for orchestrating:

- File ingestion from ADLS into SQL staging.
- Data quality checks.
- Execution of stored procedures for transformation and calculations.
- Logging outcomes into `LiquidityRunSummary`.

#### 2.4.1 Linked Services

Create linked services in ADF:

1. `ls_adls_liquidity`  
   - Type: Azure Data Lake Storage Gen2.
   - Authentication: Account key or Managed Identity (preferred in real production).
   - Points to the environment’s ADLS.

2. `ls_sqldb_liquidity`  
   - Type: Azure SQL Database.
   - Points to `sqldb-liquidity-{env}`.

Additional linked services (if needed):

- `ls_logicapp_notifications` (if using HTTP call with auth, or just use Web activity with URL).
- Optional Key Vault LS for secrets.

#### 2.4.2 Datasets

Create datasets to represent:

- ADLS CSV inputs:
  - `ds_adls_liq_balances`
    - Linked service: `ls_adls_liquidity`.
    - Type: DelimitedText.
    - Parameterized file path: `raw/liquidity/balances/{BusinessDate}/balances_{BusinessDate}.csv`.
  - `ds_adls_liq_hqla`
  - `ds_adls_liq_collateral`

- SQL staging tables:
  - `ds_sql_stg_Balances`
  - `ds_sql_stg_HQLA`
  - `ds_sql_stg_Collateral`

Each dataset should be parameterizable by `BusinessDate` where relevant.

#### 2.4.3 Pipelines

Design the following pipelines:

1. `pl_liq_load_balances`
   - Parameters: `BusinessDate` (string or date).
   - Activities:
     - Copy Activity: ADLS → `stg_Balances`.
     - Optional Data flow or pre-copy script for data cleansing.
   - Error handling: on failure, set pipeline outcome to Failed and optionally write to `LiquidityRunSummary`.

2. `pl_liq_load_hqla`
   - Similar to balances.

3. `pl_liq_load_collateral`
   - Similar to balances.

4. `pl_liq_master_daily_liquidity`
   - Parameters: `BusinessDate`.
   - Activities (in sequence or with dependencies):
     1. **Check feeds / pre-validation**:
        - Option A: Stored Procedure activity calling `sp_Liquidity_Check_MissingFeeds` (after or during loads).
        - Option B: Custom logic using Lookup + If Condition to confirm ADLS files exist.
     2. **Execute child pipelines**:
        - Execute `pl_liq_load_balances`.
        - Execute `pl_liq_load_hqla`.
        - Execute `pl_liq_load_collateral`.
     3. **Transform and calculate metrics**:
        - Stored Procedure activity: `sp_Liquidity_Load_Balances`.
        - SP: `sp_Liquidity_Load_HQLA`.
        - SP: `sp_Liquidity_Load_Collateral`.
        - SP: `sp_Liquidity_Calculate_LCR`.
     4. **Update run summary**:
        - Stored Procedure activity: `sp_Liquidity_Update_RunSummary`.
     5. **Notify logic app**:
        - Web activity that calls Logic App HTTP trigger URL, passing JSON payload:
          - `BusinessDate`
          - `Entity` (if aggregated per entity)
          - `Status`
          - `LCR`
          - `IsBelowRegulatoryLCR`
          - `IsBelowInternalLCRLimit`
          - `AllFeedsReceived`
          - `RunId` (from SQL or ADF system variables).

5. Scheduling:
   - Create a Trigger (Schedule) in ADF:
     - Name: `tr_liq_daily_run`.
     - Frequency: daily at a defined time (e.g., 07:00 local time).
     - Trigger parameter: `BusinessDate` (can be `@{formatDateTime(pipeline().TriggerTime, 'yyyy-MM-dd')}` or D-1 logic depending on bank cut-off).

### 2.5 Azure Logic Apps (Alerts & Notifications)

For each environment:

- Name pattern: `la-liquidity-notify-{env}`.

#### 2.5.1 Trigger

Use **HTTP trigger** for simplicity:

- Trigger: `When an HTTP request is received`.
- Request body JSON schema should support:
  - `BusinessDate`
  - `Entity`
  - `Status`
  - `LCR`
  - `IsBelowRegulatoryLCR`
  - `IsBelowInternalLCRLimit`
  - `AllFeedsReceived`
  - `RunId`
  - Optional: detailed error message.

#### 2.5.2 Actions

- Parse JSON from HTTP body.
- Conditions:
  - If `Status` is `Failed` OR `AllFeedsReceived` is `false`:
    - Send high-priority alert (email/Teams).
  - Else if `IsBelowRegulatoryLCR` is `true` OR `IsBelowInternalLCRLimit` is `true`:
    - Send risk alert to treasury team.
  - Else:
    - Send informational message (optional).

- Outputs:
  - Send email (Office 365) or Teams message with:
    - Subject like `"Liquidity Run {BusinessDate} - Status: {Status}"`.
    - Body with key metrics and links to:
      - ADF Monitor.
      - App Service dashboard.

### 2.6 Azure App Service (Liquidity Dashboard)

For each environment:

- **App Service Plan**:
  - Name: `asp-liquidity-{env}`.
- **Web App**:
  - Name pattern: `app-liquidity-dashboard-{env}`.

#### 2.6.1 Configuration

- Add connection string:
  - Name: `LiquidityDb`.
  - Type: SQL Azure.
  - Value: connection string to `sqldb-liquidity-{env}`.

#### 2.6.2 Dashboard Features

The app should at minimum expose:

1. **Daily LCR View**
   - Table or chart showing:
     - `BusinessDate`, `Entity`, `Currency`, `LCR`, `RegulatoryLimit`, `InternalLimit`.
   - Highlight LCR below limits in red.

2. **Run Status View**
   - Show latest entries from `LiquidityRunSummary`.
   - Include:
     - `Status`
     - `AllFeedsReceived`
     - Start/End times
     - Hyperlink to ADF monitor if possible.

3. **Feed Status Summary**
   - Show, for the latest `BusinessDate`, whether each feed (Balances, HQLA, Collateral) was received.

The implementation language (e.g., .NET, Node.js, Python) is flexible; the spec only requires DB connectivity and the above minimal views.

### 2.7 Azure Log Analytics (Monitoring & Audit)

For each environment:

- Name pattern: `law-liquidity-{env}`.

#### 2.7.1 Diagnostic Settings

Configure diagnostics to send logs and metrics to the workspace for:

- Storage account (ADLS).
- Data Factory.
- Logic App.
- App Service.
- SQL Database (where available).

The agent should:

1. Create diagnostic settings per resource.
2. Select relevant log categories (pipelineRuns, activityRuns, HTTP logs, workflow runtime, etc.).
3. Send them to `law-liquidity-{env}`.

#### 2.7.2 Basic KQL Queries (optional definitions)

The agent may create saved queries such as:

- Failed liquidity pipelines:
  - Filter on ADF resource and `Status` = Failed.
- LCR limit breaches:
  - Query `Fact_LCR` via Log Analytics if integrating or store similar signals in logs.
- Run history evidence:
  - “Show all successful `pl_liq_master_daily_liquidity` runs in last 90 days.”

---

## 3. Azure DevOps Setup (CI/CD for Liquidity Platform)

### 3.1 Azure DevOps Project

Create an Azure DevOps project:

- Name: `treasury-liquidity-risk`.

Create one Azure DevOps organization or reuse an existing one.

### 3.2 Repositories

Create two primary repos:

1. `liquidity-app`
   - Contains App Service web application code.
   - Contains its own `azure-pipelines.yml` for CI/CD.

2. `liquidity-adf`
   - Holds Azure Data Factory JSON (Git integration).
   - Holds ADF CI/CD pipeline YAML.

Optional third repo for Infrastructure-as-Code:

3. `liquidity-infra`
   - Contains Bicep/ARM templates for Storage, SQL, ADF, Logic Apps, App Service, Log Analytics.

### 3.3 Service Connections

Create an **Azure Resource Manager service connection** for each environment or one with scope to subscription:

- Name example: `sc-azure-liquidity`.
- This is used by pipelines to deploy to Azure.

---

## 4. ADF + Azure DevOps CI/CD (Liqudity Pipelines)

### 4.1 Git Integration for ADF

In **Dev** environment ADF (`adf-liquidity-dev`):

- Configure Git:
  - Repository type: Azure DevOps Git.
  - Organization: the Azure DevOps organization.
  - Project: `treasury-liquidity-risk`.
  - Repository: `liquidity-adf`.
  - Collaboration branch: `main`.
  - Publish branch: `adf_publish`.

Agents steps:

1. Set ADF into Git mode.
2. Ensure all existing pipelines are committed to `main`.
3. Use “Publish” in ADF to generate/refresh ARM template into `adf_publish` branch.

### 4.2 ADF CI Pipeline (Validation & Packaging)

Create a YAML pipeline in `liquidity-adf` repo, e.g. `.azure-pipelines/adf-ci.yml`.

- Trigger:
  - On updates to `adf_publish` branch.

- Steps (conceptual – exact tasks may vary):
  - Install Node.js.
  - Install Azure Data Factory utilities (publish-adf).
  - Run validation & packaging of ADF.
  - Publish ARM template artifact named `adf_liquidity_arm`.

The CI pipeline output is a versioned artifact that can be deployed to Test/Prod ADF instances.

### 4.3 ADF CD Pipeline (Deploy to Test/Prod)

Use either:

- Classic Release Pipeline, or
- Multi-stage YAML pipeline.

Requirements:

- Stage `Deploy_Test`:
  - Consumes `adf_liquidity_arm` artifact.
  - Deploys ARM template to `adf-liquidity-test` in `rg-liquidity-test`.
  - Uses parameter files for Test environment (different linked service configs, etc.).
- Stage `Deploy_Prod`:
  - Similar to Test but target `adf-liquidity-prod` and `rg-liquidity-prod`.
  - Protected with manual approvals and checks.

The CD pipeline must ensure:

- Only validated ADF artifacts are deployed.
- Changes are auditable and revertible.

---

## 5. App Service CI/CD with Azure DevOps

### 5.1 CI Pipeline for `liquidity-app`

Create `azure-pipelines.yml` in `liquidity-app` repo.

- Trigger on `main` branch.
- Build and test the web app.
- Publish build artifacts (e.g., zipped web app).

Example tasks:

- For .NET:
  - Restore → Build → Test → Publish.
- For Node/Python:
  - Equivalent tasks (install, test, build, package).

### 5.2 Multi-stage CI/CD Pipeline (Build + Deploy)

Extend YAML to include stages:

1. `Build` stage:
   - Builds and publishes `drop` artifact.

2. `Deploy_Dev` stage:
   - Deploys artifact to `app-liquidity-dashboard-dev`.
   - Uses `AzureWebApp` or equivalent task.

3. `Deploy_Test` and `Deploy_Prod` stages:
   - Optionally added with approvals, separate app names:
     - `app-liquidity-dashboard-test`
     - `app-liquidity-dashboard-prod`.

Each stage references the correct App Service and resource group, using `sc-azure-liquidity` service connection.

---

## 6. Infrastructure as Code (Optional but Recommended)

If the coding agent supports IaC:

- Define Bicep/ARM templates in `liquidity-infra` repo for:
  - Resource groups.
  - Storage accounts with ADLS.
  - SQL Servers and Databases (with schemas, if possible).
  - Data Factory instances.
  - Logic Apps.
  - App Service Plans and Web Apps.
  - Log Analytics workspaces.
  - Diagnostic settings to route logs to Log Analytics.

Create a pipeline `infra-deploy.yml` that:

- Deploys Dev infra on each change (or manually).
- Deploys Test/Prod with approvals.

---

## 7. Operational & Learning Notes for the Agent

1. **Order of creation**:
   - Infra (RG, Storage, SQL, ADF, Logic Apps, App Service, Log Analytics).
   - SQL schema (tables + procedures).
   - ADF linked services, datasets, and pipelines.
   - Logic App workflow.
   - App Service application deployment.
   - DevOps pipelines (infra, app, ADF).

2. **Configuration management**:
   - Use environment-specific parameter files for ADF and infra templates.
   - Use separate connection strings per environment for the web app.

3. **Security & secrets**:
   - In a real bank, secrets should be stored in Azure Key Vault and referenced via managed identities.
   - This spec allows simpler configurations for learning, but should be extended to Key Vault later.

4. **Extensibility**:
   - Add more feeds (e.g., stress test scenarios).
   - Add more metrics (NSFR, intraday stress metrics).
   - Add additional dashboards/analytics integrations.

---

## 8. Acceptance Criteria (for successful implementation)

The implementation is considered successful when:

1. A daily ADF trigger runs `pl_liq_master_daily_liquidity` for a given `BusinessDate`.
2. For that date:
   - Data from all three feeds are loaded into SQL staging.
   - Transformations and LCR calculation procedures run without error.
3. A record is inserted into `LiquidityRunSummary` with the correct status and metrics.
4. If metrics or feeds violate predefined conditions:
   - Logic App sends notifications with correct details.
5. The App Service dashboard:
   - Shows latest LCR per entity and currency.
   - Shows run status and feed status.
6. Azure DevOps pipelines:
   - CI for `liquidity-app` completes and publishes an artifact.
   - CI for `liquidity-adf` completes and publishes the ADF ARM artifact.
   - CD pipelines can deploy to another environment by running from Azure DevOps, without manual portal changes.
7. Log Analytics contains logs for:
   - ADF pipeline runs.
   - Logic App runs.
   - App Service logs and errors.
   - Database/infra diagnostics as configured.

When all these conditions are met in Dev, the same process is repeatable to Test and Prod using CI/CD.
