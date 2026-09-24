-- Should a pending contract count as a conversion (open question 1 in the README)? The mart counts it, because
-- it is signed. This shows what the conversion rate would be without the pending contracts. Each contract is
-- counted once, at its last touch.
--
-- Run: dbt show --select conversion_rate_without_pending

select
    count(*) as leads,
    count(*) filter (where is_last_touch) as conversions,
    round(100.0 * count(*) filter (where is_last_touch) / count(*), 1) as conversion_rate_pct,
    count(*) filter (where is_last_touch and contract_status in ('active', 'cancelled'))
        as conversions_without_pending,
    round(
        100.0 * count(*) filter (where is_last_touch and contract_status in ('active', 'cancelled')) / count(*),
        1
    ) as conversion_rate_without_pending_pct
from {{ ref('mart_lead_conversions') }}
