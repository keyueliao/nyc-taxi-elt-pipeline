-- Dimension table: dim_taxi_zones
--
-- Classic Type 1 slowly changing dimension (no history — zones rarely change).
-- Analysts join fct_trips on pickup_location_id or dropoff_location_id.

select
    zone_id,
    zone_name,
    borough,

    -- Convenience flag — airport zone names follow a known pattern
    case
        when zone_name in ('JFK Airport', 'LaGuardia Airport', 'Newark Airport')
        then true
        else false
    end as is_airport

from {{ ref('stg_taxi__zones') }}
