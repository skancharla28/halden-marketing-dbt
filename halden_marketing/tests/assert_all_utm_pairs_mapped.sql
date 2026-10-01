-- Fails when Shopify orders or customer journeys contain a utm_source / utm_medium pair that is not in
-- the channel_mapping seed. Fix by adding a row to seeds/channel_mapping.csv. Pairs with no UTMs at all
-- are expected to be unmapped (Direct / Unattributed).
with pairs as (
    select utm_source, utm_medium from {{ ref('stg_shopify__orders') }}
    union
    select first_visit_utm_source, first_visit_utm_medium from {{ ref('stg_shopify__customer_journeys') }}
    union
    select last_visit_utm_source, last_visit_utm_medium from {{ ref('stg_shopify__customer_journeys') }}
)

select pairs.utm_source, pairs.utm_medium
from pairs
left join {{ ref('channel_mapping') }} as mapping
    on pairs.utm_source = mapping.utm_source
    and pairs.utm_medium = mapping.utm_medium
where (pairs.utm_source is not null or pairs.utm_medium is not null)
    and mapping.channel is null
