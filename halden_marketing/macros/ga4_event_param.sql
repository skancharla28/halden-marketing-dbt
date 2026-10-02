{#
    Extract one value from GA4's event_params list (LIST of STRUCT(key, value STRUCT(string_value,
    int_value, float_value, double_value))). value_type picks the typed slot: string, int, float, double.
    Returns null when the key is absent on the event.
#}
{% macro ga4_event_param(key, value_type='string') -%}
    (list_filter(event_params, lambda param: param.key = '{{ key }}'))[1].value.{{ value_type }}_value
{%- endmacro %}
