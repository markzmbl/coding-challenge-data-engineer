# Leads & Conversions – Data Engineer Coding Challenge

My solution to the durchblicker take-home assignment ([EN](docs/assignment/Coding_Challenge_EN.pdf),
[DE](docs/assignment/Coding_Challenge_DE.pdf)):
- A notebook shows the profiling.

| Task | Deliverable |
|---|---|
| 1. Data profiling & data quality | [Profiling notebook](notebooks/task1_data_profiling.ipynb), issue register in section 11 |
| Assumptions and open questions | [Profiling notebook](notebooks/task1_data_profiling.ipynb), section 12 |

## Task 1 – Data profiling & data quality

The notebook loads both files as raw text, profiles every column, tries the intended types and measures what
fails. Its register lists 15 issues. The most important ones:
- **9 of 51 conversions (17.6 %) cannot be linked to a lead:** their `lead_id` is blank or not in the leads.
  Recovery by e-mail is plausible for only 2–3 of them.
- **Duplicates:**
  - 4 lead ids occur twice, with conflicting attributes.
  - 1 conversion row is an exact duplicate.
- **Dates in three formats.** The slash format is `MM/DD/YYYY`: the other reading produces 8 invalid dates.
- **Inconsistent values:**
  - 13 of 49 premiums use a decimal comma; 2 are negative and 2 missing.
  - The status has `aktiv` and `ACTIVE` next to the documented values.
  - The e-mails need trimming and lower-casing: 103 raw values, but only 88 addresses.

## Run it

Tested with Python 3.13 on Windows.

```bash
python -m venv .venv
.venv\Scripts\activate            # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

Then open the notebook:

```bash
python -m ipykernel install --user --name coding-challenge-de
jupyter lab
```
