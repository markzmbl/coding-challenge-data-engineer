-- Task 3: one row per customer, with the customer's lifecycle. A customer is a person, identified by the e-mail
-- address (trimmed and lower-cased in staging); two different addresses count as two customers.

with lead_conversions as (
    select * from {{ ref('mart_lead_conversions') }}
),

-- All contracts, including the ones whose lead is unknown: a contract belongs to the person even when it cannot
-- be attributed to a lead. (mart_lead_conversions leaves them out, because it attributes contracts to leads.)
contracts as (
    select * from {{ ref('stg_conversions') }}
),

-- The vertical of a contract comes from its touchpoints; a contract without a valid lead_id has none.
contract_verticals as (
    select
        conversion_id,
        vertical
    from lead_conversions
    where is_last_touch
),

leads_per_customer as (
    select
        email as customer_email,
        count(*) as leads,
        first(source order by lead_date, lead_id) as acquisition_source
    from lead_conversions
    group by email
),

contracts_per_customer as (
    select
        email as customer_email,
        count(*) as conversions,
        count(*) filter (where status = 'active') as active_contracts,
        sum(premium) filter (where status = 'active') as active_premium
    from contracts
    group by email
),

first_contracts as (
    select
        contracts.email as customer_email,
        contracts.signed_date,
        coalesce(contract_verticals.vertical, 'unknown') as vertical
    from contracts
    left join contract_verticals
        on contracts.conversion_id = contract_verticals.conversion_id
    qualify row_number() over (
        partition by contracts.email
        order by contracts.signed_date, contracts.conversion_id
    ) = 1
),

-- Did the customer come back after the first conversion? The first lead after it opens a new journey: when,
-- through which channel, and in the same or a new vertical.
returns as (
    select
        first_contracts.customer_email,
        datediff('day', first_contracts.signed_date, lead_conversions.lead_date) as days_to_return,
        lead_conversions.source as return_source,
        case
            when first_contracts.vertical = 'unknown' or lead_conversions.vertical = 'unknown' then 'unknown'
            when lead_conversions.vertical = first_contracts.vertical then 'same'
            else 'new'
        end as return_vertical
    from first_contracts
    inner join lead_conversions
        on first_contracts.customer_email = lead_conversions.email
        and lead_conversions.lead_date > first_contracts.signed_date
    qualify row_number() over (
        partition by first_contracts.customer_email
        order by lead_conversions.lead_date, lead_conversions.lead_id
    ) = 1
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
    coalesce(contracts_per_customer.active_contracts, 0) > 0 as has_active_contract,
    leads_per_customer.acquisition_source,
    first_contracts.signed_date as first_contract_date,
    returns.customer_email is not null as returned_after_contract,
    returns.days_to_return,
    returns.return_source,
    returns.return_vertical
from leads_per_customer
full outer join contracts_per_customer
    using (customer_email)
left join first_contracts
    using (customer_email)
left join returns
    using (customer_email)
