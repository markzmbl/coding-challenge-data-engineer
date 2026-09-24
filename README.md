# Data Engineer Coding Challenge: Leads & Conversions

Take-home assignment for durchblicker (see `docs/assignment/Coding_Challenge_EN.pdf`).

## Project structure

```
.
├── data/raw/                     # leads.csv, conversions.csv: the exports as delivered (not modified)
├── docs/assignment/              # the assignment (EN, DE)
├── notebooks/
│   ├── common/                   # code shared by the notebooks: paths, chart defaults
│   └── 01_data_profiling.ipynb   # Task 1: profiling & DQ issue register
├── dbt/                          # dbt project (DuckDB): raw -> staging -> marts
│   ├── dbt_project.yml           # load hook, vars (known date formats)
│   ├── profiles.yml              # local DuckDB file lead_conversions.duckdb
│   ├── macros/                   # load_raw_csv, value_shape, parse_date_by_shape, parse_decimal
│   ├── models/staging/           # sources, stg_leads, stg_conversions, tests, unit tests
│   └── tests/generic/            # values_have_shape, parses_as_decimal
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
_tbd_

### Task 3: KPI & Customer-Level Aggregation
_tbd_

### Task 4: Architecture & Automation
_tbd_
