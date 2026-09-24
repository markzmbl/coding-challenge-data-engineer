-- The aggregated Task 3 models must add up:
-- - the journeys to the lead table: every lead is a touchpoint of exactly one journey, and every attributed
--   conversion ends exactly one journey;
-- - the monthly KPIs to the lead table: last- and first-touch attribution both count every attributed conversion
--   and its active premium once;
-- - the customer view to the lead table and to all contracts (it also counts the contracts that cannot be
--   attributed to a lead).
-- Returns a row, and so fails, if any total differs.

with expected as (
    select
        (select count(*) from {{ ref('mart_lead_conversions') }}) as leads,
        (select count(distinct conversion_id) from {{ ref('mart_lead_conversions') }}) as attributed_conversions,
        (
            select coalesce(sum(premium), 0)
            from {{ ref('mart_lead_conversions') }}
            where is_last_touch and contract_status = 'active'
        ) as attributed_active_premium,
        (select count(*) from {{ ref('stg_conversions') }}) as contracts
),

actual as (
    select
        (select sum(touchpoints) from {{ ref('agg_customer_journeys') }}) as journey_touchpoints,
        (select count_if(is_converted) from {{ ref('agg_customer_journeys') }}) as converted_journeys,
        (select sum(leads) from {{ ref('agg_lead_conversions_monthly') }}) as monthly_leads,
        (select sum(conversions) from {{ ref('agg_lead_conversions_monthly') }}) as monthly_conversions,
        (select sum(first_touch_conversions) from {{ ref('agg_lead_conversions_monthly') }})
            as monthly_first_touch_conversions,
        (select sum(active_premium) from {{ ref('agg_lead_conversions_monthly') }}) as monthly_active_premium,
        (select sum(first_touch_active_premium) from {{ ref('agg_lead_conversions_monthly') }})
            as monthly_first_touch_active_premium,
        (select sum(leads) from {{ ref('agg_customers') }}) as customer_leads,
        (select sum(conversions) from {{ ref('agg_customers') }}) as customer_conversions
)

select *
from expected
cross join actual
where journey_touchpoints != leads
    or converted_journeys != attributed_conversions
    or monthly_leads != leads
    or monthly_conversions != attributed_conversions
    or monthly_first_touch_conversions != attributed_conversions
    or monthly_active_premium != attributed_active_premium
    or monthly_first_touch_active_premium != attributed_active_premium
    or customer_leads != leads
    or customer_conversions != contracts
