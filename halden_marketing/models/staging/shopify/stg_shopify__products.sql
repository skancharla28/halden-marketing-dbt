-- One row per product. Variant detail (color, size, SKU, price) is in stg_shopify__product_variants.
-- Tags are always '<type>, <gender>, <season>', so gender and season are split out.
with products as (
    select * from {{ source('shopify', 'products') }}
)

select
    -- ids
    id as product_id,
    handle,

    -- attributes
    title as product_title,
    vendor,
    product_type,
    product_type = 'Gift Card' as is_gift_card,
    nullif(trim(split_part(tags, ',', 2)), '') as gender,
    nullif(trim(split_part(tags, ',', 3)), '') as season,
    tags,
    status as product_status,
    published_scope,
    (image->>'src') as image_url,

    -- timestamps
    created_at,
    published_at,
    updated_at,

    shop_url,
    _airbyte_extracted_at
from products
