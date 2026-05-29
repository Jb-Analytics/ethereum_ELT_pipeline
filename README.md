# Ethereum On-Chain Analytics Pipeline

An enterprise-grade, FinOps-optimized ELT Pipeline orchestrating high-volume Ethereum blockchain data in Snowflake, featuring multi-layer dbt modeling, Security-as-Code, and an automated Slim-CI/CD lifecycle.

## 📌 Architecture Overview

This project implements a robust **Medallion Architecture** to ingest, transform, and govern Ethereum on-chain data (`transactions`, `token_transfers`, `contracts`).

<img width="1552" height="707" alt="ethereum_pipeline" src="https://github.com/user-attachments/assets/37bd9b45-d68f-43ca-971a-f854444479ad" />

---

## 1. Context & Business Problem

The Ethereum blockchain generates massive volumes of semi-structured data. Performing direct analytics on raw ledger events is cost-prohibitive and highly complex due to:
* Hexadecimal and un-typed data fields (e.g., values in Wei requiring 38-decimal precision).
* High-velocity transactional streams requiring incremental partitioning.
* Separation of concerns between core market analytics and sensitive protocol compliance (Fraud & Risk).

This pipeline addresses these challenges by transforming raw Parquet files into high-performance, strictly governed analytics marts tailored for both Data Analysts and Risk Compliance teams.

---

## 2. Modern Data Stack & Tooling

* **Ingestion Layer:** Native **Snowflake External Stages** pointing directly to public AWS S3 data lakes for zero-compute storage integration.
* **Environment & Package Management:** **`uv`** (Astral) utilized exclusively to manage local Python environments, pinning exact dbt CLI dependencies via `uv.lock` for 100% development determinism.
* **Data Warehouse:** **Snowflake** enterprise architecture utilizing decoupled storage stages, optimized compute warehouses, and isolated database environments (DEV/CI/PROD).
* **Transformation Framework:** **dbt Core (v1.9)**, leveraging advanced macros, package management (`dbt_utils`, `codegen`), State Deferral, and Semantic Groups.
* **Orchestration & CI/CD:** **GitHub Actions** enforcing an automated Slim-CI pipeline with ephemeral testing schemas, zero-downtime production deployments and automated metadata cleanup.

---

## 3. Data Ingestion & Storage Strategy

Raw Ethereum logs are stored as Parquet files inside AWS S3 buckets. Ingestion is handled natively via **Snowflake External Stages** mapping directly to cloud URIs:
* `Contract Stage`
* `Transactions Stage`
* `Token Stage`
```sql
CREATE OR REPLACE STAGE eth_bronze.raw.contracts_stage
URL = 's3://aws-public-blockchain/v1.0/eth/contracts'
FILE_FORMAT = (TYPE = 'PARQUET');
```

### FinOps Ingestion Pattern
To minimize Snowflake warehouse uptime and cost during backfills or schedule updates, ingestion uses a dynamic monthly pattern:

```sql
COPY INTO raw_eth.contracts
FROM @contracts_stage
PATTERN = '.*{{ var("current_month") }}.*';
```
---

## 4. Multi-Layer Data Modeling (Medallion)

The dbt project structure separates technical parsing from business metrics into distinct, isolated Snowflake schemas:

**🥉 Bronze Layer (`eth_bronze`)**
* **Materialization:** `view` (Zero additional storage cost).
* **Objective:** Direct 1:1 mapping with raw stages. Performs initial casting and renames fields.
* **Models:** `stg_transactions`, `stg_contracts`, `stg_token_transfers`.

**🥈 Silver Layer (`eth_silver`)**
* **Materialization:** `table` (Optimized with incremental keys when volume requires).
* **Objective:** High-performance denormalization. Performs hex-to-decimal conversion via `conversion_utils.sql`, calculations and joins.
* **Models:** `int_transactions_enriched` — Centralizes the complex and heavy join logic between transactions and token transfers, isolating performance bottlenecks to a single, reusable entity (DRY Principle).

**🥇 Gold Layer (`eth_gold`)**
* **Materialization:** `table` (Highly indexed and clean for BI consumption).
* **Objective:** Business-focused analytics marts.
* **Models:**
  * `eth_activity_per_day`: Global transaction volumes and gas consumption analytics.
  * `stablecoin_activity_per_day`: Merged with our deterministic reference seed (`stablecoins.csv`) to track specific stablecoin activities.
  * `fraud`: A high-value security mart crossing `int_transactions_enriched` with malicious address patterns isolated from `stg_contracts`.

<img width="1476" height="441" alt="eth_lineage" src="https://github.com/user-attachments/assets/7aa77895-6819-41be-8622-99dd470c7a7f" />

---

## 5. Data Governance & Security-as-Code

This repository enforces strict **Role-Based Access Control (RBAC)** and a **Least Privilege** visibility model through automated dbt compilation.

**Separation of Concerns**
* Intermediate and Staging schemas (`Bronze` & `Silver`) are private and strictly reserved for Data Engineers and automated processes.
* Data Analysts (`ROLE DA`) have **zero visbility** over the internal plumbing to avoid report contamination or unauthorized raw access.

**Automated Permissions (Security-as-Code)**

Permissions are declared dynamically inside `dbt_project.yml` using `post-hooks`. Whenever a Gold Mart is generated, access is granted automatically:
```sql
models:
  ethereum_onchain_analytics:
    marts:
      +schema: eth_gold
      +materialized: table
      +tags: ['analytics']
      analytics:
        stablecoin_activity_per_day:
          +post-hook: 
            - "GRANT USAGE ON DATABASE {{ target.database }} TO ROLE DA"
            - "GRANT USAGE ON SCHEMA {{ target.database }}.{{ this.schema }} TO ROLE DA"
            - "GRANT SELECT ON {{ this }} TO ROLE DA"
```

**Infrastructure Authentication**

No static passwords or tokens are stored in the clear. Connections to Snowflake (both local and CI/CD) are strictly authenticated via **Asymmetric RSA Key-Pairs** (`rsa_key.p8` and `rsa_key.pub`), injected securely through GitHub Secrets.

---

## 6. Data Quality & Test Engineering

Data integrity is guarded using a fail-fast mechanism combined with custom generic and singular assertions.

* **Global Safety Flag:** `fail_fast: true` is enabled in `dbt_project.yml` to halt pipeline execution immediately upon test failure, preventing compute waste and upstream report corruption.
* **Custom Testing:** Implements specific blockchain constraint rules like `assert_eth_value_amount_is_positive.sql` and generic test wrappers (`generic_assert_value_amount_is_positive.sql`) to ensure monetary transfers can never contain negative values.

---

## 7. Enterprise CI/CD & Automation Workflow

The pipeline relies on three interconnected GitHub Actions workflows (`.github/workflows/`):

**🧪 1. Slim CI (`dbt-ci.yml`)**

Triggered on any open **Pull Request.**

* Uses **State Deferral** to compare local modifications against the latest production artifacts (`prod/artifacts`).
* Only compiles and runs modified or downstream-impacted models using the command:
```sql
dbt build --select state:modified+ --defer --state prod/artifacts
```
* Isolates tests inside a unique, dynamic `CI` database.

**🚀 2. CD Deployment (`dbt-cd-deploy.yml`)**

Triggered automatically upon a **Merge on Main.**

* Deploys validated modifications to the `PROD` database environment.
* Refreshes production state artifacts to serve as the new baseline for future PRs.

**🧹 3. Ephemeral Cleanup (`cleanup.yml`)**

Triggered automatically on a **daily schedule (02:00 UTC)** and available for **manual execution (`workflow_dispatch`).**

* Invokes the custom dbt macro `ci_schema_cleanup` to scan and execute drop statements on temporary CI schemas created during testing cycles. This automated maintenance prevents database clutter and controls metadata overhead in Snowflake.

---

## 8. Local Development Setup

**Prerequisites**
* Python 3.11+
* `uv` installed locally.

**Installation**

1) Clone the repository and navigate to the root directory:
```
git clone [https://github.com/Jb-Analytics/ethereum_ELT_pipeline.git](https://github.com/Jb-Analytics/ethereum_ELT_pipeline.git)
cd ethereum_ELT_pipeline
```

2) Sync the virtual environment and packages instantaneously using uv:
```
uv sync
```

3) Set up your local `.dbt/profiles.yml` referencing your encrypted private key (`rsa_key.p8`) and run a project compilation:
```
uv run dbt compile --profile ethereum_onchain_analytics
```
