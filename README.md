# Leads & Conversions – Data Engineer Coding Challenge

My solution to the durchblicker take-home assignment ([EN](docs/assignment/Coding_Challenge_EN.pdf),
[DE](docs/assignment/Coding_Challenge_DE.pdf)):
- A dbt pipeline on DuckDB turns the two CSV exports into tested tables (raw → staging → marts).
- A notebook shows the profiling.

| Task | Deliverable |
|---|---|
| 1. Data profiling & data quality | The issues [below](#task-1--data-profiling--data-quality), their evidence in the [notebook](notebooks/task1_data_profiling.ipynb) |
| 2. Lead-to-conversion model | [`mart_lead_conversions`](dbt/models/marts/mart_lead_conversions.sql) |
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
| 11 | The leads end on 2024-10-31, the contracts on 2024-11-29: the latest leads can still convert (6.4) | Medium | Rates by lead month; a month counts as complete once its leads are older than the 40 days. |
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
| Conversions without a matching lead (issue 1) | Not in this table. | The e-mail alone finds a lead in the window for only 3 of the 9, and one of those belongs to another conversion ([analysis](dbt/analyses/orphan_email_candidates.sql)). A guess would put wrong numbers into every breakdown. |
| Leads that never converted (76) | Kept, with `is_converted = false`. | They are the denominator of every conversion rate, and the list for a follow-up. |
| Lead ids that occur twice (issue 3) | One row per lead: values the copies agree on are kept, contradicting ones become `unknown`. | No copy is picked at random. |
| Conversions with several touchpoints (2 of 41) | Every touchpoint carries the conversion, marked as first or last touch. | Their touchpoints come from two channels, so the channel of the conversion depends on the attribution model. |

## Assumptions and open questions

**Assumptions**
- Slash dates are month-first (issue 7).
- The e-mail address identifies a customer (issue 4).
- `premium` is the annual net premium in EUR, without thousands separators. `aktiv` means `active`.
- Both copies of a duplicated lead id describe the same lead (issue 3).
- Each delivery is a full export that replaces the previous one.
- A contract's touchpoints lie within the attribution window of 40 days (issue 5).

**Open questions.** The questions about the data are in the Task 1 table (issues 1–6). About the
definitions:
1. Should a `pending` contract count as a conversion? Here it does, because it is signed.
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

Then open the notebook. Each chart is stored twice: interactive, and as a PNG that also shows on GitHub
(the export needs a local Chrome).

```bash
python -m ipykernel install --user --name coding-challenge-de
jupyter lab
```

Lint the Python code and the notebooks with `ruff check .`.
