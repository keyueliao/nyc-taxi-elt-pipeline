-- Macro: cents_to_dollars
--
-- Macros are reusable Jinja functions. Think of them as SQL UDFs but resolved
-- at compile time (before the query hits BigQuery).
--
-- This one is simple — its purpose here is to show the pattern.
-- In interviews, saying "I used dbt macros for X" stands out.

{% macro cents_to_dollars(column_name, precision=2) %}
    round({{ column_name }} / 100.0, {{ precision }})
{% endmacro %}
