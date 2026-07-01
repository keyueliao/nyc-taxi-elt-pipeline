-- Analytics mart: agg_daily_trip_metrics
--
-- Pre-aggregated daily summary for dashboards.
-- Purpose: dashboard tools (Looker Studio, Metabase) hit this instead of
-- scanning the full fct_trips table on every page load.

select
    pickup_date,
    pickup_year,
    pickup_month,

    -- Volume
    count(*)                                    as total_trips,
    sum(passenger_count)                        as total_passengers,

    -- Distance & Duration
    round(sum(trip_distance), 2)                as total_miles,
    round(avg(trip_distance), 2)                as avg_trip_distance_miles,
    round(avg(trip_duration_minutes), 1)        as avg_trip_duration_minutes,
    round(avg(avg_speed_mph), 1)                as avg_speed_mph,

    -- Revenue
    round(sum(total_amount), 2)                 as total_revenue,
    round(avg(total_amount), 2)                 as avg_fare_per_trip,
    round(sum(tip_amount), 2)                   as total_tips,
    round(avg(tip_pct), 2)                      as avg_tip_pct,

    -- Payment mix
    countif(payment_type_name = 'Credit card')  as credit_card_trips,
    countif(payment_type_name = 'Cash')         as cash_trips

from {{ ref('fct_trips') }}
group by 1, 2, 3
order by pickup_date
