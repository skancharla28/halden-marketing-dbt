-- One row per item on a GA4 ecommerce event (view_item, add_to_cart, begin_checkout, purchase),
-- unnested from events.items. item_id = shopify_US_<product_id>_<variant_id>.
-- item_revenue is after discount, and is null on view_item / add_to_cart and on about a third of
-- begin_checkout items (item_variant is missing on the same rows). coupon, item_list_name are always null.
with events as (
    select
        *,
        unnest(items) as item,
        generate_subscripts(items, 1) as item_index
    from {{ source('ga4', 'events') }}
    where len(items) > 0
)

select
    {{ dbt_utils.generate_surrogate_key([
        'user_pseudo_id', 'event_timestamp', 'event_name', ga4_event_param('page_location')
    ]) }} as event_id,
    item_index,
    event_name,
    strptime(event_date, '%Y%m%d')::date as event_date,
    to_timestamp(event_timestamp / 1000000) as event_at,
    user_pseudo_id,
    cast(ecommerce.transaction_id as bigint) as order_id,

    item.item_id,
    cast(split_part(item.item_id, '_', 3) as bigint) as product_id,
    cast(split_part(item.item_id, '_', 4) as bigint) as variant_id,
    item.item_name,
    item.item_variant,
    item.item_category,
    item.item_brand,
    item.quantity,
    cast(item.price as decimal(12, 2)) as unit_price,
    cast(item.item_revenue as decimal(12, 2)) as item_revenue
from events
