"""Paths of the repository, independent of the folder a notebook is started from."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# The CSV exports as delivered by the source system
RAW_DATA_DIR = ROOT / "data" / "raw"
