# Data Engineer Coding Challenge: Leads & Conversions

Take-home assignment for durchblicker (see `docs/assignment/Coding_Challenge_EN.pdf`).

## Project structure

```
.
├── data/raw/                     # leads.csv, conversions.csv: the exports as delivered (not modified)
├── docs/assignment/              # the assignment (EN, DE)
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

## Process log

### Task 1: Data Profiling & Data Quality
_tbd_

### Task 2: Lead-to-Conversion Model
_tbd_

### Task 3: KPI & Customer-Level Aggregation
_tbd_

### Task 4: Architecture & Automation
_tbd_
