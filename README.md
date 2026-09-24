# Data Engineer Coding Challenge: Leads & Conversions

Take-home assignment for durchblicker (see `docs/assignment/Coding_Challenge_EN.pdf`).

## Project structure

```
.
├── data/raw/                     # leads.csv, conversions.csv: the exports as delivered (not modified)
├── docs/assignment/              # the assignment (EN, DE)
├── notebooks/
│   └── 01_data_profiling.ipynb   # Task 1: profiling & DQ issue register
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

Re-run a notebook headless (stores outputs in place):

```bash
cd notebooks
jupyter nbconvert --to notebook --execute --inplace 01_data_profiling.ipynb
```

## Process log

### Task 1: Data Profiling & Data Quality (`notebooks/01_data_profiling.ipynb`)

**Approach**
- Load both CSVs **as raw strings** (`dtype=str`, `keep_default_na=False`) so pandas cannot silently coerce
  values (decimal commas, dates, whitespace). This notebook only profiles and measures; it cleans nothing.
- Profile each column (blanks, distinct values, whitespace, casing), then attempt the intended types
  (dates, numbers, categories) and measure what fails.
- Cross-file checks: referential integrity, email agreement, lead→sign lag, cardinality.
- Summarise everything in a DQ issue register with criticality and proposed handling.

**Key findings** (details and numbers in the notebook, section 11)
- 9 of 51 conversions (17.6 %) are orphans: their `lead_id` is blank or not in `leads`. Email-based recovery
  is plausible for only 2–3 of them.
- 4 `lead_id`s are duplicated with conflicting attributes, and 1 conversion row is an exact duplicate.
- Dates come in 3 formats. The slash format was shown to be `MM/DD/YYYY`: the alternative reading
  produces 8 invalid dates.
- Premiums use decimal commas (13 of 49), and there are negative (2) and missing (2) values.
- Status contains `aktiv` and `ACTIVE` in addition to the specified values.
- Emails need `trim + lower` normalisation: this reduces 103 raw values to 88 distinct emails.

**Decisions / assumptions:** see notebook section 12.

### Task 2: Lead-to-Conversion Model
_tbd_

### Task 3: KPI & Customer-Level Aggregation
_tbd_

### Task 4: Architecture & Automation
_tbd_
