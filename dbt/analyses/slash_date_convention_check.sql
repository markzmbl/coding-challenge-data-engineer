-- Are the slash dates (99/99/9999) month-first, as staging assumes (Task 1, section 6.2)? Checked against the
-- time from lead to contract: every contract with a lead is dated both ways, month-first and day-first.
-- The right reading has no contract signed before its lead.
--
-- Run: dbt show --select slash_date_convention_check

{%- set day_first = {} %}
{%- do day_first.update(var("date_formats_by_shape")) %}
{%- do day_first.update({"99/99/9999": "%d/%m/%Y"}) %}

with leads as (
    -- the copies of a duplicated lead have the same date (Task 1, section 8)
    select distinct
        cast(trim(lead_id) as integer) as lead_id,
        created_at
    from {{ source('raw', 'leads') }}
),

contracts as (
    select distinct
        cast(nullif(trim(lead_id), '') as integer) as lead_id,
        signed_date
    from {{ source('raw', 'conversions') }}
),

pairs as (
    select
        leads.created_at,
        contracts.signed_date
    from contracts
    inner join leads
        on contracts.lead_id = leads.lead_id
),

readings as (
    select
        'month-first (staging)' as slash_dates_read,
        {{ parse_date_by_shape('created_at') }} as lead_date,
        {{ parse_date_by_shape('signed_date') }} as signed_date
    from pairs

    union all

    select
        'day-first' as slash_dates_read,
        {{ parse_date_by_shape('created_at', day_first) }} as lead_date,
        {{ parse_date_by_shape('signed_date', day_first) }} as signed_date
    from pairs
)

select
    slash_dates_read,
    count(*) as contracts,
    count(*) filter (where lead_date is null or signed_date is null) as not_a_valid_date,
    count(*) filter (where signed_date < lead_date) as signed_before_lead,
    min(datediff('day', lead_date, signed_date)) as min_days_to_sign,
    max(datediff('day', lead_date, signed_date)) as max_days_to_sign
from readings
group by slash_dates_read
order by slash_dates_read desc
