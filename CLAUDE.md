# halden-marketing-dbt

dbt project for Halden's marketing analytics: Shopify sales joined to paid media (Facebook, Google Ads,
TikTok, LinkedIn) and GA4 for ROAS, attribution and MMM. Runs on DuckDB / MotherDuck.

## Goals

This is a learning project, built with realistic marketing data. Its aims:

1. **Learn dbt by building a complete project**: use every major dbt feature where it genuinely fits
   (see the roadmap below), not just models and tests.
2. **Understand paid media data**: how each ad platform structures campaigns, spend and conversions,
   and how they reconcile with Shopify and GA4.
3. **Follow best practice for a paid media measurement framework**: layered models, a consistent
   cross-channel spend schema, attribution, and a standard KPI set.
4. **Make the final marts AI-ready** so Claude or another LLM can answer questions directly on MotherDuck.
5. **Use Claude Code to speed up the work.**

When doing work here, prefer approaches that teach a dbt concept. When you introduce a feature for the
first time, briefly explain what it is and why it fits. Tick items off the roadmap as they land.

## Roadmap

### dbt features

- [x] Sources with column docs (all 7 raw schemas)
- [x] Staging and intermediate models; custom schema macro; reusable macro (`extract_url_param`)
- [x] Generic tests (unique, not_null, relationships, accepted_values)
- [x] Seeds (3/3: `channel_mapping`, `discount_code_types`, `campaign_attributes`). More ideas:
      KPI targets, objective mapping, country/region
- [x] Packages: `dbt_utils` 1.4.1 (first use: `unique_combination_of_columns` on `channel_mapping`;
      next: `generate_surrogate_key`, `union_relations`, `date_spine`). Maybe `dbt_expectations` later
- [ ] Incremental models: daily ad insights and GA4 events (`merge` / `delete+insert`, `is_incremental()`)
- [x] Snapshots: `snap_facebook_marketing__campaigns` (timestamp strategy, `hard_deletes: new_record`),
      practised in `sandbox/snapshot_practice/`. Covered: strategies, deletes, missed edits, the
      first run having to come before changes, SCD2 dim design (`dim_campaigns` current +
      `dim_campaigns_history`, range joins, one version per day), CDC/audit logs when every change
      matters, and per-snapshot schedules via tags + orchestrator. Still to add: TikTok / LinkedIn
      campaigns, Google (`check` strategy), product variants.
- [ ] Vars: first use is `facebook_marketing_schema`, which points the Meta source at a sandbox copy
- [ ] Singular tests and custom generic tests (e.g. spend reconciles to platform totals).
      First singular test: `tests/assert_all_utm_pairs_mapped.sql`
- [ ] Unit tests (dbt 1.8+) for tricky logic such as UTM parsing and attribution
- [ ] Model contracts and versions on the marts
- [ ] Source freshness on `_airbyte_extracted_at`
- [ ] Analyses: ad-hoc SQL (e.g. attribution model comparison) kept in `analyses/`
- [ ] Hooks / operations: `on-run-end`, `run-operation` macros
- [ ] Exposures: dashboards and the LLM interface as downstream consumers
- [ ] Python models (dbt-duckdb runs them locally in the dbt process, using the `.venv` packages):
      for light ML / pandas work such as adstock and saturation features, scoring with a saved
      model, and pacing forecasts. Not for MMM training (see below). Fusion may not support them;
      use dbt-core.
- [ ] Semantic layer / MetricFlow: semantic models and metrics for the KPIs
- [ ] Docs site (`dbt docs generate`), tags, selectors, `persist_docs`

### Paid media framework

- Staging for every ad platform → `int_ad_spend__unioned`: one cross-channel schema
  (date, channel, platform, campaign, ad group, ad, spend, impressions, clicks, platform conversions/revenue).
- Channel classification of Shopify orders and GA4 sessions via a seed-driven mapping.
- Attribution: platform-reported, Shopify last-click / first-click (UTMs, click ids, customer journeys),
  GA4 sessions.
- Marts (`marts/`): `fct_ad_performance_daily`, `fct_orders`, `fct_order_lines`, `fct_sessions`,
  `fct_attribution`, `dim_campaigns`, `dim_products`, `dim_customers`, `dim_date`, plus a daily
  channel-level table ready for MMM.

### Campaigns and marketing initiatives (two-level design)

Business initiatives (BFCM 2025, Summer Sale 2026, Spring Launch 2026) run as separate campaigns on
each platform. Model both levels; don't collapse platform campaigns:

```
dim_marketing_initiatives   one row per initiative (from manual.marketing_calendar) + "Always-on" buckets
        ▲ initiative_id
dim_campaigns               one row per platform campaign, all platforms (conformed dim)
        ▲ campaign_key
fct_ad_performance_daily    spend / impressions / clicks per campaign per day
```

- **`dim_campaigns`**: one staging model per platform with standardized columns, then
  `int_ad_campaigns__unioned` with a surrogate key on (platform, campaign_id) — **built**. LinkedIn
  level decision: a LinkedIn *campaign* is treated as the campaign (not the campaign group),
  because `utm_id` equals the campaign id on every platform, including LinkedIn, so attribution
  uses one join. LinkedIn campaign groups behave like initiatives. (Fivetran's ad_reporting
  package maps it the other way, by structure.) Next: map objectives to a shared vocabulary
  (seed), add `initiative_id` and a campaign role (prospecting / retargeting / brand search…).
- **`dim_marketing_initiatives`**: built from the marketing calendar's promotion and launch entries
  (name, dates, discount_pct, discount_code). Evergreen campaigns (`Search | Brand | Exact`,
  `RT | Cart Abandon 7d`, `PROS | ASC | Evergreen`…) map to "Always-on" buckets, so all spend rolls up.
- **Campaign → initiative mapping**: a mapping seed (campaign → initiative), with a test that fails
  on unmapped campaigns. Names don't match the calendar exactly (e.g. "Spring Collection Launch 2026"
  vs "PROS | Spring Launch 2026"), so don't fuzzy-match or assign by overlapping dates. The long-term
  fix is a naming convention with an initiative code in campaign names and `utm_campaign`.
- **Initiative ROI**: spend from mapped campaigns + revenue from orders using the initiative's
  discount code or attributed to its campaigns + discount given (`int_shopify__discount_codes_enriched`).
- The calendar's other entries (events, media_change pause/budget tests, media_flight) are MMM
  controls and natural experiments, not initiatives.

### MMM (media mix modelling)

Training happens outside dbt; dbt owns the data before and after it:
1. **Input (dbt, SQL):** `fct_mmm_input_daily`: one row per day, with spend, impressions and clicks
   per channel, revenue as the outcome, and controls (promotions from `discount_code_types`,
   holidays, seasonality). Heavily tested; data quality here matters more than the model.
2. **Training (outside dbt):** a notebook or script using PyMC-Marketing or Meridian (Bayesian,
   iterative, minutes to hours per fit) reads the input table and writes results (channel
   contributions, ROI, response curves) back to MotherDuck in `mkt_raw`.
3. **Outputs (dbt):** declare the results as a source and build marts such as
   `fct_mmm_channel_contribution`, so ROI and incrementality are queryable alongside other KPIs.

### KPIs

Spend, impressions, reach, clicks, CTR, CPM, CPC, conversions, CVR, CPA / CAC, revenue, net revenue (after
refunds), ROAS (platform vs Shopify-attributed), AOV, units per order, refund / return rate,
new-customer vs returning revenue, LTV, payback, MER / blended ROAS, frequency, and spend pacing vs targets.

### AI-ready marts

The final marts are the interface for conversational analytics, so:
- Every mart and column has a plain-English description; `persist_docs` writes them to MotherDuck comments.
- Marts are wide, denormalized and clearly named (`spend_usd`, not `amt`), with an explicit grain stated
  in the description.
- KPI definitions live once, in the semantic layer or a documented mart, so an LLM never re-derives them.
- Include a glossary or metric-definitions table, and example questions, for LLM context.

## Project structure

```
halden-marketing-dbt/
├── .venv/                      # Python venv with dbt-core + dbt-duckdb (see requirements.txt)
├── requirements.txt            # pinned deps; duckdb must stay <= MotherDuck's supported version
├── sandbox/                    # hand-run MotherDuck SQL for practice exercises (not part of dbt)
│   └── snapshot_practice/      # 01_setup → snapshot → 02 → snapshot → 03 → snapshot → 04_inspect → 99_cleanup
└── halden_marketing/           # the dbt project — run dbt from here
    ├── dbt_project.yml
    ├── profiles.yml            # committed; no secrets (token comes from env)
    ├── packages.yml            # dbt packages (dbt_utils); `dbt deps` installs to dbt_packages/ (gitignored)
    ├── package-lock.yml        # exact resolved versions; committed
    ├── seeds/                  # hand-maintained CSVs (+ _seeds.yml), loaded to the `seeds` schema
    ├── tests/                  # singular tests
    ├── snapshots/              # SCD2 snapshots (YAML), written to the `snapshots` schema
    ├── macros/
    │   ├── generate_schema_name.sql   # custom schema used as-is (`intermediate`, not `staging_intermediate`)
    │   └── extract_url_param.sql      # URL-decoded query-string param from a URL/path
    └── models/
        ├── staging/<source>/          # one folder per source system
        │   ├── _<source>__sources.yml # source + column docs for raw tables
        │   ├── _<source>__models.yml  # model docs + tests
        │   └── stg_<source>__<entity>.sql
        └── intermediate/<source>/
            ├── _int_<source>__models.yml
            └── int_<source>__<entity>_<verb>.sql
```

## Running dbt

Use dbt-core from the venv, run from `halden_marketing/`. `MOTHERDUCK_TOKEN` is a Windows *user* env var
that tool shells don't inherit, so load it first:

```powershell
cd halden_marketing
$env:MOTHERDUCK_TOKEN = [Environment]::GetEnvironmentVariable('MOTHERDUCK_TOKEN','User')
..\.venv\Scripts\dbt.exe build --select <model>+ --profiles-dir .
```

- After cloning or changing `packages.yml`, run `dbt deps` first.
- Python `duckdb` must not exceed MotherDuck's supported version (1.5.5 as of 2026-10-01); newer breaks `md:`.
- The VS Code dbt extension runs dbt Fusion, not dbt-core. Fusion only sees the profile's main database,
  which is why `profiles.yml` explicitly attaches `md:mkt_raw` (without `read_only` — dbt-core errors on
  the mode mismatch).
- The editor's SQL linter is T-SQL and flags Jinja and DuckDB syntax as errors; ignore those, trust `dbt build`.
- dbt-duckdb snapshots store `dbt_is_deleted` as text ('True' / 'False'), not boolean.

## MotherDuck architecture

Two databases: Airbyte loads raw data into `mkt_raw`; dbt reads from it and writes only to `mkt_analytics`.

| Database | Schema | Contents |
|---|---|---|
| `mkt_raw` | `shopify` | customers, orders, order_refunds, transactions, products, product_variants, customer_journey_summary, discount_codes, price_rules, shop |
| | `facebook_marketing` | ad_account, campaigns, ad_sets, ads, ad_creatives, ads_insights, ads_insights_platform_and_device |
| | `google_ads` | customer, campaign, campaign_budget, ad_group, ad_group_ad, ad_group_ad_legacy, keyword_view |
| | `tiktok_marketing` | advertisers, campaigns, ad_groups, ads, campaigns_reports_daily, ads_reports_daily |
| | `linkedin_ads` | accounts, campaign_groups, campaigns, creatives, ad_campaign_analytics, ad_creative_analytics |
| | `ga4` | events (GA4 BigQuery export schema) |
| | `manual` | marketing_calendar |
| | `docs` | table_definitions, column_definitions — grain, keys, joins and gotchas for every raw table |
| `mkt_analytics` | `staging` | `stg_*` models (views) |
| | `intermediate` | `int_*` models (views) |
| | `marts_marketing` | marketing marts (tables), e.g. `dim_campaigns` |
| | `marts_attribution`, `marts_mmm` | planned (empty schemas already exist) |
| | `seeds` | seed tables loaded by `dbt seed` |
| | `snapshots` | SCD2 snapshot tables; built up run by run and cannot be rebuilt, so never drop casually |
| `mkt_raw` | `sandbox_*` | practice copies of raw tables (e.g. `sandbox_facebook_marketing`); never edit the real raw schemas |

All raw tables carry Airbyte metadata columns (`_airbyte_raw_id`, `_airbyte_extracted_at`, `_airbyte_meta`,
`_airbyte_generation_id`). Staging models keep only `_airbyte_extracted_at`. Many fields are JSON
(line items, refund lines, addresses, consents) and money is often stored as strings.

Before modelling a new raw table, check `mkt_raw.docs.table_definitions` / `column_definitions` and the
`_<source>__sources.yml` descriptions, then verify assumptions (keys, joins, uniqueness) with queries.

## Models so far

Sources are declared for all seven raw schemas. Models exist for Shopify and for campaigns on
all four ad platforms; GA4 and ad performance metrics are not modelled yet.

### Staging — Shopify (`models/staging/shopify/`)

| Model | Grain | Notes |
|---|---|---|
| `stg_shopify__orders` | order | Money cast to decimal; `is_test`, `is_wholesale`, `is_cancelled` flags from tags/status; UTMs and click ids (gclid, fbclid, ttclid…) parsed from `landing_site` |
| `stg_shopify__order_lines` | order line | Unnested from `orders.line_items`; discount from `discount_allocations` (line `total_discount` is always 0) |
| `stg_shopify__order_refunds` | refund | Amounts summed from `refund_line_items` (`orders.current_subtotal_price` is unreliable with gift cards); `return_reason` from note |
| `stg_shopify__order_refund_lines` | refunded order line | Unnested from `refund_line_items`; `order_line_id` → order lines |
| `stg_shopify__customer_journeys` | order | Shopify first/last visit summary for first- vs last-touch attribution; ~12% untracked |
| `stg_shopify__customers` | customer | Scalar fields only |
| `stg_shopify__customer_addresses` | customer address | Unnested from `addresses` |
| `stg_shopify__customer_default_addresses` | customer | From `default_address` JSON |
| `stg_shopify__customer_email_consents` | customer | From `email_marketing_consent` JSON |
| `stg_shopify__products` | product | `gender` and `season` parsed from tags (`<type>, <gender>, <season>`); `is_gift_card` |
| `stg_shopify__discount_codes` | discount code | Code text + Shopify `usage_count`; discount details live on the price rule |
| `stg_shopify__price_rules` | price rule | `discount_value` flipped to positive (source is a negative string); `ends_at` always null |
| `stg_shopify__product_variants` | variant | `option1`/`option2` renamed to `color`/`size`; SKUs are **not** unique — join on `variant_id` |

Key joins: `order_lines.variant_id → product_variants.variant_id`, `product_variants.product_id →
products.product_id`, `order_refund_lines.order_line_id → order_lines.order_line_id`.

### Seeds

| Seed | Grain | Notes |
|---|---|---|
| `channel_mapping` | utm_source + utm_medium | → `channel`, `platform`, `is_paid`. Keys are the lowercased raw values (incl. variants like `fb`, `paid social`). No-UTM traffic isn't listed (= Direct / Unattributed). `assert_all_utm_pairs_mapped` fails when a new pair appears |
| `campaign_attributes` | platform + campaign_id | → `channel`, `campaign_tactic`, `initiative_name` (exact marketing-calendar name or 'Always-on'). Inferred from campaign names + calendar. `dim_campaigns` not_null tests fail when a new campaign is unmapped |
| `discount_code_types` | discount code | → `code_type` (welcome / seasonal_promo / creator / internal). Not in Shopify; inferred from order history. The relationships test on `stg_shopify__discount_codes` fails when a new code appears |

### Staging — ad platforms (campaigns)

Each platform's campaign model uses the same names for shared columns (`campaign_id`,
`campaign_name`, `account_id`, `campaign_status`, `created_at`…). `campaign_id` equals `utm_id` on
every platform.

| Model | Grain | Notes |
|---|---|---|
| `stg_facebook_marketing__campaigns` | campaign | `daily_budget` converted from cents; null when budget is on ad sets |
| `stg_google_ads__campaigns` | campaign | Source `campaign` is a daily report (campaign × date × network × device); keeps the latest row. No objective (use `advertising_channel_type`), no created date; end date `2037-12-30` → null |
| `stg_tiktok_marketing__campaigns` | campaign | No start date |
| `stg_linkedin_ads__campaigns` | campaign | Account/group ids parsed from URNs; `runSchedule` epoch ms → timestamps; budget from JSON |
| `stg_linkedin_ads__campaign_groups` | campaign group | Initiative-like folders (Corporate Gifting, Team & Workwear) |

### Intermediate — ad platforms (`models/intermediate/ad_platforms/`)

| Model | Grain | Notes |
|---|---|---|
| `int_ad_campaigns__unioned` | campaign (all platforms) | Jinja loop over a platform → model dict; `campaign_key` = `dbt_utils.generate_surrogate_key(['platform','campaign_id'])`; only columns every platform fills (id, name, account, status); `campaign_status` standardized to active / paused / removed; `platform` values match `channel_mapping.platform` |

### Intermediate — Shopify (`models/intermediate/shopify/`)

| Model | Grain | Notes |
|---|---|---|
| `int_shopify__orders_enriched` | order | Line counts, units ordered, refund summary (units, lines, products, amounts, reasons) attributed to the order date; `net_sales`, refund flags, and `is_marketing_eligible` (not test / cancelled / wholesale) — filter on it for ROAS and MMM |
| `int_shopify__discount_codes_enriched` | discount code | Code + price rule + `code_type` seed + order usage (order count, discount given, net sales, first/last used). Discount codes ↔ price rules are 1:1 today |
| `int_shopify__customers_enriched` | customer | Customer + default address + email consent; `address_count` |

### Marts — marketing (`models/marts/marketing/`, schema `marts_marketing`, tables)

| Model | Grain | Notes |
|---|---|---|
| `dim_campaigns` | campaign (all platforms) | Current attributes only (no history, by choice). `int_ad_campaigns__unioned` + `campaign_attributes` seed: channel, tactic, initiative, `is_always_on`. Join facts on `campaign_key` |

## Conventions

- Naming: `stg_<source>__<entity>` (plural entity), `int_<source>__<entity>_<verb>`; ids renamed to
  `<entity>_id`; booleans as `is_*` / `has_*`; money as `decimal(12, 2)`.
- Staging: rename, cast, unnest JSON to one model per grain — no joins across entities. Start each model
  with a comment stating its grain and any source quirks.
- DuckDB `->>` binds looser than comparison operators, so parenthesize JSON extracts: `(col->>'key')`.
- Every model has a unique + not_null test on its primary key and `relationships` tests on foreign keys
  (dbt 1.10+ syntax with `arguments:`). Document non-obvious columns in the `_models.yml`.
- Staging and intermediate materialize as views; marts as tables (set in `dbt_project.yml`).
- MotherDuck MCP queries can miss newly created tables (stale catalog); use fully qualified
  `database.schema.table` names.
- Marts are the AI-facing layer: every column gets a plain-English description.
