-- One row per order: Shopify's first-visit / last-visit summary for first- vs last-touch attribution.
-- Visit fields are null when the journey was not tracked (~12% of orders).
-- UTM values here are already URL-decoded (unlike orders.landing_site).
with journeys as (
    select
        order_id,
        created_at,
        customer_journey_summary as journey,
        _airbyte_extracted_at
    from {{ source('shopify', 'customer_journey_summary') }}
)

select
    order_id,
    created_at as order_created_at,
    cast((journey->>'customerOrderIndex') as integer) as customer_order_index,
    cast((journey->>'daysToConversion') as integer) as days_to_conversion,
    cast((journey->>'momentsCount') as integer) as moments_count,
    (journey->'firstVisit'->>'occurredAt') is not null as has_journey,
{%- for visit in ['first', 'last'] %}
{%- set path = "journey->'" ~ visit ~ "Visit'" %}

    -- {{ visit }} visit
    cast(({{ path }}->>'occurredAt') as timestamptz) as {{ visit }}_visit_at,
    ({{ path }}->>'source') as {{ visit }}_visit_source,
    ({{ path }}->>'sourceType') as {{ visit }}_visit_source_type,
    ({{ path }}->>'landingPage') as {{ visit }}_visit_landing_page,
    ({{ path }}->>'referrerUrl') as {{ visit }}_visit_referrer_url,
    lower(({{ path }}->'utmParameters'->>'source')) as {{ visit }}_visit_utm_source,
    lower(({{ path }}->'utmParameters'->>'medium')) as {{ visit }}_visit_utm_medium,
    ({{ path }}->'utmParameters'->>'campaign') as {{ visit }}_visit_utm_campaign,
    ({{ path }}->'utmParameters'->>'content') as {{ visit }}_visit_utm_content,
    ({{ path }}->'utmParameters'->>'term') as {{ visit }}_visit_utm_term,
{%- endfor %}

    _airbyte_extracted_at
from journeys
