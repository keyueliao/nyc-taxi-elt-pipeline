"""
ELT Ingestion: NYC Taxi public dataset → raw layer in your BigQuery project.

This script demonstrates the "Load" step in ELT:
  - Source: bigquery-public-data.new_york_taxi_trips (Google's hosted public dataset)
  - Destination: <your_project>.raw_nyc_taxi

We copy a full year of trip data into a raw dataset so dbt can own all transforms.
Why copy instead of querying the public dataset directly from dbt?
  - Decouples your pipeline from upstream schema changes
  - Gives you full control over refresh cadence and partitioning
  - Simulates real-world ELT where raw data lands in your warehouse first
"""

import argparse
import logging

from google.cloud import bigquery

logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(levelname)s  %(message)s")
log = logging.getLogger(__name__)

SOURCE_PROJECT = "bigquery-public-data"
SOURCE_DATASET = "new_york_taxi_trips"
RAW_DATASET = "raw_nyc_taxi"


def get_client(project_id: str) -> bigquery.Client:
    return bigquery.Client(project=project_id)


def ensure_dataset(client: bigquery.Client, project_id: str) -> None:
    dataset_ref = f"{project_id}.{RAW_DATASET}"
    dataset = bigquery.Dataset(dataset_ref)
    dataset.location = "US"
    client.create_dataset(dataset, exists_ok=True)
    log.info(f"Dataset ready: {dataset_ref}")


def load_trips(client: bigquery.Client, project_id: str, year: int) -> None:
    """Copy one year of yellow taxi trips into raw_nyc_taxi.trips."""
    source_table = f"{SOURCE_PROJECT}.{SOURCE_DATASET}.tlc_yellow_trips_{year}"
    destination = f"{project_id}.{RAW_DATASET}.trips"

    query = f"""
        SELECT
            vendor_id,
            pickup_datetime,
            dropoff_datetime,
            passenger_count,
            trip_distance,
            rate_code,
            store_and_fwd_flag,
            payment_type,
            fare_amount,
            extra,
            mta_tax,
            tip_amount,
            tolls_amount,
            imp_surcharge,
            total_amount,
            pickup_location_id,
            dropoff_location_id,
            data_file_year,
            data_file_month
        FROM `{source_table}`
    """

    job_config = bigquery.QueryJobConfig(
        destination=destination,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        time_partitioning=bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field="pickup_datetime",
        ),
    )

    log.info(f"Loading {year} trips from {source_table} → {destination} ...")
    job = client.query(query, job_config=job_config)
    job.result()
    log.info("Trips loaded.")


def load_zones(client: bigquery.Client, project_id: str) -> None:
    """Copy the taxi zone lookup table (~265 rows)."""
    destination = f"{project_id}.{RAW_DATASET}.taxi_zones"

    query = f"""
        SELECT
            zone_id,
            zone_name,
            borough
        FROM `{SOURCE_PROJECT}.{SOURCE_DATASET}.taxi_zone_geom`
    """

    job_config = bigquery.QueryJobConfig(
        destination=destination,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    log.info(f"Loading taxi zones → {destination} ...")
    job = client.query(query, job_config=job_config)
    job.result()
    log.info("Zones loaded.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Ingest NYC Taxi data into BigQuery raw layer")
    parser.add_argument("--project", required=True, help="Your GCP project ID")
    parser.add_argument("--year", type=int, default=2023, help="Year to load (default: 2023)")
    args = parser.parse_args()

    client = get_client(args.project)
    ensure_dataset(client, args.project)
    load_trips(client, args.project, args.year)
    load_zones(client, args.project)

    log.info("Ingestion complete. Run `dbt run` next.")


if __name__ == "__main__":
    main()
