{#
    Fails for every non-blank value whose shape (see macro value_shape) is not in the list of known shapes.
    Used on the raw date columns, so a new export format fails loudly instead of parsing to NULL.
#}
{% test values_have_shape(model, column_name, shapes) %}

with shaped as (
    select
        {{ column_name }} as value,
        {{ value_shape("trim(" ~ column_name ~ ")") }} as shape
    from {{ model }}
    where nullif(trim({{ column_name }}), '') is not null
)

select *
from shaped
where shape not in (
    {%- for shape in shapes %}'{{ shape }}'{% if not loop.last %}, {% endif %}{% endfor -%}
)

{% endtest %}
