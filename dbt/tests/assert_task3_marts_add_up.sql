-- The Task 3 marts must add up: the monthly KPIs to the lead table, the customer view to the lead table
-- and to all contracts (the customer view also counts the contracts whose lead is unknown).
-- Returns a row, and so fails, if any total differs.

with expected as (
    select
        (select count(*) from {{ ref('mart_lead_conversions') }}) as leads,
        (select count_if(is_converted) from {{ ref('mart_lead_conversions') }}) as converted_leads,
        (select count(*) from {{ ref('stg_conversions') }}) as contracts
),

actual as (
    select
        (select sum(leads) from {{ ref('mart_lead_conversions_monthly') }}) as monthly_leads,
        (select sum(conversions) from {{ ref('mart_lead_conversions_monthly') }}) as monthly_conversions,
        (select sum(leads) from {{ ref('mart_customers') }}) as customer_leads,
        (select sum(conversions) from {{ ref('mart_customers') }}) as customer_conversions
)

select *
from expected
cross join actual
where monthly_leads != leads
    or monthly_conversions != converted_leads
    or customer_leads != leads
    or customer_conversions != contracts
