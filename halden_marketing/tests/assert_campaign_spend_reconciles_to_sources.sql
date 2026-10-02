-- Fails when total spend per platform in fct_campaign_performance_daily differs from the raw platform
-- reports by more than one cent. Catches rows lost or duplicated by joins, grain changes or
-- incremental runs.
with fact as (
    select platform, sum(spend) as fact_spend
    from {{ ref('fct_campaign_performance_daily') }}
    group by platform
),

sources as (
    select 'Meta' as platform, sum(spend) as source_spend
    from {{ source('facebook_marketing', 'ads_insights') }}
    union all
    select 'Google Ads', sum(metrics_cost_micros) / 1000000.0
    from {{ source('google_ads', 'campaign') }}
    union all
    select 'TikTok', sum(cast((metrics->>'spend') as double))
    from {{ source('tiktok_marketing', 'campaigns_reports_daily') }}
    union all
    select 'LinkedIn', sum(costInUsd)
    from {{ source('linkedin_ads', 'ad_campaign_analytics') }}
)

select
    sources.platform,
    sources.source_spend,
    fact.fact_spend
from sources
full outer join fact
    on sources.platform = fact.platform
where abs(coalesce(sources.source_spend, 0) - coalesce(fact.fact_spend, 0)) > 0.01
