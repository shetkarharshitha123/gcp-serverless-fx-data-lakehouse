````markdown
# Serverless FX Data Lakehouse on GCP

A serverless Foreign Exchange (FX) data lakehouse pipeline built on Google Cloud Platform (GCP).

The pipeline ingests USD-based foreign exchange rates from an external REST API, performs serverless ingestion and preprocessing using Google Cloud Functions, stores data across Bronze and Silver Cloud Storage layers, processes curated data using Google Cloud Dataflow, and loads validated records into a partitioned and clustered BigQuery Gold table.

The pipeline is automated using Cloud Scheduler and follows a three-tier Medallion architecture: **Bronze → Silver → Gold**.

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
          GCS Bronze          GCS Silver
           Raw JSON            JSONL
                 │                 │
                 │                 ▼
                 │              Dataflow
                 │           Apache Beam
                 │                 │
                 │                 ▼
                 │           BigQuery Gold
                 │                 │
                 │                 ▼
                 │       Analytics & Reporting
                 │
                 └─────────────────────────

                    Cloud Scheduler
                          │
                          ▼
                   Cloud Function
                    Daily Trigger
````

---

## Project Overview

The pipeline is designed to implement a scalable **three-tier Medallion data architecture** for foreign exchange data.

### Bronze Layer

Stores the original API payload in its raw JSON format.

### Silver Layer

Stores cleaned, standardized, and filtered exchange-rate records as JSONL.

### Gold Layer

Stores validated analytical records in BigQuery for reporting and downstream analytics.

The architecture separates raw ingestion, data curation, distributed processing, and analytical serving into independent layers. 

---

## Technology Stack

| Technology              | Purpose                                |
| ----------------------- | -------------------------------------- |
| Python 3.11             | Cloud Function runtime                 |
| Open Exchange Rates API | External FX data source                |
| Cloud Functions 2nd Gen | Serverless ingestion and preprocessing |
| Cloud Storage           | Data lake storage                      |
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
       ↓
Cloud Functions
       ↓
 ┌─────┴──────┐
 ↓            ↓
Bronze       Silver
 GCS          GCS
Raw JSON     JSONL
                ↓
             Dataflow
                ↓
             BigQuery
                ↓
          Gold Analytics
```

### Processing Steps

1. The Cloud Function calls the Open Exchange Rates API.
2. The API returns USD-based exchange-rate data.
3. The original response is stored in the Bronze GCS bucket.
4. The Cloud Function selects and standardizes the required currency records.
5. Cleaned records are written to the Silver GCS bucket in JSONL format.
6. Dataflow reads the curated Silver files.
7. Dataflow validates the records against the BigQuery schema.
8. Validated records are loaded into the BigQuery Gold table.
9. BigQuery provides the final analytical dataset.
10. Cloud Scheduler triggers the ingestion process automatically.

The documented Cloud Function writes both the raw Bronze data and the cleaned Silver data. 

---

## Medallion Architecture

### 🥉 Bronze — Raw Data

**Purpose:** Preserve the source data in its original form.

```text
Open Exchange Rates API
          ↓
    Cloud Function
          ↓
      GCS Bronze
          ↓
       Raw JSON
```

Bucket:

```text
it-prod-landing-as1-raw
```

Raw files are stored under:

```text
raw_events/
```

The Bronze layer is intended to retain immutable source payloads so the data can be reprocessed if required. 

---

### 🥈 Silver — Curated Data

**Purpose:** Store cleaned and standardized data suitable for downstream processing.

```text
Bronze / API Data
       ↓
Cloud Function
       ↓
Data Cleaning
       ↓
Currency Filtering
       ↓
JSONL
       ↓
GCS Silver
```

Bucket:

```text
it-prod-curated-as1-clean
```

The Silver layer contains cleansed JSONL records with unnecessary fields removed and currency values standardized. 

---

### 🥇 Gold — Analytical Data

**Purpose:** Provide a trusted dataset for analytics and reporting.

```text
Silver JSONL
      ↓
Dataflow
      ↓
BigQuery
      ↓
currency_rates_gold
```

Table:

```text
analytics_lakehouse.currency_rates_gold
```

The Gold table is partitioned by `rate_date` and clustered by currency fields to improve analytical query performance. 

---

## Cloud Function

### Function

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
* Creates the raw Bronze payload
* Filters required currencies
* Creates curated Silver records
* Writes JSON data to GCS
* Adds ingestion metadata

The documented implementation uses Cloud Functions 2nd Gen in `asia-south1`. 

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

Base currency:

```text
USD
```

The currency selection is defined in the project implementation. 

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
    ↓
JSONL Files
    ↓
Dataflow
    ↓
Schema Validation
    ↓
BigQuery
```

Dataflow validates the curated files using `schema.json` before loading the records into BigQuery. 

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

Partitioning reduces the amount of data scanned for date-based queries, while clustering improves filtering on currency columns.

---

## Schema Validation

The Dataflow pipeline uses:

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

This provides structural validation before data reaches the Gold layer.

---

## Data Quality Checks

The project includes SQL-based sanity checks for the Gold dataset.

### Volume Checks

Validates:

* Total record count
* Distinct currencies
* Average exchange rate
* Minimum ingestion timestamp
* Maximum ingestion timestamp

### Null Checks

Validates required fields such as:

```text
base_currency
target_currency
exchange_rate
rate_date
```

### Duplicate Checks

Checks duplicate combinations of:

```text
rate_date
base_currency
target_currency
```

### Currency Validation

Validates that only the expected target currencies are present.

### Date Validation

Checks for:

* Future dates
* Invalid dates
* Stale data
* Chronological inconsistencies

These checks are defined in the project's sanity-check documentation.   

---

## Automation

Cloud Scheduler is used to trigger the Cloud Function automatically.

```text
Cloud Scheduler
       ↓
HTTP + OIDC Authentication
       ↓
Cloud Function
       ↓
Bronze + Silver
       ↓
Dataflow
       ↓
BigQuery Gold
```

The documented design uses a daily Cloud Scheduler job with an HTTP trigger and OIDC authentication. 

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

The bucket names and region are defined in the project implementation documentation. 

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



## Execution Order

```text
1. Create GCS Bronze, Silver and Scratch buckets
                    ↓
2. Create BigQuery dataset
                    ↓
3. Create BigQuery Gold table
                    ↓
4. Upload schema.json
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
10. Run sanity checks
                    ↓
11. Configure Cloud Scheduler
                    ↓
12. Automate the pipeline
```



## Security

The project uses Google Cloud IAM for access control and follows the principle of least privilege.

Do not commit sensitive credentials to GitHub.

Never upload:

```text
Service account private keys
API keys
Passwords
Credentials
.env files
Secret files
```



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
* Data validation
* Data quality checks
* Cloud Scheduler
* IAM
* Serverless data lakehouse



## Documentation

Detailed project documentation is available in the `docs/` directory:

* **01 — Theory & Architecture**
* **02 — Code Documentation**
* **03 — Sanity Checks**

---

## Project Status

**Proof of Concept (POC)**

Built using Google Cloud Platform with a serverless Bronze-Silver-Gold data lakehouse architecture.

````



