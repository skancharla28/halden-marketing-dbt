-- One row per product variant. variant_id joins to stg_shopify__order_lines.variant_id.
-- Every product's options are [Color, Size], so option1 = color and option2 = size (option3 is unused).
-- The gift card variant is 'Default / $50': color is nulled and size holds the denomination.
with variants as (
    select * from {{ source('shopify', 'product_variants') }}
)

select
    -- ids
    id as variant_id,
    product_id,
    sku,
    barcode,
    inventory_item_id,

    -- attributes
    title as variant_title,
    nullif(option1, 'Default') as color,
    option2 as size,
    position as variant_position,

    -- pricing (source stores price as a string)
    cast(price as decimal(12, 2)) as price,
    cast(compare_at_price as decimal(12, 2)) as compare_at_price,
    taxable as is_taxable,

    -- inventory / fulfillment
    inventory_management,
    inventory_management is not null as is_inventory_tracked,
    inventory_policy,
    inventory_quantity,
    requires_shipping,
    grams,
    weight,
    weight_unit,

    -- timestamps
    created_at,
    updated_at,

    shop_url,
    _airbyte_extracted_at
from variants
