"""Compatibility helpers for Streamlit iframe HTML embeds."""

from __future__ import annotations

import streamlit as st
from streamlit.delta_generator import get_last_dg_added_to_context_stack


def html(
    body: str,
    width: int | None = None,
    height: int | None = None,
    scrolling: bool = False,
    *,
    tab_index: int | None = None,
):
    """Embed inline HTML in the active Streamlit container."""
    container = get_last_dg_added_to_context_stack() or st._main
    return container._html(
        body,
        width=width,
        height=height,
        scrolling=scrolling,
        tab_index=tab_index,
    )
