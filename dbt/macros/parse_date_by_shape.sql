{#
    Parse a text date with the one format that belongs to its shape (var date_formats_by_shape, or the
    formats passed in). Values of an unknown shape, or impossible dates, become NULL, so not_null tests
    catch them. See Task 1, section 6: automatic format guessing puts dates silently on the wrong day.
#}
{% macro parse_date_by_shape(column, formats=none) -%}
    {%- set formats = formats or var("date_formats_by_shape") -%}
    {%- set value = "trim(" ~ column ~ ")" -%}
    case {{ value_shape(value) }}
        {%- for shape, format in formats.items() %}
        when '{{ shape }}' then try_strptime({{ value }}, '{{ format }}')
        {%- endfor %}
    end::date
{%- endmacro %}
