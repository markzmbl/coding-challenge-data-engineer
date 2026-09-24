{#
    Parse a text date with the one format that belongs to its shape (var date_formats_by_shape).
    Values of an unknown shape, or impossible dates, become NULL, so not_null tests catch them.
    See notebook 01, section 6: automatic format guessing puts dates silently on the wrong day.
#}
{% macro parse_date_by_shape(column) -%}
    {%- set value = "trim(" ~ column ~ ")" -%}
    case {{ value_shape(value) }}
        {%- for shape, format in var("date_formats_by_shape").items() %}
        when '{{ shape }}' then try_strptime({{ value }}, '{{ format }}')
        {%- endfor %}
    end::date
{%- endmacro %}
