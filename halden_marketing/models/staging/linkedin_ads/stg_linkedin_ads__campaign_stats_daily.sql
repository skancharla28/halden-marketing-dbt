-- One row per LinkedIn campaign per day, from ad_campaign_analytics. LinkedIn only spends during
-- flights (see the marketing calendar), so days outside flights have no rows. The campaign id is
-- parsed from the sponsoredCampaign URN.
select
    cast(regexp_extract(sponsoredCampaign, '(\d+)$', 1) as bigint) as campaign_id,
    start_date as date_day,

    impressions,
    clicks,
    landingPageClicks as landing_page_clicks,
    cast(costInUsd as decimal(14, 2)) as spend,
    videoViews as video_views,

    externalWebsiteConversions as platform_conversions,
    cast(conversionValueInLocalCurrency as decimal(14, 2)) as platform_conversion_value,

    _airbyte_extracted_at
from {{ source('linkedin_ads', 'ad_campaign_analytics') }}
