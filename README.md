# Data Engineer Coding Challenge: Leads & Conversions

Take-home assignment for durchblicker (see `docs/assignment/Coding_Challenge_EN.pdf`).

## Project structure

```
.
├── data/raw/                     # leads.csv, conversions.csv: the exports as delivered (not modified)
├── docs/assignment/              # the assignment (EN, DE)
├── notebooks/
│   ├── common/                   # code shared by the notebooks: paths, chart defaults, warehouse queries
│   ├── 01_data_profiling.ipynb   # Task 1: profiling & DQ issue register
│   └── 02_lead_conversions.ipynb # Task 2: sample queries and charts on the lead mart, for marketing
├── dbt/                          # dbt project (DuckDB): raw -> staging -> marts
│   ├── dbt_project.yml           # load hook, vars (known date formats, conversion window)
│   ├── profiles.yml              # local DuckDB file lead_conversions.duckdb
│   ├── macros/                   # load_raw_csv, value_shape, parse_date_by_shape, parse_decimal
│   ├── models/staging/           # sources, stg_leads, stg_conversions, tests, unit tests
│   ├── models/marts/             # mart_lead_conversions (Task 2),
│   │                             # mart_lead_conversions_monthly, mart_customers (Task 3)
│   ├── analyses/                 # orphan_email_candidates (evidence for a Task 2 decision)
│   └── tests/                    # generic: values_have_shape, parses_as_decimal;
│                                 # singular: assert_task3_marts_add_up
├── pyproject.toml                # lint settings (ruff)
├── requirements.txt              # pinned versions
└── README.md                     # setup + process log
```

## Setup

Requires Python 3.11+ (developed with 3.13, Windows).

```bash
python -m venv .venv
.venv\Scripts\activate            # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
python -m ipykernel install --user --name coding-challenge-de --display-name "Python (.venv coding-challenge-de)"
jupyter lab
```

Figures use plotly. Each figure is stored twice in the notebook: as an interactive figure for
Jupyter/PyCharm and as a static PNG, so it also shows on GitHub. The PNG export (kaleido) needs a
local Chrome installation.

Re-run a notebook headless (stores outputs in place):

```bash
cd notebooks
jupyter nbconvert --to notebook --execute --inplace 01_data_profiling.ipynb
```

Lint the Python code and the notebooks (settings in `pyproject.toml`):

```bash
ruff check .
```

Build and test the dbt pipeline (from the `dbt` folder, which also holds `profiles.yml`):

```bash
cd dbt
dbt deps
dbt build
```

`dbt build` loads both CSVs into the `raw` schema, builds the models and runs all tests and unit tests.
Warnings are expected: they are the known data-quality issues from Task 1, each monitored with a threshold
(`warn_if` / `error_if`) that fails the run if the issue grows.

Notebook 02 reads the dbt warehouse (`dbt/lead_conversions.duckdb`), so run `dbt build` before it.

## Process log

### Task 1: Data Profiling & Data Quality (`notebooks/01_data_profiling.ipynb`)

**Approach: a discovery loop.** Nothing is assumed up front. Each section looks at the data, states a
finding and, where needed, applies a fix to a working copy, so the next section builds on cleaner data.
- Load both CSVs **as raw text** (`dtype=str`, `keep_default_na=False`), so pandas cannot silently
  coerce values at read time.
- **Discover formats instead of assuming them:** every value is reduced to its *shape* (digits → `9`,
  letters → `A`/`a`, spaces → `␣`). Counting shapes per column reveals date formats, decimal commas,
  whitespace, capitals and 5-digit ids without a single hand-written pattern.
- **Clean progressively:** trim and null empty strings, cast ids to nullable `Int64`, normalise e-mails
  and status, parse dates, drop exact duplicates, then parse premiums on the deduplicated contracts.
- **Dates:** `pandas.tseries.api.guess_datetime_format`, run month-first and day-first on the distinct
  values, finds the format of each shape and flags ambiguous values. The dates are then parsed with one
  explicit format per shape.
- Cross-file check limited to what a pipeline tests: referential integrity and cardinality of
  `conversions.lead_id`. Analyses that need joined data (lead→sign lag, orphan recovery by e-mail) are
  left for Task 2.
- The code is written with large data in mind: vectorised operations, expensive steps only on distinct
  values, aggregation before plotting.
- The notebook ends with the input for the dbt pipeline (section 11): layers, staging rules and tests
  per column, and the test severities.

**Key findings** (details in the notebook, section 10)
- 9 of 50 distinct conversions (18 %) are orphans: their `lead_id` is blank or not in `leads`.
  Every `lead_id` occurs at most once in the conversions (1 : 0..1).
- 4 `lead_id`s are duplicated with conflicting content. `region` differs in every one of them, which
  suggests an upstream fan-out join (open question). 1 conversion row is an exact duplicate.
- Dates come in 3 formats. Naive `pd.to_datetime` fails on 97 of 123 lead dates; `format="mixed"` raises
  no error but puts 14 of them on the wrong day. Slash dates are month-first: all 17 unambiguous ones
  are, and 16 are ambiguous.
- Premiums use decimal commas (13 of 48), and there are negative (2) and missing (2) values.
- Status contains `aktiv` and `ACTIVE` next to the documented values.
- E-mails need trimming and lower-casing: 123 raw spellings become 88 distinct addresses.

**Decisions / assumptions:** see notebook section 12.

### dbt pipeline, step 1: raw and staging (`dbt/`)

Local DuckDB via `dbt-duckdb`, so the pipeline runs with `pip install` and `dbt build`, with no cloud account
needed. The layers follow notebook 01, section 11:
- **Raw:** an `on-run-start` hook (`load_raw_csv`) copies both CSVs unchanged into the `raw` schema, every
  column as text, with a pinned CSV dialect and a `_loaded_at` timestamp. It stands in for the ingestion job
  that would fill these tables in production.
- **Staging:** `stg_leads` (123 rows) and `stg_conversions` (50 rows): one row per source row, cleaning only.
  - trim, blank → NULL, lower-cased e-mails, integer ids
  - dates parsed with one format per shape; the known formats are a var, `date_formats_by_shape`
  - decimal comma → point; `aktiv`/`ACTIVE` → `active`; the exact duplicate conversion is dropped
  - duplicate lead ids are kept: resolving them is a modelling decision for the marts
- **Tests:**
  - Source tests fail on unknown date shapes and unparseable premiums.
  - Staging tests check keys, accepted values and relationships.
  - The known issues are warnings with an `error_if` threshold at the Task 1 baseline: 4 duplicate lead ids,
    6 unknown and 3 missing lead ids, 3 missing verticals, 5 missing regions, 2 missing and 2 negative premiums.
  - 4 unit tests pin down the parsing rules, e.g. `06.10.2024` → 6 Oct, `03/05/2024` → 5 Mar,
    `2024/05/12` → NULL.
- **Checked:** a run against a corrupted copy of the files fails on a new date format, a thousands separator,
  a new status and a new channel.

### Task 2: Lead-to-Conversion Model

**Audience:** the marketing team (channel steering), together with the product owners of the verticals.
They want to see which leads converted, through which channel, how fast and with which premium.

**Mart `mart_lead_conversions` (`dbt/models/marts/`):** one row per lead (119), with its contract if the lead
converted (41 leads, 34.5 %). Columns: lead id, date and month, vertical, source, region, e-mail,
`is_converted`, contract id, signed date, status, premium, `days_to_sign`.

**Decisions**
- Duplicate lead ids are merged into one row: values the copies agree on are kept, contradicting ones become
  `unknown`, like missing values.
- Leads that never converted stay in (`is_converted = false`): they are the denominator of every conversion
  rate.
- A lead counts as converted if it has a signed contract, whatever its status. A later cancellation is churn,
  not a failed conversion.
- Conversions without a known lead (9 of 50, including 5 of the 7 pending contracts) are left out: they can't
  be credited to a channel, vertical or month. The staging tests keep monitoring them. Linking them by e-mail
  instead would mostly be a guess: only 3 of the 9 have a lead with the same e-mail and a plausible time to
  sign (`dbt show --select orphan_email_candidates --limit 20`).
- Tests: one row per lead (`lead_id` unique), unique contract ids, and `days_to_sign >= 0`, which guards the
  date-format assumption. A unit test pins down the merge rule.

**Notebook `notebooks/02_lead_conversions.ipynb`:** sample queries and charts the marketing team can build on
the mart directly: plain SQL on one table, no staging or raw data.
- Overview: 119 leads, 41 conversions (34.5 %), 26 active contracts; a successful conversion takes 21.7 days
  on average.
- Average days to sign per channel (about three weeks everywhere), active premium per channel, and the latest
  leads without a contract as a follow-up list.
- `unknown` values are left out of the charts (with a note) but kept in the result tables.

### Task 3: KPI & Customer-Level Aggregation

Both marts are built on `mart_lead_conversions`, so they share its definitions (duplicate leads merged,
conversion rule). Building a mart on a mart is deliberate: the definitions exist in one place only.

**Definitions**
- **Conversion:** a lead with a signed contract, whatever the contract's status (as in Task 2).
- **Month:** the month the **lead** came in, not the month the contract was signed. A conversion counts in the
  month of its lead, so a rate never exceeds 100 %.
- **Complete month:** contracts come up to 40 days after the lead (var `conversion_window_days`). A month is
  complete once all its leads are at least that old at the data cutoff, the latest signing date (2024-11-29).
  Only October 2024 is incomplete.
- **Contract status:** today's status (active / pending / cancelled). There is no status history, so the
  numbers of a past month change when one of its contracts is cancelled later. Freezing that history would
  need a dbt snapshot of the contracts (slowly changing dimension, type 2), which only pays off with recurring
  runs (Task 4).
- **Customer:** a person, identified by the cleaned e-mail address. Different addresses are different
  customers, even with the same name (a documented limitation from Task 1).

**Mart `mart_lead_conversions_monthly`:** one row per vertical × source × lead month (68 rows): `leads`,
`conversions`, `conversion_rate`, the conversions by status (`active_contracts`, `pending_contracts`,
`cancelled_contracts`) and `is_complete`. `unknown` stays as its own rows, so the table adds up to all
119 leads. All counts are additive: to combine rows, add them up and divide again; don't average the rates.
The status split answers a question beyond the required minimum: which channels bring contracts that last.

**Mart `mart_customers`:** one row per customer (88): `leads`, `conversions`, `total_active_premium`,
`has_active_contract`.
- The customer view counts **all 50 contracts**, including the 9 whose lead is unknown: a contract belongs to
  the person even when its lead can't be found. Without them, e.g. hannah.fuchs@gmx.at would show no active
  contract, although she holds one (894.41 EUR).
- `total_active_premium` is 0 without an active contract, and NULL if an active contract has no premium in the
  source (1 customer): unknown is not the same as zero.

**Tests:** unique vertical × source × month, `conversions <= leads`, active + pending + cancelled =
conversions, rate between 0 and 1, unique customers,
and a reconciliation test: the monthly mart adds up to the lead mart, the customer view to the lead mart and to
all contracts. A unit test pins down what counts for a customer.


### Task 4: Architecture & Automation
_tbd_
