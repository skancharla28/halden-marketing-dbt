-- One row per campaign across all ad platforms. Only columns populated on every platform are
-- included; platform-specific detail stays in each stg_<platform>__campaigns model.
-- campaign_key is unique across platforms (ids are only unique within a platform). platform values
-- match channel_mapping.platform. LinkedIn rows are LinkedIn *campaigns*, not campaign groups,
-- because campaign_id equals utm_id on every platform.
{%- set platform_models = {
    'Meta': 'stg_facebook_marketing__campaigns',
    'Google Ads': 'stg_google_ads__campaigns',
    'TikTok': 'stg_tiktok_marketing__campaigns',
    'LinkedIn': 'stg_linkedin_ads__campaigns',
} %}

with unioned as (
    {%- for platform, model in platform_models.items() %}
    select
        '{{ platform }}' as platform,
        cast(campaign_id as varchar) as campaign_id,
        campaign_name,
        cast(account_id as varchar) as account_id,
        campaign_status as platform_campaign_status
    from {{ ref(model) }}
    {%- if not loop.last %}
    union all
    {%- endif %}
    {%- endfor %}
)

select
    {{ dbt_utils.generate_surrogate_key(['platform', 'campaign_id']) }} as campaign_key,
    platform,
    campaign_id,
    campaign_name,
    account_id,
    case
        when upper(platform_campaign_status) in ('ACTIVE', 'ENABLED', 'ENABLE') then 'active'
        when upper(platform_campaign_status) in ('PAUSED', 'DISABLE') then 'paused'
        when upper(platform_campaign_status) in ('REMOVED', 'DELETED', 'ARCHIVED') then 'removed'
        else 'other'
    end as campaign_status,
    platform_campaign_status
from unioned
