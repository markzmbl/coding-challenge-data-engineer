-- Task 3: one row per customer. A customer is a person, identified by the e-mail address (trimmed and
-- lower-cased in staging); two different addresses count as two customers.

with lead_conversions as (
    select * from {{ ref('mart_lead_conversions') }}
),

-- All contracts, including the ones whose lead is unknown: a contract belongs to the person even when its
-- lead cannot be found. (mart_lead_conversions leaves them out, because it credits leads.)
contracts as (
    select * from {{ ref('stg_conversions') }}
),

leads_per_customer as (
    select
        email as customer_email,
        count(*) as leads
    from lead_conversions
    group by email
),

contracts_per_customer as (
    select
        email as customer_email,
        count(*) as conversions,
        count_if(status = 'active') as active_contracts,
        sum(premium) filter (where status = 'active') as active_premium
    from contracts
    group by email
)

select
    customer_email,
    coalesce(leads_per_customer.leads, 0) as leads,
    coalesce(contracts_per_customer.conversions, 0) as conversions,
    -- 0 without an active contract; NULL if an active contract has no premium in the source
    case
        when coalesce(contracts_per_customer.active_contracts, 0) = 0 then 0
        else contracts_per_customer.active_premium
    end as total_active_premium,
    coalesce(contracts_per_customer.active_contracts, 0) > 0 as has_active_contract
from leads_per_customer
full outer join contracts_per_customer
    using (customer_email)
