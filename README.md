# Serverless FX Data Lakehouse on GCP

A serverless Foreign Exchange (FX) data lakehouse pipeline built on Google Cloud Platform (GCP).

The pipeline ingests USD-based foreign exchange rates from an external REST API, performs serverless ingestion and preprocessing using Google Cloud Functions, stores raw and curated data in Google Cloud Storage (GCS), processes curated data using Google Cloud Dataflow, and loads validated records into a partitioned and clustered BigQuery Gold table.

The pipeline is automated using Cloud Scheduler and follows a three-tier Medallion architecture:

**Bronze → Silver → Gold**

---

## Architecture

```text
                    Open Exchange Rates API
                              │
                              ▼
                    Cloud Functions 2nd Gen
                         Python 3.11
                              │
                     ┌────────┴────────┐
                     │                 │
                     ▼                 ▼
                GCS Bronze        GCS Silver
                  Raw JSON          JSONL
                                       │
                                       ▼
                                   Dataflow
                                Apache Beam
                                       │
                                       ▼
                                BigQuery Gold
                                       │
                                       ▼
                              Analytics & Reporting


                    Cloud Scheduler
                           │
                           ▼
                  HTTP + OIDC Authentication
                           │
                           ▼
                  Cloud Functions 2nd Gen
```

Cloud Scheduler triggers the Cloud Function on a scheduled basis. The Cloud Function retrieves FX data from the external API and writes both Bronze and Silver data to Cloud Storage. Dataflow then processes the Silver JSONL files and loads the curated records into the BigQuery Gold table.

---

## Project Overview

This project implements a scalable **three-tier Medallion data architecture** for foreign exchange data.

The architecture separates raw ingestion, data curation, distributed processing, and analytical serving into independent layers.

### Bronze Layer

Stores the original API response in its raw JSON format.

**Purpose:**

* Preserve source data
* Maintain the original API payload
* Support reprocessing and troubleshooting

### Silver Layer

Stores cleaned, standardized, and filtered exchange-rate records in JSONL format.

**Purpose:**

* Remove unnecessary fields
* Select required currencies
* Standardize the data structure
* Prepare data for downstream processing

### Gold Layer

Stores validated analytical records in BigQuery.

**Purpose:**

* Provide a trusted analytical dataset
* Support reporting and downstream analytics
* Optimize analytical queries using partitioning and clustering

---

## Technology Stack

| Technology              | Purpose                                |
| ----------------------- | -------------------------------------- |
| Python 3.11             | Cloud Function runtime                 |
| Open Exchange Rates API | External FX data source                |
| Cloud Functions 2nd Gen | Serverless ingestion and preprocessing |
| Google Cloud Storage    | Data lake storage                      |
| JSON / JSONL            | Raw and curated data formats           |
| Google Cloud Dataflow   | Distributed batch processing           |
| Apache Beam             | Data processing framework              |
| BigQuery                | Analytical warehouse / Gold layer      |
| Cloud Scheduler         | Pipeline automation                    |
| Cloud IAM               | Identity and access management         |

---

## End-to-End Data Flow

```text
External REST API
       │
       ▼
Cloud Functions 2nd Gen
       │
       ├──────────────────┐
       ▼                  ▼
GCS Bronze           GCS Silver
Raw JSON              JSONL
                           │
                           ▼
                       Dataflow
                           │
                    Schema Validation
                           │
                           ▼
                      BigQuery
                           │
                           ▼
                    Gold Analytics
```

### Processing Steps

1. Cloud Scheduler triggers the Cloud Function.
2. The Cloud Function calls the Open Exchange Rates API.
3. The API returns USD-based exchange-rate data.
4. The original API response is stored in the Bronze GCS bucket.
5. The Cloud Function selects the required currencies and standardizes the required fields.
6. The cleaned records are written to the Silver GCS bucket in JSONL format.
7. Dataflow reads the curated Silver JSONL files.
8. Dataflow processes and validates the records according to the configured schema.
9. Validated records are loaded into the BigQuery Gold table.
10. BigQuery provides the final analytical dataset for reporting and downstream analytics.

---

## Medallion Architecture

### 🥉 Bronze — Raw Data

**Purpose:** Preserve the source data in its original form.

```text
Open Exchange Rates API
          │
          ▼
   Cloud Function
          │
          ▼
      GCS Bronze
          │
          ▼
       Raw JSON
```

**Bucket:**

```text
it-prod-landing-as1-raw
```

**Object prefix:**

```text
raw_events/
```

The Bronze layer preserves the original source payload and provides a raw data layer that can be used for auditing, troubleshooting, and potential reprocessing.

---

### 🥈 Silver — Curated Data

**Purpose:** Store cleaned and standardized data suitable for downstream processing.

```text
API Response
     │
     ▼
Cloud Function
     │
     ├── Data Cleaning
     │
     ├── Currency Filtering
     │
     └── Field Standardization
              │
              ▼
            JSONL
              │
              ▼
         GCS Silver
```

**Bucket:**

```text
it-prod-curated-as1-clean
```

The Silver layer contains curated JSONL records with unnecessary fields removed and required currency values standardized.

---

### 🥇 Gold — Analytical Data

**Purpose:** Provide a trusted dataset for analytics and reporting.

```text
Silver JSONL
     │
     ▼
 Dataflow
     │
     ▼
 BigQuery
     │
     ▼
currency_rates_gold
```

**Dataset:**

```text
analytics_lakehouse
```

**Table:**

```text
currency_rates_gold
```

The Gold table is partitioned by `rate_date` and clustered by currency fields to improve query performance for analytical workloads.

---

## Cloud Function

### Function Name

```text
api-to-gcs-raw-ingestion
```

### Runtime

```text
Python 3.11
```

### Entry Point

```text
fetch_and_stage_rates
```

### Trigger

```text
HTTPS
```

### Responsibilities

The Cloud Function:

* Calls the external FX REST API
* Retrieves exchange-rate data
* Preserves the original API response
* Writes raw data to the Bronze layer
* Filters the required currencies
* Standardizes curated records
* Writes JSONL data to the Silver layer
* Adds ingestion metadata

The Cloud Function is deployed using **Cloud Functions 2nd Gen** in the `asia-south1` region.

---

## Supported Currencies

The pipeline processes the following target currencies:

```text
EUR
INR
GBP
JPY
AUD
CAD
SGD
CHF
CNY
AED
```

### Base Currency

```text
USD
```

The pipeline retrieves USD-based exchange rates and processes the configured target currencies.

---

## Dataflow Processing

Google Cloud Dataflow is used for the **Silver-to-Gold batch processing layer**.

### Dataflow Job

```text
curated-to-gold-batch-load
```

### Template

```text
Text Files on Cloud Storage to BigQuery (Batch)
```

### Processing Flow

```text
GCS Silver
    │
    ▼
JSONL Files
    │
    ▼
Dataflow
    │
    ▼
Schema Validation
    │
    ▼
BigQuery Gold
```

Dataflow reads the curated Silver JSONL files, processes the records, validates the expected structure, and loads the resulting records into BigQuery.

The expected BigQuery schema is defined in:

```text
config/schema.json
```

---

## BigQuery Gold Table

### Dataset

```text
analytics_lakehouse
```

### Table

```text
currency_rates_gold
```

### Schema

```text
base_currency
target_currency
exchange_rate
rate_date
ingested_at
```

### Optimization

The table uses:

```text
Partitioning:
rate_date

Clustering:
target_currency
base_currency
```

Partitioning by `rate_date` helps reduce the amount of data scanned for date-based queries.

Clustering by `target_currency` and `base_currency` can improve query performance when filtering or grouping by currency fields.

---

## Schema Validation

The expected schema is defined in:

```text
config/schema.json
```

The schema defines the expected BigQuery structure:

```text
base_currency    → STRING
target_currency  → STRING
exchange_rate    → NUMERIC
rate_date        → DATE
ingested_at      → TIMESTAMP
```

This provides a consistent structure for records before they are loaded into the Gold layer.

---

## Data Quality Checks

The project includes SQL-based sanity checks for the BigQuery Gold dataset.

### Volume Checks

The checks validate:

* Total record count
* Distinct currencies
* Average exchange rate
* Minimum ingestion timestamp
* Maximum ingestion timestamp

### Null Checks

Required fields are checked for null values:

```text
base_currency
target_currency
exchange_rate
rate_date
```

### Duplicate Checks

Duplicate combinations are checked using:

```text
rate_date
base_currency
target_currency
```

### Currency Validation

The validation checks that only the expected target currencies are present.

### Date Validation

The checks validate:

* Future dates
* Missing dates
* Stale data
* Chronological inconsistencies

These checks help verify that the Gold dataset is complete, valid, and suitable for downstream analytics.

---

## Automation

Cloud Scheduler is used to automate the pipeline.

```text
Cloud Scheduler
       │
       ▼
HTTP + OIDC Authentication
       │
       ▼
Cloud Function
       │
       ├───────────────┐
       ▼               ▼
GCS Bronze        GCS Silver
Raw JSON            JSONL
                       │
                       ▼
                   Dataflow
                       │
                       ▼
                BigQuery Gold
```

The pipeline uses a scheduled HTTP request authenticated using **OIDC** to invoke the Cloud Function.

The current project configuration uses a **daily schedule**.

---

## GCP Configuration

```text
GCP Project ID      : snappy-mapper-498509-e0
Region              : asia-south1

Bronze Bucket       : it-prod-landing-as1-raw
Silver Bucket       : it-prod-curated-as1-clean
Scratch Bucket      : it-prod-df-scratch-as1-schema

BigQuery Dataset    : analytics_lakehouse
Gold Table          : currency_rates_gold

Cloud Function      : api-to-gcs-raw-ingestion
Dataflow Job        : curated-to-gold-batch-load
```

> **Note:** If this repository is public, consider replacing environment-specific GCP identifiers with placeholders such as `<GCP_PROJECT_ID>` and `<BUCKET_NAME>`.

---

## Repository Structure

```text
📦 gcp-serverless-fx-data-lakehouse
│
├── 📁 architecture
│   └── 📄 gcp-fx-data-lakehouse-architecture.png
│
├── 📁 docs
│   ├── 📄 01-theory-and-architecture.pdf
│   ├── 📄 02-code-documentation.pdf
│   └── 📄 03-sanity-checks.pdf
│
├── 📁 src
│   └── 📁 cloud_function
│       ├── 📄 main.py
│       └── 📄 requirements.txt
│
├── 📁 config
│   └── 📄 schema.json
│
├── 📁 sql
│   ├── 📄 gold_table.sql
│   └── 📄 verification_queries.sql
│
├── 📁 tests
│   └── 📄 sanity_checks.sql
│
├── 📄 README.md
├── 📄 .gitignore
└── 📄 LICENSE
```

---

## Execution Order

```text
1. Create GCS Bronze, Silver, and Scratch buckets
                    ↓
2. Create BigQuery dataset
                    ↓
3. Create BigQuery Gold table
                    ↓
4. Configure the Dataflow schema
                    ↓
5. Deploy Cloud Function
                    ↓
6. Test Cloud Function
                    ↓
7. Verify Bronze and Silver data
                    ↓
8. Run Dataflow batch job
                    ↓
9. Verify BigQuery Gold table
                    ↓
10. Run data quality / sanity checks
                    ↓
11. Configure Cloud Scheduler
                    ↓
12. Validate automated pipeline execution
```

---

## Security

The project uses **Google Cloud IAM** for access control and follows the principle of least privilege.

### Security Guidelines

Do not commit sensitive credentials or secrets to GitHub.

Never upload:

```text
Service account private keys
API keys
Passwords
Credentials
.env files
Secret files
```

Sensitive configuration such as API credentials should be supplied through appropriate secret or environment-variable mechanisms rather than hard-coded in source code.

The Cloud Scheduler invocation should use authenticated requests with OIDC rather than an unauthenticated HTTP endpoint.

---

## Key Technical Concepts

* REST API ingestion
* Serverless computing
* Cloud Functions 2nd Gen
* Google Cloud Storage
* Medallion architecture
* Bronze / Silver / Gold layers
* JSON and JSONL processing
* Apache Beam
* Google Cloud Dataflow
* Batch ETL
* BigQuery
* Table partitioning
* Table clustering
* Schema validation
* Data quality checks
* Cloud Scheduler
* IAM
* Serverless data lakehouse

---

## Documentation

Detailed project documentation is available in the `docs/` directory:

* **01 — Theory & Architecture**
* **02 — Code Documentation**
* **03 — Sanity Checks**

These documents provide additional information about the architecture, implementation, code, and data quality validation.

---

## Project Status

**Proof of Concept (POC)**

This project demonstrates a serverless Bronze-Silver-Gold data lakehouse architecture on Google Cloud Platform using Cloud Functions, Cloud Storage, Dataflow, BigQuery, Cloud Scheduler, and IAM.
