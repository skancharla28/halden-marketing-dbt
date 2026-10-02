-- One row per campaign per day across all ad platforms, with the same additive metrics.
-- Meta (ad level) and Google (network x device) are summed up to campaign x day.
-- clicks = clicks to the website: Meta inline link clicks and LinkedIn landing page clicks, because
-- their raw `clicks` also count likes, comments and profile clicks.
-- platform_conversions / _value are what each platform claims under its own attribution rules; they
-- overlap across platforms and are not comparable to Shopify revenue.
with meta as (
    select
        'Meta' as platform,
        campaign_id,
        date_day,
        sum(spend) as spend,
        sum(impressions) as impressions,
        sum(link_clicks) as clicks,
        sum(platform_conversions) as platform_conversions,
        sum(platform_conversion_value) as platform_conversion_value
    from {{ ref('stg_facebook_marketing__ad_stats_daily') }}
    group by all
),

google_ads as (
    select
        'Google Ads' as platform,
        campaign_id,
        date_day,
        sum(spend) as spend,
        sum(impressions) as impressions,
        sum(clicks) as clicks,
        sum(platform_conversions) as platform_conversions,
        sum(platform_conversion_value) as platform_conversion_value
    from {{ ref('stg_google_ads__campaign_stats_daily') }}
    group by all
),

tiktok as (
    select
        'TikTok' as platform,
        campaign_id,
        date_day,
        spend,
        impressions,
        clicks,
        platform_conversions,
        platform_conversion_value
    from {{ ref('stg_tiktok_marketing__campaign_stats_daily') }}
),

linkedin as (
    select
        'LinkedIn' as platform,
        campaign_id,
        date_day,
        spend,
        impressions,
        landing_page_clicks as clicks,
        platform_conversions,
        platform_conversion_value
    from {{ ref('stg_linkedin_ads__campaign_stats_daily') }}
),

unioned as (
    select * from meta
    union all
    select * from google_ads
    union all
    select * from tiktok
    union all
    select * from linkedin
)

select
    {{ dbt_utils.generate_surrogate_key(['platform', 'cast(campaign_id as varchar)']) }} as campaign_key,
    platform,
    cast(campaign_id as varchar) as campaign_id,
    date_day,
    spend,
    impressions,
    clicks,
    platform_conversions,
    platform_conversion_value
from unioned
