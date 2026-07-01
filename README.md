# Project 1: NYC Taxi ELT Pipeline

An end-to-end ELT pipeline demonstrating core analytical engineering practices using the modern data stack.

## Stack
- **Ingestion:** Python + BigQuery Storage API
- **Warehouse:** Google BigQuery (partitioned + clustered tables)
- **Transformation:** dbt Core with staging → intermediate → marts layering
- **Testing:** dbt generic tests + custom singular tests
- **CI/CD:** GitHub Actions (runs `dbt build` on every PR)

## Architecture

```
Python ingestion script
        │
        ▼
BigQuery: raw_nyc_taxi
  ├── trips          (partitioned by pickup_datetime)
  └── taxi_zones
        │
        ▼ dbt
BigQuery: staging
  ├── stg_taxi__trips
  └── stg_taxi__zones
        │
        ▼ dbt
BigQuery: intermediate
  └── int_trips__enriched   (joins + decoded labels + derived columns)
        │
        ▼ dbt
BigQuery: marts
  ├── core/
  │   ├── fct_trips          (fact table — one row per trip)
  │   └── dim_taxi_zones     (dimension — one row per zone)
  └── analytics/
      ├── agg_daily_trip_metrics
      └── agg_zone_performance
```

## Key concepts demonstrated

| Concept | Where |
|---|---|
| ELT pattern (load raw, transform in warehouse) | `ingestion/load_taxi_data.py` |
| Staging → intermediate → marts layer pattern | `dbt/models/` |
| Star schema (fact + dimension tables) | `fct_trips`, `dim_taxi_zones` |
| Surrogate keys with `generate_surrogate_key` | `int_trips__enriched.sql` |
| BigQuery partitioning + clustering | `fct_trips.sql` config block |
| dbt generic tests (unique, not_null, relationships) | `_*.yml` schema files |
| dbt singular tests (custom SQL assertions) | `tests/` |
| dbt macros | `macros/cents_to_dollars.sql` |
| dbt packages (dbt_utils) | `packages.yml` |
| CI/CD for data pipelines | `.github/workflows/ci.yml` |
| Source freshness monitoring | `_sources.yml` freshness config |

## Setup

### Prerequisites
- Python 3.11+
- GCP project with BigQuery API enabled
- `gcloud` CLI authenticated (`gcloud auth application-default login`)

### 1. Set your GCP project
```bash
export GCP_PROJECT_ID=your-project-id
gcloud config set project $GCP_PROJECT_ID
```

### 2. Run ingestion (loads raw data to BigQuery)
```bash
cd ingestion
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python load_taxi_data.py --project $GCP_PROJECT_ID --start-date 2023-01-01 --end-date 2024-01-01
```

### 3. Set up dbt
```bash
cd dbt
pip install dbt-bigquery==1.8.2
dbt deps
```

Create `~/.dbt/profiles.yml`:
```yaml
nyc_taxi_pipeline:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: your-project-id
      dataset: dbt_dev
      location: US
      threads: 4
      timeout_seconds: 300
```

### 4. Run the pipeline
```bash
# Test your connection
dbt debug

# Install packages
dbt deps

# Run all models
dbt run

# Test all models
dbt test

# Or do both at once (recommended)
dbt build

# Generate and serve docs
dbt docs generate
dbt docs serve
```

## Dataset

NYC TLC Yellow Taxi trip records, 2023 (≈38M rows). Source: `bigquery-public-data.new_york_tlc.trips`.

The ingestion script copies a date-bounded slice into your own project's `raw_nyc_taxi` dataset, simulating how real ELT pipelines work: data lands in the warehouse raw, and dbt owns all transformation from there.
