{#
    Fails for every non-blank value that the parse_decimal macro cannot turn into a number,
    e.g. a thousands separator ('1.299,57') or text ('n/a').
#}
{% test parses_as_decimal(model, column_name) %}

select {{ column_name }} as value
from {{ model }}
where nullif(trim({{ column_name }}), '') is not null
    and {{ parse_decimal(column_name) }} is null

{% endtest %}
