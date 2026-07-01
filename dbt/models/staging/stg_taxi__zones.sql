-- Staging model: stg_taxi__zones
--
-- The source taxi_zone_geom table has duplicate zone_ids (IDs 56 and 103).
-- This is a real data quality issue in the upstream source.
-- We deduplicate here in staging — the canonical place to handle source messiness.
-- QUALIFY + ROW_NUMBER is the idiomatic BigQuery pattern for deduplication.

with source as (
    select * from {{ source('raw_nyc_taxi', 'taxi_zones') }}
),

renamed as (
    select
        zone_id,
        zone_name,
        borough
    from source
),

deduped as (
    select *
    from renamed
    qualify row_number() over (partition by zone_id order by zone_name) = 1
)

select * from deduped
