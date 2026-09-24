"""Code shared by the notebooks: paths and chart defaults."""

from .charts import configure_plotly
from .paths import RAW_DATA_DIR, ROOT

__all__ = ["RAW_DATA_DIR", "ROOT", "configure_plotly"]
