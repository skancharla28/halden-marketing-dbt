{#
    Extract one query-string parameter from a URL or path, URL-decoded.
    Parameter name match is case-insensitive; returns null when the parameter is absent or empty.
#}
{% macro extract_url_param(url_column, param_name) -%}
    nullif(url_decode(regexp_extract({{ url_column }}, '(?i)[?&]{{ param_name }}=([^&#]*)', 1)), '')
{%- endmacro %}
