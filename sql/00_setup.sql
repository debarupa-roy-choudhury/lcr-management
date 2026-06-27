-- ============================================================================
-- Unity Catalog Setup for LCR Management Platform
-- ============================================================================
-- Creates the catalog, schemas, and volume for the LCR data pipeline
--
-- Usage:
--   databricks sql execute --file sql/00_setup.sql
--   Or run in Databricks SQL Editor

-- Create catalog
CREATE CATALOG IF NOT EXISTS liquidity_dev
COMMENT 'Liquidity Coverage Ratio (LCR) Management Platform - Basel III Compliance';

-- Create bronze schema (raw data layer)
CREATE SCHEMA IF NOT EXISTS liquidity_dev.bronze
COMMENT 'Bronze layer - Raw data ingested from landing zone CSV files';

-- Create silver schema (cleaned data layer)
CREATE SCHEMA IF NOT EXISTS liquidity_dev.silver
COMMENT 'Silver layer - Cleaned, validated, and deduplicated data';

-- Create gold schema (analytical layer)
CREATE SCHEMA IF NOT EXISTS liquidity_dev.gold
COMMENT 'Gold layer - Dimensional model for LCR analytics and reporting';

-- Create volume for CSV file landing zone
CREATE VOLUME IF NOT EXISTS liquidity_dev.bronze.landing_zone
COMMENT 'Landing zone for CSV file ingestion (balances, hqla, collateral)';

-- Verify structure
SHOW SCHEMAS IN liquidity_dev;
