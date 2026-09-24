{#
    Reduce a text value to its format: digits -> 9, runs of capitals -> A, runs of lower-case letters -> a.
    '2024-04-22' -> '9999-99-99', 'Lea.Weber@gmx.at' -> 'Aa.a@a.a'. See notebook 01, section 2.
#}
{% macro value_shape(column) -%}
    regexp_replace(
        regexp_replace(
            regexp_replace({{ column }}, '[0-9]', '9', 'g'),
            '[A-Z]+', 'A', 'g'
        ),
        '[a-z]+', 'a', 'g'
    )
{%- endmacro %}
