"""Chart defaults and the bar chart the notebooks use for their result tables."""

import pandas as pd
import plotly.express as px
import plotly.io as pio


def configure_plotly() -> None:
    """Interactive figures in Jupyter / PyCharm, plus a static PNG in the same output, so that
    the figures also show on GitHub (which strips JavaScript)."""
    pio.renderers.default = "plotly_mimetype+png"
    pio.templates.default = "plotly_white"
    pio.defaults.default_width = 900
    pio.defaults.default_height = 400


def bar_chart(table: pd.DataFrame, x: str, y: str, title: str) -> None:
    """Bar chart of a result table. Rows labelled 'unknown' are left out; the subtitle says so."""
    unknown = table[x].astype(str) == "unknown"
    fig = px.bar(table[~unknown], x=x, y=y, text_auto=True, title=title)
    fig.update_traces(textposition="outside")
    fig.update_xaxes(type="category")
    fig.update_yaxes(range=[0, table.loc[~unknown, y].max() * 1.15])
    if unknown.any():
        fig.update_layout(title_subtitle_text=f"Not shown: {x} 'unknown' (see the table above)")
    fig.show()
