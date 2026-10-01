-- One row per order line item, unnested from orders.line_items.
-- Line discount comes from discount_allocations (the line's total_discount field is always 0).
with orders as (
    select * from {{ source('shopify', 'orders') }}
),

lines as (
    select
        orders.id as order_id,
        orders.created_at as order_created_at,
        line.value as line_item
    from orders,
        json_each(orders.line_items) as line
)

select
    cast((line_item->>'id') as bigint) as order_line_id,
    order_id,
    cast((line_item->>'product_id') as bigint) as product_id,
    cast((line_item->>'variant_id') as bigint) as variant_id,
    (line_item->>'sku') as sku,
    (line_item->>'title') as product_title,
    (line_item->>'variant_title') as variant_title,
    (line_item->>'vendor') as vendor,
    cast((line_item->>'quantity') as integer) as quantity,
    cast((line_item->>'price') as decimal(12, 2)) as unit_price,
    cast((line_item->>'price') as decimal(12, 2))
        * cast((line_item->>'quantity') as integer) as gross_amount,
    coalesce((
        select sum(cast((allocation.value->>'amount') as decimal(12, 2)))
        from json_each(line_item->'discount_allocations') as allocation
    ), 0) as discount_amount,
    coalesce((
        select sum(cast((tax.value->>'price') as decimal(12, 2)))
        from json_each(line_item->'tax_lines') as tax
    ), 0) as tax_amount,
    cast((line_item->>'gift_card') as boolean) as is_gift_card,
    cast((line_item->>'requires_shipping') as boolean) as requires_shipping,
    (line_item->>'fulfillment_status') as fulfillment_status,
    order_created_at
from lines
