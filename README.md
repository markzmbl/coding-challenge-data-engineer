# Leads & Conversions – Data Engineer Coding Challenge

My solution to the durchblicker take-home assignment ([EN](docs/assignment/Coding_Challenge_EN.pdf),
[DE](docs/assignment/Coding_Challenge_DE.pdf)):
- A dbt pipeline on DuckDB turns the two CSV exports into tested tables (raw → staging → marts).
- Notebooks show the profiling, and how a business team works with the tables.

| Task | Deliverable |
|---|---|
| 1. Data profiling & data quality | The issues [below](#task-1--data-profiling--data-quality), their evidence in the [notebook](notebooks/task1_data_profiling.ipynb) |
| 2. Lead-to-conversion model | [`mart_lead_conversions`](dbt/models/marts/mart_lead_conversions.sql), [sample queries](notebooks/task2_lead_conversions.ipynb) |
| 3. KPI & customer aggregation | [`agg_lead_conversions_monthly`](dbt/models/marts/agg_lead_conversions_monthly.sql), [`agg_customers`](dbt/models/marts/agg_customers.sql), [`agg_customer_journeys`](dbt/models/marts/agg_customer_journeys.sql), [what they show](notebooks/task3_kpis_and_customers.ipynb) |
| Assumptions and open questions | [Below](#assumptions-and-open-questions) |

Every model and column is documented in the dbt yml files, including its type and when it can be NULL
([staging](dbt/models/staging/_staging.yml), [marts](dbt/models/marts/_marts.yml)).

## Task 1 – Data profiling & data quality

**Profile.** `leads.csv` has 123 rows for 119 leads, created from 2024-01-05 to 2024-10-31. `conversions.csv` has
51 rows for 50 contracts, signed from 2024-01-16 to 2024-11-29, with premiums from −217.61 to 1,359.55 EUR. The
missing values, duplicates and suspicious values are the 13 issues below. The
[notebook](notebooks/task1_data_profiling.ipynb) assumes no formats and finds them from the data; the number in brackets
is its section with the evidence.

**Criticality** weighs how far an issue reaches into the required KPIs, and who can settle it: the pipeline, by
converting correctly, or only the team that owns the source.
- **High:** changes the KPIs for many records, and the pipeline cannot settle it.
- **Medium:** would change the KPIs if converted naively, but a rule settles it; or changes them for a few records
  and needs the team.
- **Low:** a few records, and no required KPI changes.

**For the team.** Only the source can settle these issues:

| # | Issue | Criticality | Handling until then | Question for the team |
|---|---|---|---|---|
| 1 | 9 of 50 contracts name no valid lead: 3 have no `lead_id`, 6 have ids from another range (9.1) | High | Kept, but not attributed: without the lead they have no vertical and no channel (Task 2). | Where do the ids `9xxxx` come from? Can every contract carry a valid `lead_id`, or at least its vertical? |
| 2 | 2 premiums are missing, 1 of them on an active contract (7) | Medium | Kept as NULL, never 0: the customer's total is then unknown, not silently too low. | Can the source deliver them? |
| 3 | 4 lead ids occur twice with conflicting content: `region` differs in all 4, `source` in 2 (8) | Medium | Merged to one row (Task 2). | Is there a fan-out join upstream? Which system is the source of truth for the channel? |
| 4 | 5 names appear with two e-mail domains (8) | Medium | Counted as two customers each: the data cannot prove they are one person. | Is there a customer id in the CRM? |
| 5 | How the source links a lead to a contract is unknown: no lead a contract names is older than 40 days, and in 2 of 40 contracts it is not the last lead before signing (9.3, 9.4) | Low | Conversions are attributed by rule (Task 2). | How is the `lead_id` of a contract chosen, and is 40 days a limit of the system? |
| 6 | 2 negative premiums, both on cancelled contracts (7) | Low | Kept: no active premium is affected. | A refund, a reversal booking, or an error? |

**Settled by converting correctly.** One rule each, guarded by a test:

| # | Issue | Criticality | Rule |
|---|---|---|---|
| 7 | Dates in 3 formats, 16 of them ambiguous slash dates. The default parse fails on 97 of 123 dates; `format="mixed"` puts 14 on the wrong day without an error (6) | Medium | One format per shape; an unknown shape fails. Slash dates are month-first: all 17 unambiguous ones are, and read day-first, 2 contracts would be signed before their lead ([check](dbt/analyses/slash_date_convention_check.sql)). |
| 8 | 13 of 49 premiums use a decimal comma; a naive cast makes them NULL (7) | Medium | Replace the comma before casting. |
| 9 | E-mails with spaces and capitals: 123 spellings for 88 addresses (5) | Medium | Trim and lower-case: the e-mail is the customer key. |
| 10 | Status `ACTIVE` and `aktiv` next to `active`, on 2 of 27 active contracts (5) | Medium | Lower-case and map to the documented values. |
| 11 | The leads end on 2024-10-31, the contracts on 2024-11-29: the latest leads can still convert (6.4) | Medium | Rates by lead month, with `is_complete` (Task 3). |
| 12 | 1 contract row is exported twice (8) | Low | Drop exact duplicates. |
| 13 | 3 leads have no vertical, 5 no region (4) | Low | `unknown`, so that totals still add up. |

## Task 2 – Lead-to-conversion model

[`mart_lead_conversions`](dbt/models/marts/mart_lead_conversions.sql) has one row per lead (119): whether it
converted, and if so the contract with its status, premium and the days to signing.

**How a lead is linked to a conversion.** A contract names one lead (`lead_id`), which gives it its vertical. Its
touchpoints are that lead and every other lead of the same customer (e-mail) and vertical from the 40 days before
signing; a lead belongs to one conversion at most. The window is read from the data, not guessed
([notebook](notebooks/task1_data_profiling.ipynb), 9.3). `is_first_touch` marks the touchpoint that opened
the customer journey, `is_last_touch` the one that closed it. 43 leads are touchpoints of 41 conversions.

| Case | Decision | Why |
|---|---|---|
| Conversions without a matching lead (issue 1) | Not in this table. Counted in the customer view (Task 3). | The e-mail alone finds a lead in the window for only 3 of the 9, and one of those belongs to another conversion ([analysis](dbt/analyses/orphan_email_candidates.sql)). A guess would put wrong numbers into every breakdown. |
| Leads that never converted (76) | Kept, with `is_converted = false`. | They are the denominator of every conversion rate, and the list for a follow-up. |
| Lead ids that occur twice (issue 3) | One row per lead: values the copies agree on are kept, contradicting ones become `unknown`. | No copy is picked at random. |
| Conversions with several touchpoints (2 of 41) | Every touchpoint carries the conversion, marked as first or last touch. | Their touchpoints come from two channels, so the channel of the conversion depends on the attribution model. |

## Task 3 – KPI & customer-level aggregation

All three models are built on `mart_lead_conversions`, so every definition exists once:

| Model | One row per | Columns |
|---|---|---|
| [`agg_lead_conversions_monthly`](dbt/models/marts/agg_lead_conversions_monthly.sql) | vertical × source × lead month (68) | `leads`, `conversions`, `conversion_rate`, `active_premium`; the same by first-touch attribution; `is_complete` |
| [`agg_customers`](dbt/models/marts/agg_customers.sql) | customer (88) | `leads`, `conversions`, `total_active_premium`, `has_active_contract`; the acquisition channel, and whether, when and how the customer came back |
| [`agg_customer_journeys`](dbt/models/marts/agg_customer_journeys.sql) | customer journey (117) | path, touchpoints, first- and last-touch channel, conversion, time lag, `is_complete` |

**Definitions**

| Term | Definition |
|---|---|
| Conversion | A signed contract, whatever its status today (active, pending or cancelled). A later cancellation is churn, not a failed conversion. |
| Customer | A person, identified by the trimmed, lower-cased e-mail address. |
| Customer journey | The touchpoints (leads) of one customer in one vertical. The touchpoints of a conversion form one journey; other leads start a new journey after more than 40 days without a touchpoint. |
| Attribution | A conversion counts at its last touch, the lead that closed the journey. It is the default, because in 40 of 41 conversions it is the lead the contract names. First-touch attribution counts it at the lead that opened the journey. |
| Conversion rate | Conversions / leads (34.5 % overall). A conversion counts in the month of its lead, not of its signing, so a rate never exceeds 100 %: by signing month, November would have 4 conversions and no lead. To combine rows, add up leads and conversions, then divide. |
| Journey conversion rate | Converted journeys / complete journeys (36.9 %). |
| Complete | A lead month or journey whose leads are older than the attribution window at the data cutoff. October 2024 and 6 journeys are not complete yet. |
| Total active premium | The sum of the annual net premiums of a customer's active contracts. NULL, not 0, if one of them has no premium (issue 2). |

**Where the numbers differ, and why.** A [test](dbt/tests/assert_aggregates_add_up.sql) checks this on every run:

| | Leads | Contracts |
|---|---|---|
| Rows in the files | 123 | 51 |
| After cleaning (exact duplicate removed) | 123 | 50 |
| After merging duplicate lead ids | 119 | 50 |
| Attributed to a lead (monthly model, journey model) | 119 | 41 |
| Belonging to a customer (customer model) | 119 | 50 |

**What the models show.** The channels convert about equally often, but differ in what lasts: only 4 of google's
11 conversions are still active, so a google lead is worth 86 EUR of active premium and a newsletter lead 186 EUR.
The [notebook](notebooks/task3_kpis_and_customers.ipynb) tells the whole story, from touchpoint to lasting
customer.

## Assumptions and open questions

**Assumptions**
- Slash dates are month-first (issue 7).
- The e-mail address identifies a customer (issue 4).
- `premium` is the annual net premium in EUR, without thousands separators. `aktiv` means `active`.
- Both copies of a duplicated lead id describe the same lead (issue 3).
- Each delivery is a full export that replaces the previous one. The files carry no export date, so the latest
  signing date (2024-11-29) is the data cutoff.
- The attribution window of 40 days (issue 5) also separates customer journeys, and decides when a lead month
  or a journey is complete.

**Open questions.** The questions about the data are in the Task 1 table (issues 1–6). About the
definitions:
1. Should a `pending` contract count as a conversion? Here it does, because it is signed. Without it, the
   conversion rate would be 32.8 % instead of 34.5 %
   ([analysis](dbt/analyses/conversion_rate_without_pending.sql)).
2. Which attribution model should steer the marketing budget: last touch (the channel that closes
   journeys) or first touch (the one that opens them)? They differ for 2 of 41 conversions.

## Run it

Tested with Python 3.13 on Windows.

```bash
python -m venv .venv
.venv\Scripts\activate            # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

`dbt build` loads both CSVs, builds all models and runs all tests. The warnings it prints are the known Task 1
issues at their baseline.

```bash
cd dbt
dbt deps
dbt build
```

Then open the notebooks. Those of Tasks 2 and 3 read the DuckDB file that dbt writes. Each chart is stored
twice: interactive, and as a PNG that also shows on GitHub (the export needs a local Chrome).

```bash
python -m ipykernel install --user --name coding-challenge-de
jupyter lab
```

Lint the Python code and the notebooks with `ruff check .`.
