{#
    Stand-in for the ingestion job: copy one CSV export unchanged into the raw schema.
    Every column is read as text (all_varchar), so nothing is typed, trimmed or guessed on the way in.
    The CSV dialect is pinned instead of sniffed, so an unusual file fails in the tests, not in the loader.
    Runs as an on-run-start hook (dbt_project.yml); in production a loader would fill these tables.
#}
{% macro load_raw_csv(name) -%}
    create or replace table raw.{{ name }} as
    select
        *,
        current_timestamp as _loaded_at
    from read_csv(
        '{{ var("raw_files_dir") }}/{{ name }}.csv',
        header = true,
        delim = ',',
        quote = '"',
        escape = '"',
        all_varchar = true
    )
{%- endmacro %}
