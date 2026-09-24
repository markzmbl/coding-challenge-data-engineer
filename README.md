# Leads & Conversions – Data Engineer Coding Challenge

My solution to the durchblicker take-home assignment ([EN](docs/assignment/Coding_Challenge_EN.pdf),
[DE](docs/assignment/Coding_Challenge_DE.pdf)):
- A notebook shows the profiling.

| Task | Deliverable |
|---|---|
| 1. Data profiling & data quality | The issues [below](#task-1--data-profiling--data-quality), their evidence in the [notebook](notebooks/task1_data_profiling.ipynb) |
| Assumptions and open questions | [Below](#assumptions-and-open-questions) |

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
| 1 | 9 of 50 contracts name no valid lead: 3 have no `lead_id`, 6 have ids from another range (9.1) | High | Kept, but not attributed: without the lead they have no vertical and no channel. | Where do the ids `9xxxx` come from? Can every contract carry a valid `lead_id`, or at least its vertical? |
| 2 | 2 premiums are missing, 1 of them on an active contract (7) | Medium | Kept as NULL, never 0: the customer's total is then unknown, not silently too low. | Can the source deliver them? |
| 3 | 4 lead ids occur twice with conflicting content: `region` differs in all 4, `source` in 2 (8) | Medium | Merge to one row: keep what the copies agree on, mark contradictions as `unknown`. | Is there a fan-out join upstream? Which system is the source of truth for the channel? |
| 4 | 5 names appear with two e-mail domains (8) | Medium | Counted as two customers each: the data cannot prove they are one person. | Is there a customer id in the CRM? |
| 5 | How the source links a lead to a contract is unknown: no lead a contract names is older than 40 days, and in 2 of 40 contracts it is not the last lead before signing (9.3, 9.4) | Low | Attribute by rule: every lead of the customer and vertical from the 40 days before signing. | How is the `lead_id` of a contract chosen, and is 40 days a limit of the system? |
| 6 | 2 negative premiums, both on cancelled contracts (7) | Low | Kept: no active premium is affected. | A refund, a reversal booking, or an error? |

**Settled by converting correctly.** One rule each:

| # | Issue | Criticality | Rule |
|---|---|---|---|
| 7 | Dates in 3 formats, 16 of them ambiguous slash dates. The default parse fails on 97 of 123 dates; `format="mixed"` puts 14 on the wrong day without an error (6) | Medium | One format per shape; an unknown shape fails. Slash dates are month-first: all 17 unambiguous ones are. |
| 8 | 13 of 49 premiums use a decimal comma; a naive cast makes them NULL (7) | Medium | Replace the comma before casting. |
| 9 | E-mails with spaces and capitals: 123 spellings for 88 addresses (5) | Medium | Trim and lower-case: the e-mail is the customer key. |
| 10 | Status `ACTIVE` and `aktiv` next to `active`, on 2 of 27 active contracts (5) | Medium | Lower-case and map to the documented values. |
| 11 | The leads end on 2024-10-31, the contracts on 2024-11-29: the latest leads can still convert (6.4) | Medium | Rates by lead month; a month counts as complete once its leads are older than the 40 days. |
| 12 | 1 contract row is exported twice (8) | Low | Drop exact duplicates. |
| 13 | 3 leads have no vertical, 5 no region (4) | Low | `unknown`, so that totals still add up. |

## Assumptions and open questions

**Assumptions**
- Slash dates are month-first (issue 7).
- The e-mail address identifies a customer (issue 4).
- `premium` is the annual net premium in EUR, without thousands separators. `aktiv` means `active`.
- Both copies of a duplicated lead id describe the same lead (issue 3).

**Open questions.** The questions about the data are in the Task 1 table (issues 1–6). About the
definitions:
1. Should a `pending` contract count as a conversion? This decides the conversion definition in Tasks 2
   and 3.

## Run it

Tested with Python 3.13 on Windows.

```bash
python -m venv .venv
.venv\Scripts\activate            # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

Then open the notebook. Each chart is stored twice: interactive, and as a PNG that also shows on GitHub
(the export needs a local Chrome).

```bash
python -m ipykernel install --user --name coding-challenge-de
jupyter lab
```

Lint the Python code and the notebooks with `ruff check .`.
