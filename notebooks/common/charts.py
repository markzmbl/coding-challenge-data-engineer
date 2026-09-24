"""Chart defaults for the notebooks."""

import plotly.io as pio


def configure_plotly() -> None:
    """Interactive figures in Jupyter / PyCharm, plus a static PNG in the same output, so that
    the figures also show on GitHub (which strips JavaScript)."""
    pio.renderers.default = "plotly_mimetype+png"
    pio.templates.default = "plotly_white"
    pio.defaults.default_width = 900
    pio.defaults.default_height = 400

