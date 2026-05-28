{% test assert_value_amount_is_positive(model, column_name) %}

select
  sum({{ column_name }}) as total_amount
from {{ model }}
having total_amount < 0

{% endtest %}