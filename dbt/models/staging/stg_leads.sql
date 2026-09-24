-- One row per row of leads.csv, cleaned and typed. Duplicate lead_ids are kept here;
-- how they are resolved is a modelling decision for the marts (notebook 01, section 7).

with raw_leads as (
    select * from {{ source('raw', 'leads') }}
)

select
    cast(trim(lead_id) as integer) as lead_id,
    lower(nullif(trim(email), '')) as email,
    nullif(trim(vertical), '') as vertical,
    nullif(trim(source), '') as source,
    {{ parse_date_by_shape('created_at') }} as created_at,
    nullif(trim(region), '') as region
from raw_leads
