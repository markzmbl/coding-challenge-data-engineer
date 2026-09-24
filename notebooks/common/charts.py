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


def bar_chart(
    table: pd.DataFrame,
    x: str,
    y: str | list[str],
    title: str,
    labels: dict[str, str],
    y_title: str,
) -> None:
    """Bar chart of a result table, with grouped bars if y lists several columns.
    labels names the columns in plain words; y_title names the y axis, with its unit.
    Rows labelled 'unknown' are left out; the subtitle says so."""
    columns = [y] if isinstance(y, str) else y
    unknown = table[x].astype(str) == "unknown"
    shown = table.loc[~unknown, [x, *columns]].rename(columns=labels)
    names = [labels.get(column, column) for column in columns]
    fig = px.bar(shown, x=labels.get(x, x), y=names, text_auto=True, title=title, barmode="group")
    fig.update_traces(textposition="outside")
    fig.update_xaxes(type="category")
    fig.update_yaxes(title=y_title, range=[0, shown[names].to_numpy().max() * 1.15])
    fig.update_layout(legend_title_text="", showlegend=len(names) > 1)
    if unknown.any():
        fig.update_layout(title_subtitle_text=f"Not shown: {x} 'unknown' (see the table above)")
    fig.show()
