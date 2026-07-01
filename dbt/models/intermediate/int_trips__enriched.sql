-- Intermediate model: int_trips__enriched
--
-- Intermediate models handle logic that is:
--   - Too complex / reusable to belong in a single mart
--   - Not ready to be a user-facing table yet
--
-- Here: join trips with zone names (pickup + dropoff) and decode
-- payment_type and rate_code from string codes into readable labels.
-- Downstream marts ref this instead of re-joining zones themselves.

with trips as (
    select * from {{ ref('stg_taxi__trips') }}
),

zones as (
    select * from {{ ref('stg_taxi__zones') }}
),

-- payment_type in the source is a string code ("1", "2", etc.)
payment_types as (
    select '1' as payment_type_id, 'Credit card' as payment_type_name union all
    select '2',                    'Cash'                               union all
    select '3',                    'No charge'                          union all
    select '4',                    'Dispute'                            union all
    select '5',                    'Unknown'                            union all
    select '6',                    'Voided trip'
),

rate_codes as (
    select '1' as rate_code_id, 'Standard rate'         as rate_code_name union all
    select '2',                 'JFK'                                      union all
    select '3',                 'Newark'                                   union all
    select '4',                 'Nassau or Westchester'                    union all
    select '5',                 'Negotiated fare'                          union all
    select '6',                 'Group ride'
),

enriched as (
    select
        -- Surrogate key: unique identifier for each trip
        -- dbt_utils.generate_surrogate_key hashes a list of columns into a stable UUID
        {{ dbt_utils.generate_surrogate_key([
            'trips.vendor_id',
            'trips.pickup_datetime',
            'trips.dropoff_datetime',
            'trips.pickup_location_id',
            'trips.dropoff_location_id'
        ]) }}                                      as trip_id,

        -- Pass-through identifiers
        trips.vendor_id,

        -- Timestamps
        trips.pickup_datetime,
        trips.dropoff_datetime,

        -- Location (IDs + human-readable names)
        trips.pickup_location_id,
        pickup_zone.zone_name                      as pickup_zone_name,
        pickup_zone.borough                        as pickup_borough,

        trips.dropoff_location_id,
        dropoff_zone.zone_name                     as dropoff_zone_name,
        dropoff_zone.borough                       as dropoff_borough,

        -- Trip metrics
        trips.passenger_count,
        trips.trip_distance,
        trips.trip_duration_minutes,

        -- Derived: speed in mph
        safe_divide(
            trips.trip_distance,
            trips.trip_duration_minutes / 60.0
        )                                          as avg_speed_mph,

        -- Payment (decoded from string codes)
        trips.payment_type_id,
        pt.payment_type_name,
        trips.rate_code_id,
        rc.rate_code_name,

        -- Financials
        trips.fare_amount,
        trips.extra,
        trips.mta_tax,
        trips.tip_amount,
        trips.tolls_amount,
        trips.imp_surcharge,
        trips.total_amount,

        -- Tip percentage (only meaningful for card payments)
        case
            when trips.payment_type_id = '1' and trips.fare_amount > 0
            then round(safe_divide(trips.tip_amount, trips.fare_amount) * 100, 2)
        end                                        as tip_pct,

        -- Date parts (useful for mart aggregations)
        date(trips.pickup_datetime)                as pickup_date,
        extract(year  from trips.pickup_datetime)  as pickup_year,
        extract(month from trips.pickup_datetime)  as pickup_month,
        extract(hour  from trips.pickup_datetime)  as pickup_hour,
        extract(dayofweek from trips.pickup_datetime) as pickup_day_of_week  -- 1=Sunday

    from trips
    left join zones         as pickup_zone  on trips.pickup_location_id  = pickup_zone.zone_id
    left join zones         as dropoff_zone on trips.dropoff_location_id = dropoff_zone.zone_id
    left join payment_types as pt           on trips.payment_type_id     = pt.payment_type_id
    left join rate_codes    as rc           on trips.rate_code_id        = rc.rate_code_id
)

select * from enriched
