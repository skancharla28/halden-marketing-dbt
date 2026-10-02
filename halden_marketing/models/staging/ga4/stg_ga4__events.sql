{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='event_date',
        on_schema_change='append_new_columns'
    )
}}

-- One row per GA4 event (session_start, first_visit, page_view, view_item, add_to_cart, begin_checkout,
-- purchase). event_params is a fixed set of 17 keys (one value each), so it's pivoted into typed columns
-- here; items has its own model (stg_ga4__event_items). user_properties, user_ltv, app_info, publisher
-- and event_dimensions are always empty and dropped.
-- Incremental by day: GA4 restates a day's events for up to ~72h, so each run deletes and re-inserts
-- the last N event_dates (var ga4_lookback_days, default 3). Events are not updated individually, so
-- replacing whole days is safer than merging on a row key. Full rebuild: --full-refresh.
-- No natural key: two event pairs share user + timestamp + name (a collided session), so event_id also
-- hashes page_location. No Airbyte metadata columns on this table.
with events as (
    select * from {{ source('ga4', 'events') }}
    {% if is_incremental() %}
    where event_date >= (
        select strftime(max(event_date) - interval '{{ var("ga4_lookback_days", 3) }} days', '%Y%m%d')
        from {{ this }}
    )
    {% endif %}
)

select
    -- keys
    {{ dbt_utils.generate_surrogate_key([
        'user_pseudo_id', 'event_timestamp', 'event_name', ga4_event_param('page_location')
    ]) }} as event_id,
    {{ dbt_utils.generate_surrogate_key(['user_pseudo_id', ga4_event_param('ga_session_id', 'int')]) }}
        as session_key,
    user_pseudo_id,
    {{ ga4_event_param('ga_session_id', 'int') }} as ga_session_id,
    {{ ga4_event_param('ga_session_number', 'int') }} as ga_session_number,
    cast(user_id as bigint) as customer_id,
    cast(ecommerce.transaction_id as bigint) as order_id,

    -- event
    event_name,
    strptime(event_date, '%Y%m%d')::date as event_date,
    to_timestamp(event_timestamp / 1000000) as event_at,
    to_timestamp(user_first_touch_timestamp / 1000000) as user_first_touch_at,

    -- page
    {{ ga4_event_param('page_location') }} as page_location,
    split_part(split_part({{ ga4_event_param('page_location') }}, '?', 1), '#', 1) as page_url,
    {{ ga4_event_param('page_title') }} as page_title,
    {{ ga4_event_param('page_referrer') }} as page_referrer,

    -- session source (landing events only: session_start, first_visit, landing page_view)
    lower({{ ga4_event_param('source') }}) as utm_source,
    lower({{ ga4_event_param('medium') }}) as utm_medium,
    {{ ga4_event_param('campaign') }} as utm_campaign,
    {{ ga4_event_param('campaign_id') }} as utm_id,
    {{ ga4_event_param('content') }} as utm_content,
    {{ ga4_event_param('term') }} as utm_term,
    {{ ga4_event_param('gclid') }} as gclid,
    {{ extract_url_param(ga4_event_param('page_location'), 'gbraid') }} as gbraid,
    {{ extract_url_param(ga4_event_param('page_location'), 'fbclid') }} as fbclid,
    {{ extract_url_param(ga4_event_param('page_location'), 'ttclid') }} as ttclid,
    {{ extract_url_param(ga4_event_param('page_location'), 'li_fat_id') }} as li_fat_id,
    {{ extract_url_param(ga4_event_param('page_location'), '_kx') }} as klaviyo_kx,
    collected_traffic_source.srsltid,

    -- GA4's own attribution
    session_traffic_source_last_click.cross_channel_campaign.default_channel_group
        as ga4_last_click_channel_group,
    lower(session_traffic_source_last_click.cross_channel_campaign.source) as ga4_last_click_source,
    lower(session_traffic_source_last_click.cross_channel_campaign.medium) as ga4_last_click_medium,
    session_traffic_source_last_click.cross_channel_campaign.campaign_id as ga4_last_click_campaign_id,
    session_traffic_source_last_click.cross_channel_campaign.campaign_name as ga4_last_click_campaign_name,
    session_traffic_source_last_click.google_ads_campaign.ad_group_id as ga4_last_click_google_ad_group_id,
    lower(traffic_source.source) as first_user_source,
    lower(traffic_source.medium) as first_user_medium,
    traffic_source.name as first_user_campaign,

    -- ecommerce (value on view_item / add_to_cart / begin_checkout / purchase; the rest on purchase only)
    {{ ga4_event_param('currency') }} as currency,
    cast({{ ga4_event_param('value', 'double') }} as decimal(12, 2)) as event_value,
    cast(ecommerce.purchase_revenue as decimal(12, 2)) as purchase_revenue,
    cast(ecommerce.shipping_value as decimal(12, 2)) as shipping_value,
    cast(ecommerce.tax_value as decimal(12, 2)) as tax_value,
    ecommerce.total_item_quantity,
    ecommerce.unique_items,

    -- device / geo / consent
    device.category as device_category,
    device.operating_system,
    device.operating_system_version,
    device.web_info.browser as browser,
    device.mobile_brand_name,
    device.language,
    geo.country as geo_country,
    geo.region as geo_region,
    geo.city as geo_city,
    geo.metro as geo_metro,
    privacy_info.ads_storage as ads_storage_consent,
    is_active_user
from events
