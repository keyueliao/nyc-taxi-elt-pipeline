-- Analytics mart: agg_zone_performance
--
-- Per-zone aggregates. Answers: which neighborhoods generate the most revenue?

select
    pickup_location_id                          as zone_id,
    pickup_zone_name                            as zone_name,
    pickup_borough                              as borough,

    -- Volume
    count(*)                                    as total_trips,

    -- Revenue
    round(sum(total_amount), 2)                 as total_revenue,
    round(avg(total_amount), 2)                 as avg_revenue_per_trip,
    round(safe_divide(sum(total_amount), sum(trip_distance)), 2) as revenue_per_mile,

    -- Efficiency
    round(avg(trip_distance), 2)                as avg_trip_distance_miles,
    round(avg(trip_duration_minutes), 1)        as avg_trip_duration_minutes,
    round(avg(avg_speed_mph), 1)                as avg_speed_mph,

    -- Tips
    round(avg(tip_pct), 2)                      as avg_tip_pct,

    -- Top destination borough from this zone
    approx_top_count(dropoff_borough, 1)[offset(0)].value as top_dropoff_borough

from {{ ref('fct_trips') }}
group by 1, 2, 3
order by total_revenue desc
