-- Custom singular test: assert no trip has a negative total_amount.
--
-- Generic tests (not_null, unique) live in .yml files.
-- Singular tests are SQL files that return rows on FAILURE.
-- dbt considers a test failed if the query returns any rows.
-- Use these when the logic is too complex for a generic test.

select
    trip_id,
    total_amount,
    fare_amount,
    tip_amount

from {{ ref('fct_trips') }}

where total_amount < 0
   or fare_amount  < 0
   or tip_amount   < 0
