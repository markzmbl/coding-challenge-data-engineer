-- A customer is an e-mail address, so the same name with two e-mail domains (e.g. paul.aigner@gmail.com and
-- paul.aigner@hotmail.com) counts as two customers (Task 1, issue 4). They could be one person, but the data
-- cannot prove it. This test watches how many customers the definition may split.

{{ config(severity="warn") }}  -- today: 5 names

select
    split_part(customer_email, '@', 1) as name,
    count(*) as email_addresses
from {{ ref('agg_customers') }}
group by split_part(customer_email, '@', 1)
having count(*) > 1
