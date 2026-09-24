"""Read access to the dbt warehouse."""

import duckdb
import pandas as pd

from .paths import DATABASE


def query(sql: str) -> pd.DataFrame:
    """Run a SQL query on the dbt warehouse; returns a table with nullable dtypes."""
    # Read-only, and closed again right away, so that dbt can keep writing to the file.
    with duckdb.connect(str(DATABASE), read_only=True) as con:
        return con.sql(sql).df().convert_dtypes()
