-- One row per order. Line items are in stg_shopify__order_lines; refunds join via order_refunds.order_id.
-- Note: DuckDB's ->> binds looser than comparison/boolean operators, so JSON extracts are parenthesized.
with orders as (
    select * from {{ source('shopify', 'orders') }}
)

select
    -- ids
    id as order_id,
    name as order_name,
    order_number,
    cast((customer->>'id') as bigint) as customer_id,
    checkout_id,

    -- timestamps
    created_at,
    processed_at,
    updated_at,
    closed_at,
    cancelled_at,

    -- status / exclusion flags
    financial_status,
    fulfillment_status,
    cancel_reason,
    tags,
    coalesce(test, false) or regexp_matches(coalesce(tags, ''), '(^|,)\s*test\s*(,|$)') as is_test,
    regexp_matches(coalesce(tags, ''), '(^|,)\s*wholesale-team-order\s*(,|$)') as is_wholesale,
    cancelled_at is not null as is_cancelled,

    -- money (source stores these as strings)
    cast(total_line_items_price as decimal(12, 2)) as gross_sales,
    cast(total_discounts as decimal(12, 2)) as total_discounts,
    cast(subtotal_price as decimal(12, 2)) as subtotal_price,
    cast((total_shipping_price_set->'shop_money'->>'amount') as decimal(12, 2)) as shipping_price,
    cast(total_tax as decimal(12, 2)) as total_tax,
    cast(total_price as decimal(12, 2)) as total_price,
    cast(current_subtotal_price as decimal(12, 2)) as current_subtotal_price,
    cast(current_total_discounts as decimal(12, 2)) as current_total_discounts,
    cast(current_total_tax as decimal(12, 2)) as current_total_tax,
    cast(current_total_price as decimal(12, 2)) as current_total_price,
    cast(total_outstanding as decimal(12, 2)) as total_outstanding,
    currency,

    -- discounts (source arrays hold at most one entry)
    (discount_codes->0->>'code') as discount_code,
    (discount_applications->0->>'type') as discount_type,

    -- last-click attribution from the converting visit
    landing_site,
    split_part(landing_site, '?', 1) as landing_path,
    lower({{ extract_url_param('landing_site', 'utm_source') }}) as utm_source,
    lower({{ extract_url_param('landing_site', 'utm_medium') }}) as utm_medium,
    {{ extract_url_param('landing_site', 'utm_campaign') }} as utm_campaign,
    {{ extract_url_param('landing_site', 'utm_id') }} as utm_id,
    {{ extract_url_param('landing_site', 'utm_content') }} as utm_content,
    {{ extract_url_param('landing_site', 'utm_term') }} as utm_term,
    {{ extract_url_param('landing_site', 'gclid') }} as gclid,
    {{ extract_url_param('landing_site', 'gbraid') }} as gbraid,
    {{ extract_url_param('landing_site', 'fbclid') }} as fbclid,
    {{ extract_url_param('landing_site', 'ttclid') }} as ttclid,
    {{ extract_url_param('landing_site', 'li_fat_id') }} as li_fat_id,
    {{ extract_url_param('landing_site', '_kx') }} as klaviyo_kx,
    {{ extract_url_param('landing_site', 'srsltid') }} as srsltid,
    referring_site,
    nullif(regexp_extract(referring_site, '^https?://([^/]+)', 1), '') as referrer_domain,

    -- device
    case
        when (client_details->>'user_agent') is null then null
        when (client_details->>'user_agent') ilike '%ipad%'
            or (client_details->>'user_agent') ilike '%tablet%' then 'tablet'
        when (client_details->>'user_agent') ilike '%mobile%'
            or (client_details->>'user_agent') ilike '%android%' then 'mobile'
        else 'desktop'
    end as device_type,

    -- checkout / shipping
    buyer_accepts_marketing,
    customer_locale,
    (payment_gateway_names->>0) as payment_gateway,
    (shipping_lines->0->>'code') as shipping_method,
    (shipping_address->>'city') as shipping_city,
    (shipping_address->>'province_code') as shipping_province_code,
    (shipping_address->>'country_code') as shipping_country_code,
    (shipping_address->>'zip') as shipping_zip,
    total_weight as total_weight_grams,

    shop_url,
    _airbyte_extracted_at
from orders
