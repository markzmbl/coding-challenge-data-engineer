{#
    Parse a text amount that may use a decimal comma ('1299,57') or a decimal point ('422.42').
    The files contain no thousands separators (notebook 01, section 8), so ',' can safely become '.'.
    Blank or unparseable values become NULL; the parses_as_decimal test reports the unparseable ones.
#}
{% macro parse_decimal(column) -%}
    try_cast(replace(nullif(trim({{ column }}), ''), ',', '.') as decimal(12, 2))
{%- endmacro %}
