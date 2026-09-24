-- Two contracts of the same customer and vertical, signed within the attribution window of each other, are
-- either two contracts or one contract that the source delivers twice under a new id (Task 1, issue 5). The
-- one pair of today has two different premiums, so it counts as two contracts; this test watches for more.

{{ config(severity="warn") }}  -- today: 1 pair (5029 and 5012)

with contracts as (
    select
        conversion_id,
        email,
        vertical,
        signed_date
    from {{ ref('mart_lead_conversions') }}
    where is_last_touch
)

select
    contracts.email,
    contracts.vertical,
    contracts.conversion_id,
    next_contracts.conversion_id as next_conversion_id,
    datediff('day', contracts.signed_date, next_contracts.signed_date) as days_apart
from contracts
inner join contracts as next_contracts
    on contracts.email = next_contracts.email
    and contracts.vertical = next_contracts.vertical
    and next_contracts.signed_date
        between contracts.signed_date and contracts.signed_date + {{ var('attribution_window_days') }}
where (contracts.signed_date, contracts.conversion_id)
    < (next_contracts.signed_date, next_contracts.conversion_id)
