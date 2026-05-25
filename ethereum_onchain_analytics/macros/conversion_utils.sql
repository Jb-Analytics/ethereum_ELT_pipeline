{% macro convertion(column_name, decimals) %}

    sum({{ column_name }} / power(10, {{ decimals }}))

{% endmacro %}
