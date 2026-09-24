"""Paths of the repository, independent of the folder a notebook is started from."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# The CSV exports as delivered by the source system (read by notebook 01 and by dbt)
RAW_DATA_DIR = ROOT / "data" / "raw"

# The DuckDB file that `dbt build` writes, read by the notebooks
DATABASE = ROOT / "dbt" / "lead_conversions.duckdb"
