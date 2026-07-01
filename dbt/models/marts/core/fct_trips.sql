-- Fact table: fct_trips
--
-- The central fact table in our star schema. One row per trip.
-- All measures (fare, distance, duration) live here.
-- Analysts join this with dim_taxi_zones for geographic breakdowns.
--
-- Materialized as a TABLE partitioned by pickup_date and clustered by
-- pickup_borough so time-range + geographic queries skip irrelevant data.

{{
    config(
        partition_by={
            "field": "pickup_date",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by=["pickup_borough", "payment_type_name"]
    )
}}

with trips as (
    select * from {{ ref('int_trips__enriched') }}
)

select
    -- Keys
    trip_id,
    pickup_location_id,
    dropoff_location_id,
    payment_type_id,
    rate_code_id,
    vendor_id,

    -- Dates
    pickup_date,
    pickup_datetime,
    dropoff_datetime,

    -- Decoded labels (denormalized for query convenience)
    pickup_zone_name,
    pickup_borough,
    dropoff_zone_name,
    dropoff_borough,
    payment_type_name,
    rate_code_name,

    -- Time components (pre-extracted to avoid repeated function calls in queries)
    pickup_year,
    pickup_month,
    pickup_hour,
    pickup_day_of_week,

    -- Measures
    passenger_count,
    trip_distance,
    trip_duration_minutes,
    avg_speed_mph,

    -- Financials
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tip_pct,
    tolls_amount,
    imp_surcharge,
    total_amount

from trips
