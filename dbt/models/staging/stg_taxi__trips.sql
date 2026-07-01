-- Staging model: stg_taxi__trips
--
-- Rules for staging models:
--   1. Exactly one source table in, one staging model out (1:1)
--   2. Rename columns to your team's conventions
--   3. Cast to correct types
--   4. Basic data cleaning (nulls, sentinel values)
--   5. NO joins, NO aggregations, NO business logic
--
-- The double-underscore in the name (stg_taxi__trips) is a dbt convention:
--   stg_<source>__<table> — makes lineage obvious at a glance.
--
-- NOTE: The 2022 source data contains duplicate trip records (same vendor,
-- timestamps, and locations). We deduplicate here using QUALIFY — the canonical
-- place to handle upstream data quality issues.

with source as (
    select * from {{ source('raw_nyc_taxi', 'trips') }}
),

renamed as (
    select
        -- IDs (all string in source schema)
        vendor_id,
        pickup_location_id,
        dropoff_location_id,

        -- Timestamps
        pickup_datetime,
        dropoff_datetime,

        -- Trip details
        cast(passenger_count as int64)             as passenger_count,
        cast(trip_distance   as float64)           as trip_distance,
        rate_code                                  as rate_code_id,   -- string: "1"–"6"
        store_and_fwd_flag,

        -- Payment (string codes: "1"=credit card, "2"=cash, etc.)
        payment_type                               as payment_type_id,
        cast(fare_amount   as float64)             as fare_amount,
        cast(extra         as float64)             as extra,
        cast(mta_tax       as float64)             as mta_tax,
        cast(tip_amount    as float64)             as tip_amount,
        cast(tolls_amount  as float64)             as tolls_amount,
        cast(imp_surcharge as float64)             as imp_surcharge,
        cast(total_amount  as float64)             as total_amount,

        -- Derived: duration in minutes
        timestamp_diff(dropoff_datetime, pickup_datetime, minute) as trip_duration_minutes,

        data_file_year,
        data_file_month

    from source
),

cleaned as (
    select *
    from renamed
    where
        -- Remove physically impossible records
        trip_distance        > 0
        and fare_amount      > 0
        and total_amount     > 0
        and passenger_count  > 0
        and trip_duration_minutes > 0
        and trip_duration_minutes < 300  -- no trip should take 5+ hours
        and pickup_location_id  is not null
        and dropoff_location_id is not null
),

deduped as (
    select *
    from cleaned
    -- Keep one row per business key; ties broken by lowest fare (arbitrary but stable)
    qualify row_number() over (
        partition by vendor_id, pickup_datetime, dropoff_datetime,
                     pickup_location_id, dropoff_location_id
        order by fare_amount asc
    ) = 1
)

select * from deduped
