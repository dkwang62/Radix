# radix_ui.py
# Consolidated UI components, HTML builders, and styles

import streamlit as st
from radix_embed import html as st_html
import json
import html as pyhtml
import base64
import hashlib
import uuid
import os
import sqlite3
from radix_core import (
    component_map, clean_field, format_decomposition, get_etymology_text,
    cc_t2s, cc_s2t, get_char_definition_en, component_usage_count, analyze_component_structure, get_pronunciation_family, get_semantic_family
)

RADIX_REFERENCE_DIR = "/Users/desmondkwang/Library/Mobile Documents/com~apple~CloudDocs/Projects/Radix"
HANZI_WRITER_JS_PATH = os.path.join(RADIX_REFERENCE_DIR, "Resources", "hanzi-writer.min.js")
STROKE_DB_PATH = os.path.join(RADIX_REFERENCE_DIR, "Resources", "character_strokes.db")
_HANZI_WRITER_SCRIPT = None
_STROKE_DB_CONN = None


# ==================== STYLES ====================

def apply_styles():
    """Apply all CSS styles — refined ink-on-paper aesthetic."""
    st.markdown("""
    <style>
    @import url('https://fonts.googleapis.com/css2?family=Noto+Serif+SC:wght@400;600;700;900&family=Noto+Sans+SC:wght@400;500;700&family=Lora:ital,wght@0,400;0,600;0,700;1,400;1,600&display=swap');

    /* ── Root palette ── */
    :root {
      --ink:       #1a1410;
      --ink-2:     #3d342a;
      --ink-3:     #6b5e52;
      --ink-4:     #a89e94;
      --paper:     #faf8f4;
      --paper-2:   #f3efe8;
      --paper-3:   #e8e2d8;
      --paper-4:   #d8d0c4;
      --vermilion: #c0392b;
      --vermilion-light: #f5ede9;
      --vermilion-dim:   #e8b4ad;
      --jade:      #2a6b55;
      --jade-light: #e3ede9;
      --jade-dim:  #a0c4b8;
      --gold:      #b07a28;
      --gold-light: #f5eed8;
      --indigo:    #2e4a7a;
      --indigo-light: #e4eaf5;
      --shadow-sm: 0 1px 3px rgba(26,20,16,0.08);
      --shadow-md: 0 3px 10px rgba(26,20,16,0.1);
      --shadow-lg: 0 8px 28px rgba(26,20,16,0.12);
      --radius-sm: 6px;
      --radius-md: 10px;
      --radius-lg: 16px;
    }

    /* ── Global resets ── */
    .main .block-container {
      padding-top: 1.5rem;
      padding-bottom: 3rem;
      background: var(--paper);
    }
    body, .stApp { background: var(--paper) !important; }
    section[data-testid="stSidebar"] {
      background: var(--paper-2) !important;
      border-right: 1px solid var(--paper-4) !important;
    }

    /* ── Character card ── */
    .char-card, .radix-info-card {
      background: #fff;
      padding: 16px;
      border-radius: var(--radius-md);
      margin-bottom: 0;
      border: 1px solid var(--paper-3);
      box-shadow: var(--shadow-sm);
      transition: box-shadow 0.18s ease, border-color 0.18s ease;
    }
    .char-card:hover, .radix-info-card:hover {
      box-shadow: var(--shadow-md);
      border-color: var(--paper-4);
    }

    /* ── Card header ── */
    .radix-info-header { display:flex; align-items:flex-start; gap:10px; margin-bottom:12px; }
    .radix-info-main-tile {
      width:68px; height:68px; flex:0 0 68px;
      display:flex; flex-direction:column; align-items:center; justify-content:center; gap:3px;
      background: var(--vermilion-light);
      border: 1.5px solid var(--vermilion-dim);
      border-radius: var(--radius-md);
    }
    .radix-info-main-char {
      font-family: 'Noto Serif SC', serif;
      font-size: 2.1rem; line-height: 1; font-weight: 900;
      color: var(--vermilion);
    }
    .radix-info-tile-sub {
      font-family: 'Noto Sans SC', sans-serif;
      font-size: 0.62rem; line-height: 1; color: var(--ink-3); font-weight: 500;
      max-width:58px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;
    }
    .radix-info-pinyin {
      font-family: 'Lora', Georgia, serif;
      font-size: 2.1rem; line-height: 1.05; font-weight: 700;
      color: var(--vermilion); overflow-wrap:anywhere;
    }
    .radix-info-word {
      font-family: 'Noto Serif SC', serif;
      font-size: 2rem; line-height: 1.05; font-weight: 700;
      color: var(--ink); overflow-wrap:anywhere;
    }
    .radix-info-header-body { min-width:0; flex:1; }

    /* ── Chips & pills ── */
    .radix-info-actions { display:flex; flex-wrap:wrap; gap:6px; margin-bottom:10px; }
    .radix-action-pill {
      display:inline-flex; align-items:center; gap:5px;
      padding:5px 10px; min-height:28px;
      background: var(--indigo-light);
      border: 1px solid #c4cedf;
      border-radius: var(--radius-sm);
      color: var(--indigo);
      font-size:0.8rem; font-weight:700; line-height:1;
      font-family: 'Noto Sans SC', sans-serif;
    }
    .radix-chip {
      display:inline-flex; align-items:center; gap:5px;
      padding:5px 10px; min-height:28px;
      background: var(--paper-2); border: 1px solid var(--paper-4);
      border-radius: var(--radius-sm);
      color: var(--ink-2);
      font-size:0.8rem; font-weight:600; line-height:1;
    }
    .radix-tier-chip { color:#fff; border-color:transparent; }
    .radix-tier-1 { background: var(--jade); }
    .radix-tier-2 { background: #2a8a6a; }
    .radix-tier-3 { background: var(--gold); }
    .radix-tier-4 { background: #b06020; }
    .radix-tier-5 { background: var(--ink-3); }

    /* ── Sections ── */
    .radix-section {
      padding: 10px 12px; border-radius: var(--radius-md);
      background: var(--paper-2);
      border: 1px solid var(--paper-3);
      margin-top: 8px;
    }
    .radix-section.soft { background: rgba(243,239,232,0.55); border-color: var(--paper-3); }
    .radix-section-label {
      font-family: 'Noto Sans SC', sans-serif;
      font-size:0.72rem; line-height:1.1; color: var(--ink-3);
      font-weight:700; text-transform:uppercase; letter-spacing:0.04em;
      margin-bottom:5px; display:flex; gap:5px; align-items:center;
    }
    .radix-section-text {
      font-family: 'Noto Sans SC', sans-serif;
      font-size:0.93rem; line-height:1.5; color: var(--ink); overflow-wrap:anywhere;
    }
    .radix-section-text.secondary { font-size:0.84rem; color: var(--ink-3); font-style:italic; font-family: 'Lora', serif; }
    .radix-section-text.notes { font-size:0.84rem; color: var(--ink-2); font-style:normal; }

    /* ── Parts grid ── */
    .radix-parts-grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(54px, 1fr)); gap:6px; }
    .radix-part-tile {
      height:56px; display:flex; flex-direction:column;
      align-items:center; justify-content:center; gap:2px;
      border: 1px solid var(--paper-4);
      border-radius: var(--radius-sm);
      background: #fff;
      transition: border-color 0.15s, box-shadow 0.15s;
    }
    .radix-part-tile:hover { border-color: var(--vermilion-dim); box-shadow: var(--shadow-sm); }
    .radix-part-tile.radical { background: var(--gold-light); border-color: #d4a84b; }
    .radix-part-char {
      font-family: 'Noto Serif SC', serif;
      font-size:1.45rem; font-weight:700; line-height:1; color: var(--vermilion);
    }
    .radix-part-sub { font-size:0.62rem; color: var(--ink-3); line-height:1; max-width:46px; overflow:hidden; white-space:nowrap; text-overflow:ellipsis; }

    /* ── Variants ── */
    .radix-variant-row { display:flex; align-items:center; flex-wrap:wrap; gap:7px; margin:2px 0 10px 0; }
    .radix-variant-label { font-size:0.74rem; color: var(--ink-3); font-weight:700; letter-spacing:0.03em; text-transform:uppercase; }
    .radix-variant-button {
      width:36px; height:36px; display:inline-flex; align-items:center; justify-content:center;
      border-radius: var(--radius-sm);
      background: var(--indigo-light); border: 1px solid #c4cedf;
      color: var(--ink); font-size:1.3rem; font-family:'Noto Serif SC',serif; font-weight:700;
    }
    .radix-variant-script { font-size:0.62rem; color: var(--ink-3); font-weight:700; margin-left:-3px; }

    /* ── Legacy meta classes ── */
    .meta-row { font-size:0.95em; color: var(--ink-2); margin-bottom:12px; display:flex; align-items:center; flex-wrap:wrap; gap:12px; }
    .meta-pinyin {
      font-family: 'Lora', serif;
      font-weight:700; font-size:2.4em; color: var(--vermilion);
    }
    .meta-tag {
      background: var(--paper-2); padding:4px 11px; border-radius: var(--radius-sm);
      font-size:0.83em; color: var(--ink-2); font-weight:600;
      border: 1px solid var(--paper-3);
      margin-bottom:5px; display:inline-block;
    }
    .meta-tag-trad { background: var(--gold-light); color: var(--gold); border-color: #d4a84b; }
    .meta-tag-simp { background: var(--jade-light); color: var(--jade); border-color: var(--jade-dim); }
    .def-row {
      font-family: 'Noto Sans SC', sans-serif;
      font-size:1.13em; line-height:1.65; color: var(--ink); margin-bottom:10px; font-weight:500;
    }
    .ety-row {
      font-family: 'Lora', serif;
      font-size:0.9em; color: var(--ink-3); font-style:italic;
      border-top: 1px solid var(--paper-3); padding-top:10px; margin-top:8px; line-height:1.55;
    }
    section[data-testid="stSidebar"] .meta-pinyin { font-size:2.0em !important; }
    section[data-testid="stSidebar"] .char-card { padding:14px !important; }
    section[data-testid="stSidebar"] .def-row { font-size:1.03em !important; }

    /* ── Component grid buttons ── */
    .comp-grid .stButton > button {
      width:100% !important; font-size:2.1em !important;
      height:90px !important;
      font-family: 'Noto Serif SC', serif !important;
      background: #fff !important;
      border: 1.5px solid var(--paper-3) !important;
      border-radius: var(--radius-md) !important;
      box-shadow: var(--shadow-sm) !important;
      padding:6px 4px !important; font-weight:700 !important;
      color: var(--ink) !important;
      transition: all 0.18s ease !important;
      white-space:normal !important; overflow:hidden !important;
    }
    .comp-grid .stButton > button [data-testid="stMarkdownContainer"] p {
      white-space:pre-line !important; line-height:0.95 !important;
      font-size:1.4rem !important; overflow:hidden !important; text-overflow:ellipsis !important;
    }
    .comp-grid .stButton > button:hover {
      background: var(--vermilion-light) !important;
      border-color: var(--vermilion-dim) !important;
      color: var(--vermilion) !important;
      transform: translateY(-2px) !important;
      box-shadow: 0 5px 14px rgba(192,57,43,0.12) !important;
    }

    /* ── Browse page ── */
    .browse-page-title {
      font-family: 'Noto Serif SC', serif;
      text-align:center; font-size:1.4rem; font-weight:800; color: var(--ink); margin:0 0 16px 0;
    }
    .browse-page-card {
      display:flex; align-items:center; justify-content:space-between; gap:16px;
      background:#fff; border-radius: var(--radius-md);
      padding:16px 18px; margin:10px 0;
      box-shadow: var(--shadow-sm); border:1px solid var(--paper-3);
      transition: box-shadow 0.18s, border-color 0.18s;
    }
    .browse-page-card:hover { box-shadow: var(--shadow-md); border-color: var(--paper-4); }
    .browse-page-card-main { display:flex; align-items:center; gap:12px; min-width:0; }
    .browse-page-card-icon {
      width:38px; height:38px; border-radius:9px; display:flex; align-items:center; justify-content:center;
      background: var(--jade-light); color: var(--jade);
      font-family:'Noto Serif SC',serif; font-size:1.3rem; font-weight:800;
    }
    .browse-page-card-title {
      font-family: 'Noto Serif SC', serif;
      font-size:1.5rem; line-height:1.1; font-weight:800; color: var(--ink);
      white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
    }
    .browse-page-card-sub { font-size:1.05rem; color: var(--ink-3); margin-top:2px; font-weight:500; }
    .browse-page-translation [data-testid="stExpander"] {
      border-radius: var(--radius-md) !important; border:1px solid var(--paper-3) !important; box-shadow:none !important;
    }
    .st-key-browse_page_tools [data-testid="stElementContainer"] { margin-bottom:4px !important; }
    .st-key-browse_page_tools [data-testid="stSelectbox"] { margin-bottom:0 !important; }
    .st-key-browse_page_flow [data-testid="column"] { min-width:0 !important; }
    .st-key-browse_page_flow [data-testid="stElementContainer"] { margin-bottom:3px !important; }
    .st-key-browse_page_flow .stButton button {
      width:100% !important; min-width:0 !important; height:40px !important;
      padding:1px 3px !important; white-space:normal !important; overflow:hidden !important;
      font-size:1rem !important; font-family:'Noto Serif SC',serif !important;
      background: var(--paper-2) !important; border:1px solid var(--paper-3) !important;
      border-radius: var(--radius-sm) !important; box-shadow:none !important;
      color: var(--ink) !important; font-weight:700 !important; transition:all 0.12s ease !important;
    }
    .st-key-browse_page_flow .stButton button [data-testid="stMarkdownContainer"] p {
      font-size:0.9rem !important; line-height:0.9 !important; white-space:pre-line !important;
      overflow:hidden !important; text-overflow:ellipsis !important; letter-spacing:0 !important;
    }
    .st-key-browse_page_flow .stButton button:hover {
      background: var(--jade-light) !important; border-color: var(--jade-dim) !important;
      color: var(--ink) !important; transform:none !important; box-shadow:none !important;
    }
    .st-key-browse_page_flow .stButton button[kind="primary"] {
      background: var(--jade-light) !important; border-color: var(--jade-dim) !important; color: var(--ink) !important;
    }

    /* ── Char buttons ── */
    .char-btn-wrap .stButton > button {
      width:100% !important;
      font-size:3.6em !important; font-weight:700 !important;
      font-family:'Noto Serif SC', serif !important;
      background: #fff !important;
      border: 1.5px solid var(--paper-3) !important;
      padding:10px !important; min-height:90px !important;
      border-radius: var(--radius-lg) !important;
      box-shadow: var(--shadow-sm) !important;
      color: var(--ink) !important;
      transition: all 0.2s ease !important;
    }
    .char-btn-wrap .stButton > button:hover {
      background: var(--vermilion-light) !important;
      border-color: var(--vermilion-dim) !important;
      color: var(--vermilion) !important;
      transform: scale(1.02) !important;
      box-shadow: 0 5px 18px rgba(192,57,43,0.14) !important;
    }
    .pen-btn-wrap .stButton > button {
      width:100% !important; font-size:1.5em !important;
      border:1.5px solid var(--paper-3) !important;
      background: var(--paper-2) !important;
      margin-top:7px !important; height:44px !important;
      color: var(--ink-2) !important; font-weight:600 !important;
      border-radius: var(--radius-md) !important; transition:all 0.18s ease !important;
    }
    .pen-btn-wrap .stButton > button:hover {
      background: var(--jade-light) !important;
      border-color: var(--jade-dim) !important; color: var(--jade) !important;
      transform:translateY(-1px) !important; box-shadow: var(--shadow-sm) !important;
    }
    .char-static-box {
      font-family:'Noto Serif SC',serif;
      font-size:3.6em; font-weight:700;
      background: var(--paper-2); color: var(--paper-4);
      border:1.5px solid var(--paper-3); border-radius: var(--radius-lg);
      padding:10px; min-height:90px; display:flex; align-items:center; justify-content:center;
      width:100%; cursor:default; box-shadow:none;
    }

    /* ── Status & lineage ── */
    .status-line {
      font-size:1.05em; font-weight:600; color: var(--jade);
      background: var(--jade-light); border:1px solid var(--jade-dim);
      padding:15px; border-radius: var(--radius-md); margin:18px 0 26px 0;
      box-shadow: var(--shadow-sm);
    }
    .status-tag {
      background: var(--paper); color: var(--ink-2);
      padding:5px 13px; border-radius: var(--radius-sm);
      font-weight:700; font-size:0.88em;
      border:1px solid var(--paper-3); display:inline-flex; align-items:center;
    }
    .lineage-header {
      font-family: 'Noto Sans SC', sans-serif;
      font-size:0.78rem; font-weight:700; color: var(--ink-3);
      margin:22px 0 10px 0; padding:0 0 7px 0;
      border-bottom: 1.5px solid var(--paper-3);
      text-transform: uppercase; letter-spacing: 0.06em;
    }
    .compound-item {
      display:flex; align-items:baseline; margin-bottom:8px; padding:10px 12px;
      border-bottom:1px solid var(--paper-3); border-radius: var(--radius-sm);
      background:#fff; transition:background 0.15s, transform 0.15s;
    }
    .compound-item:hover { background: var(--paper-2); transform:translateX(3px); }
    .cp-word {
      font-family:'Noto Serif SC',serif;
      font-weight:700; font-size:1.15em; color: var(--ink); min-width:80px; margin-right:14px;
    }
    .cp-pinyin {
      font-family:'Lora',serif;
      color: var(--vermilion); margin-right:14px; font-weight:600; font-size:1.45em; font-style:italic;
    }
    .cp-mean { color: var(--ink-2); font-size:0.97em; flex:1; line-height:1.45; }
    .char-btn-hint { margin-top:5px; text-align:center; font-size:0.84em; color: var(--ink-3); font-weight:600; }
    .char-btn-hint.previewing { color: var(--vermilion); }

    /* ── Tier pills ── */
    .tier-row { display:flex; align-items:center; justify-content:space-between; margin:8px 0 10px 0; }
    .tier-left { display:flex; align-items:center; gap:10px; }
    .tier-pill {
      display:inline-block; padding:5px 14px; border-radius:20px;
      font-weight:800; color:#fff; font-size:0.9em; line-height:1.2;
      font-family:'Noto Sans SC',sans-serif; letter-spacing:0.02em;
    }
    .tier-pill.t1 { background: var(--jade); }
    .tier-pill.t2 { background: #2a8a6a; }
    .tier-pill.t3 { background: var(--gold); }
    .tier-pill.t4 { background: #b06020; }
    .tier-pill.t5 { background: var(--ink-3); }
    .tier-info-btn {
      display:inline-flex; align-items:center; justify-content:center;
      width:32px; height:32px; border-radius:50%;
      border:1.5px solid var(--ink-4); color: var(--ink-3);
      font-weight:800; font-size:18px; background: var(--paper); box-sizing:border-box;
    }
    .tier-reco { font-family:'Lora',serif; font-style:italic; color: var(--ink-3); font-size:0.93em; padding-right:2px; }

    /* ── Splash screen ── */
    .splash-wrap { max-width:820px; margin:0 auto; padding:50px 20px 20px 20px; }
    .splash-card {
      background:#fff; border:1px solid var(--paper-3); border-radius:32px;
      padding:52px; box-shadow: var(--shadow-lg); text-align:center;
    }
    .splash-title {
      font-family:'Noto Serif SC',serif;
      font-size:2.8em; font-weight:900; color: var(--ink); margin-bottom:10px; letter-spacing:-0.01em;
    }
    .splash-sub { font-family:'Lora',serif; font-size:1.2em; color: var(--ink-3); font-style:italic; }
    .palace-entrance-container { text-align:center; margin:50px 0; }
    .grand-torii { font-size:220px !important; line-height:1; filter:drop-shadow(0 8px 18px rgba(26,20,16,0.12)); }
    .entrance-text {
      font-family:'Noto Serif SC',serif;
      color: var(--ink); font-size:22px; font-weight:700;
      margin-top:18px; margin-bottom:28px; letter-spacing:3px;
    }

    /* ── Tooltip ── */
    .radix-tooltip { position:relative; display:inline-block; cursor:help; }
    .radix-tooltip .radix-tooltiptext {
      visibility:hidden; width:240px; background: var(--ink);
      color:#f5f0e8; text-align:left; border-radius: var(--radius-md);
      padding:11px 13px; position:absolute; z-index:1000; bottom:125%; left:50%;
      margin-left:-120px; opacity:0; transition:opacity 0.25s;
      font-size:0.78rem; font-weight:400; line-height:1.45;
      box-shadow: var(--shadow-lg); pointer-events:none;
    }
    .radix-tooltip .radix-tooltiptext::after {
      content:""; position:absolute; top:100%; left:50%; margin-left:-5px;
      border-width:5px; border-style:solid; border-color: var(--ink) transparent transparent transparent;
    }
    .radix-tooltip:hover .radix-tooltiptext { visibility:visible; opacity:1; }
    .radix-tooltiptext strong { color: #f5c67a; }

    /* ── Insight box ── */
    .insight-box {
      background:#fff; border:1px solid var(--paper-3); border-radius: var(--radius-md);
      padding:18px; margin-top:18px; box-shadow: var(--shadow-sm);
    }
    .insight-title {
      font-family:'Noto Serif SC',serif;
      font-weight:800; color: var(--ink); font-size:1.05em; margin-bottom:13px;
      display:flex; align-items:center; gap:8px;
    }
    .role-badge { display:inline-flex; align-items:center; padding:5px 11px; border-radius: var(--radius-sm); font-size:0.88em; font-weight:600; margin-right:9px; margin-bottom:7px; }
    .role-semantic { background: var(--jade-light); color: var(--jade); border:1px solid var(--jade-dim); }
    .role-phonetic { background: var(--indigo-light); color: var(--indigo); border:1px solid #c4cedf; }
    .family-list { display:flex; gap:8px; flex-wrap:wrap; margin-top:7px; }
    .family-char {
      font-family:'Noto Serif SC',serif;
      font-size:1.35em; color: var(--ink-2); cursor:pointer;
      padding:2px 8px; background: var(--paper-2);
      border-radius: var(--radius-sm); border:1px solid var(--paper-3);
      transition: background 0.15s, color 0.15s;
    }
    .family-char:hover { background: var(--vermilion-light); color: var(--vermilion); border-color: var(--vermilion-dim); }

    /* ── Sidebar nav buttons ── */
    .st-key-nav_pad [data-testid='stButton'] > button {
      height:82px !important; min-height:82px !important;
      border-radius: var(--radius-md) !important;
      background: var(--paper-2) !important;
      border: 1px solid var(--paper-3) !important;
      color: var(--ink-2) !important;
      box-shadow: none !important;
      transition: background 0.15s, border-color 0.15s !important;
    }
    .st-key-nav_pad [data-testid='stButton'] > button:hover {
      background: var(--paper-3) !important; border-color: var(--paper-4) !important;
    }
    .st-key-nav_pad [data-testid='stButton'] > button [data-testid='stMarkdownContainer'] { display:none; }
    .st-key-nav_pad [data-testid='stButton'] > button [data-testid='stIconMaterial'] { font-size:28px; line-height:1; color: var(--ink-2); }
    .st-key-nav_bottom [data-testid='stButton'] > button {
      height:46px !important; border-radius:999px !important;
      font-size:14px !important; font-weight:500 !important;
      border:1px solid var(--paper-3) !important;
      background: var(--paper-2) !important;
      color: var(--ink-2) !important;
    }

    /* ── Browse tab switcher ── */
    .st-key-browse_tab_dict [data-testid='stButton'] > button,
    .st-key-browse_tab_pages [data-testid='stButton'] > button {
      border-radius: 8px !important;
      height: 40px !important;
      font-size: 0.88rem !important;
      font-weight: 700 !important;
    }
    .st-key-browse_tab_dict [data-testid='stButton'] > button[kind="secondary"],
    .st-key-browse_tab_pages [data-testid='stButton'] > button[kind="secondary"] {
      background: var(--paper-2) !important;
      border: 1px solid var(--paper-3) !important;
      color: var(--ink-3) !important;
    }
    .st-key-browse_tab_dict [data-testid='stButton'] > button[kind="primary"],
    .st-key-browse_tab_pages [data-testid='stButton'] > button[kind="primary"] {
      background: var(--ink) !important;
      border: 1px solid var(--ink) !important;
      color: var(--paper) !important;
    }

    /* ── Browse ● dot badge on nav button ── */
    .st-key-nav_browse_6 [data-testid='stButton'] > button [data-testid='stMarkdownContainer'] p {
      color: var(--vermilion) !important;
    }

    /* ── Lineage expanded tile ── */
    .lineage-expanded-card {
      background: #fff;
      border: 1.5px solid var(--v-dim);
      border-radius: var(--radius-md);
      padding: 16px;
      margin-top: 10px;
      box-shadow: 0 3px 12px rgba(192,57,43,0.08);
    }

    /* ── Comp-grid tile size for lineage ── */
    .comp-grid .stButton > button {
      min-height: 72px !important;
      height: 72px !important;
    }
    </style>
    """, unsafe_allow_html=True)

# ==================== HTML BUILDERS ====================

FREQ_PERCENTILES = {'p95': 8500, 'p75': 3200, 'p50': 800, 'p25': 150}

_TIER_RANK_CACHE = None


def _build_freq_rank_and_coverage_maps():
    freq_pairs = []
    for ch, info in component_map.items():
        freq = float(info.get('freq_per_million', 0.0) or 0.0)
        freq_pairs.append((ch, max(freq, 0.0)))

    ranked = sorted(freq_pairs, key=lambda x: (-x[1], x[0]))
    rank_map = {}
    coverage_map = {}
    total = sum(v for _, v in ranked if v > 0)
    cumulative = 0.0
    rank = 0
    for ch, freq in ranked:
        if freq > 0:
            rank += 1
            rank_map[ch] = rank
            cumulative += freq
            coverage_map[ch] = (cumulative / total * 100.0) if total else 0.0
        else:
            rank_map[ch] = len(component_map) + 1
            coverage_map[ch] = 100.0
    return rank_map, coverage_map




def _get_tier_rank_cache():
    global _TIER_RANK_CACHE
    if _TIER_RANK_CACHE is None:
        _TIER_RANK_CACHE = _build_freq_rank_and_coverage_maps()
    return _TIER_RANK_CACHE


def _tier_from_freq_rank(rank: int) -> int:
    if rank <= 1500:
        return 1
    if rank <= 3000:
        return 2
    if rank <= 4000:
        return 3
    if rank <= 5000:
        return 4
    return 5


def _tier_meta_for_char(c: str):
    rank_map, coverage_map = _get_tier_rank_cache()
    rank = int(rank_map.get(c, len(component_map) + 1))
    tier = _tier_from_freq_rank(rank)
    tier_name = {
        1: 'Core Literacy',
        2: 'Fluency Core',
        3: 'Educated Native',
        4: 'Academic/Pro',
        5: 'Niche/Rare',
    }[tier]
    recommendation = {
        1: 'Essential',
        2: 'Required',
        3: 'Recommended',
        4: 'Optional',
        5: 'Ignore',
    }[tier]
    return tier, tier_name, rank, round(float(coverage_map.get(c, 100.0)), 2), recommendation


def build_frequency_badge(freq: float, minimal: bool = False) -> str:
    """Build frequency badge HTML (without old frequency guide tooltip)."""
    if freq > 0:
        if freq >= FREQ_PERCENTILES['p95']:
            label, color = "Top 5%", "#2e7d32"
        elif freq >= FREQ_PERCENTILES['p75']:
            label, color = "Top 25%", "#558b2f"
        elif freq >= FREQ_PERCENTILES['p50']:
            label, color = "Above Average", "#ff8f00"
        elif freq >= FREQ_PERCENTILES['p25']:
            label, color = "Below Average", "#f57c00"
        else:
            label, color = "Bottom 25%", "#c62828"
        return f"<span class='meta-tag' style='background: linear-gradient(135deg, {color}15 0%, {color}25 100%); color: {color}; border: 1px solid {color}40; font-weight:700;'>Freq: {label}</span>"
    return "<span class='meta-tag' style='color:#999;'>Freq: No Data</span>"

def build_tier_info_row(c: str) -> str:
    tier, tier_name, rank, _, recommendation = _tier_meta_for_char(c)
    tier_cls = {1: 't1', 2: 't2', 3: 't3', 4: 't4', 5: 't5'}.get(tier, 't5')

    guide = (
        "<strong>Character Learning Guide</strong><br><br>"
        "<strong>Tier 1: Core Literacy</strong><br>"
        "Everyday survival characters. Essential for basic reading.<br><br>"
        "<strong>Tier 2: Fluency Core</strong><br>"
        "Required for reading newspapers and modern written content.<br><br>"
        "<strong>Tier 3: Educated Native</strong><br>"
        "Required for university-level reading and formal argumentation.<br><br>"
        "<strong>Tier 4: Academic/Pro</strong><br>"
        "Specialized, technical, or research-heavy characters.<br><br>"
        "<strong>Tier 5: Niche/Rare</strong><br>"
        "Rare names, dialect, or archaic forms. Safe to ignore for most learners."
    )

    return (
        f"<div class='tier-row'>"
        f"<div class='tier-left'>"
        f"<span class='tier-pill {tier_cls}'>Tier {tier}</span>"
        f"<div class='radix-tooltip'><span class='tier-info-btn'>i</span><span class='radix-tooltiptext' style='width:308px; left:0; margin-left:0; bottom:115%; font-size:0.82rem; line-height:1.38;'>{guide}</span></div>"
        f"</div>"
        f"<span class='tier-reco'>{recommendation}</span>"
        f"</div>"
    )


def build_usage_badge(count: int, char: str, is_static: bool, minimal: bool) -> str:
    """Build usage badge with tooltip."""
    if count <= 0:
        return ""
    
    if minimal:
        return f"<span class='meta-tag' title='Used in {count} characters. Click to drill down.'>Used in {count} chars</span>"
    else:
        if is_static:
            tip = f"💡 <strong>Static View:</strong> Copy and paste <strong>{char}</strong> into the search box to explore related chars."
        else:
            tip = f"✨ <strong>Interactive Tip:</strong><br>1. Click <strong>{char}</strong> once to preview in sidebar.<br>2. Click <strong>{char}</strong> again to drill down into the {count} related characters."
        return f"<div class='radix-tooltip'><span class='meta-tag' style='border-bottom: 2px dotted #aaa;'>Used in {count} chars</span><span class='radix-tooltiptext'>{tip}</span></div>"

IDC_CHARS_LOCAL = set("⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿻")


def _section_html(title: str, icon: str, text: str, *, soft: bool = False, secondary: bool = False, notes: bool = False, fallback: str = "") -> str:
    body = (text or "").strip() or fallback
    if not body:
        return ""
    classes = ["radix-section"]
    if soft:
        classes.append("soft")
    text_classes = ["radix-section-text"]
    if secondary:
        text_classes.append("secondary")
    if notes:
        text_classes.append("notes")
    return (
        f"<div class='{' '.join(classes)}'>"
        f"<div class='radix-section-label'>{icon} {pyhtml.escape(title)}</div>"
        f"<div class='{' '.join(text_classes)}'>{pyhtml.escape(body).replace(chr(10), '<br>')}</div>"
        f"</div>"
    )


def _tier_chip_html(c: str) -> str:
    tier, tier_name, _, _, _ = _tier_meta_for_char(c)
    tier_cls = {1: "radix-tier-1", 2: "radix-tier-2", 3: "radix-tier-3", 4: "radix-tier-4", 5: "radix-tier-5"}.get(tier, "radix-tier-5")
    return f"<span class='radix-chip radix-tier-chip {tier_cls}'>Tier {tier}: {pyhtml.escape(tier_name)}</span>"


def _variant_script_label(char: str) -> str:
    if cc_t2s and cc_t2s.convert(char) == char and (not cc_s2t or cc_s2t.convert(char) != char):
        return "简"
    if cc_s2t and cc_s2t.convert(char) == char and (not cc_t2s or cc_t2s.convert(char) != char):
        return "繁"
    return ""


def _character_variants(c: str, meta: dict) -> list[str]:
    variants = []
    for value in [meta.get("variant")] + list(meta.get("additional_variants") or []):
        if isinstance(value, str):
            candidate = value.strip()
            if candidate and candidate != c and candidate in component_map and candidate not in variants:
                variants.append(candidate)
    if variants:
        return variants

    for candidate in [
        cc_t2s.convert(c) if cc_t2s else c,
        cc_s2t.convert(c) if cc_s2t else c,
    ]:
        if candidate and candidate != c and candidate in component_map and candidate not in variants:
            variants.append(candidate)
    return variants


def _variants_html(c: str, meta: dict) -> str:
    variants = _character_variants(c, meta)
    if not variants:
        return ""
    items = []
    for variant in variants:
        label = _variant_script_label(variant)
        script_html = f"<span class='radix-variant-script'>{pyhtml.escape(label)}</span>" if label else ""
        items.append(
            f"<span class='radix-variant-button'>{pyhtml.escape(variant)}</span>"
            f"{script_html}"
        )
    return (
        "<div class='radix-variant-row'>"
        "<span class='radix-variant-label'>Variants</span>"
        f"{''.join(items)}"
        "</div>"
    )


def _character_parts_html(c: str, meta: dict) -> str:
    decomp = clean_field(meta.get("decomposition", "")) or format_decomposition(c)
    radical = clean_field(meta.get("radical", ""))
    parts = []
    seen = set()
    for part in decomp:
        if part in IDC_CHARS_LOCAL or part in {"?", "—"} or part == c:
            continue
        if part in component_map and part not in seen:
            seen.add(part)
            parts.append(part)
    if not parts:
        return ""

    tiles = []
    for part in parts[:12]:
        pinyin = clean_field(component_map.get(part, {}).get("meta", {}).get("pinyin", ""))
        radical_cls = " radical" if radical and part == radical else ""
        tiles.append(
            f"<div class='radix-part-tile{radical_cls}'>"
            f"<div class='radix-part-char'>{pyhtml.escape(part)}</div>"
            f"<div class='radix-part-sub'>{pyhtml.escape(pinyin)}</div>"
            f"</div>"
        )
    return (
        "<div class='radix-section'>"
        "<div class='radix-section-label'>🧩 Parts</div>"
        f"<div class='radix-parts-grid'>{''.join(tiles)}</div>"
        "</div>"
    )


def generate_clean_card_html(
    c: str,
    usage_count: int = None,
    is_static: bool = False,
    minimal: bool = False,
    notes_override: str | None = None,
    show_actions: bool = True,
    show_parts: bool = True,
) -> str:
    """Generate a Radix-style character info card."""
    if not c:
        return ""
    
    info = component_map.get(c, {})
    meta = info.get("meta", {})
    pinyin = clean_field(meta.get("pinyin", ""))
    pinyin_display = pinyin if pinyin and pinyin != "—" else "—"
    strokes = info.get("stroke_count")
    usage_subtitle = ""
    if usage_count is not None:
        usage_subtitle = f"{usage_count} chars" if usage_count > 1 else "1 char"

    header = (
        "<div class='radix-info-header'>"
        "<div class='radix-info-main-tile'>"
        f"<div class='radix-info-main-char'>{pyhtml.escape(c)}</div>"
        f"<div class='radix-info-tile-sub'>{pyhtml.escape(usage_subtitle)}</div>"
        "</div>"
        "<div class='radix-info-header-body'>"
        f"<div class='radix-info-pinyin'>{pyhtml.escape(pinyin_display)}</div>"
        "</div>"
        "</div>"
    )

    actions = "" if minimal or not show_actions else (
        "<div class='radix-info-actions'>"
        "<span class='radix-action-pill'>□✎ Notes</span>"
        "<span class='radix-action-pill'>词 Phrases</span>"
        "</div>"
    )

    radical = clean_field(meta.get("radical", ""))
    decomp = format_decomposition(c)
    chips = []
    if not minimal:
        chips.append(_tier_chip_html(c))
    if decomp and decomp != "—":
        chips.append(f"<span class='radix-chip'>{pyhtml.escape(decomp)}</span>")
    if radical and radical != "—":
        chips.append(f"<span class='radix-chip'>Rad. {pyhtml.escape(radical)}</span>")
    variants_html = "" if minimal else _variants_html(c, meta)
    chips_html = f"<div class='radix-info-actions'>{''.join(chips)}</div>" if chips else ""

    parts_html = "" if minimal or not show_parts else _character_parts_html(c, meta)
    definition = clean_field(meta.get("definition", ""))
    etymology = get_etymology_text(meta)
    notes = notes_override if notes_override is not None else clean_field(meta.get("notes", ""))

    def_html = _section_html("Definition", "📕", definition, fallback="No definition")
    origin_html = _section_html("Origin", "🔎", etymology, soft=True, secondary=True)
    notes_html = _section_html("Notes", "📝", notes, soft=True, notes=True)

    return f"<div class='char-card'>{header}{actions}{variants_html}{chips_html}{parts_html}{def_html}{origin_html}{notes_html}</div>"

def render_ipad_safe_download_html(data_str: str, filename: str, label: str) -> str:
    """Build iPad-safe download link."""
    b64 = base64.b64encode(data_str.encode()).decode()
    href = f'data:application/octet-stream;base64,{b64}'
    return f'<div style="text-align:center; margin: 10px 0;"><a href="{href}" download="{filename}" target="_self" style="text-decoration: none; color: white; background-color: #d35400; padding: 12px 24px; border-radius: 12px; font-weight: 700; display: inline-block; box-shadow: 0 4px 12px rgba(211, 84, 0, 0.2); -webkit-appearance: none;">{label}</a></div>'

def render_copy_to_clipboard(prompt_text: str, widget_id: str):
    """Render copy-to-clipboard button."""
    safe_text = json.dumps(prompt_text, ensure_ascii=False)
    st_html(
        f"""<div style="display:flex; justify-content:center; margin:10px 0 0 0;"><button id="copy-btn-{widget_id}" style="padding:10px 14px; border-radius:10px; border:1px solid #ddd; background:#fff; cursor:pointer; font-weight:700;">Copy Prompt to Clipboard</button></div><div id="copy-msg-{widget_id}" style="text-align:center; margin-top:8px; color:#2e7d32; font-weight:600;"></div><script>(function() {{const text = {safe_text}; const btn = document.getElementById("copy-btn-{widget_id}"); const msg = document.getElementById("copy-msg-{widget_id}"); if (!btn) return; async function copy() {{try {{await navigator.clipboard.writeText(text); msg.textContent = "Copied. Paste into ChatGPT.";}} catch (e) {{msg.textContent = "Copy failed.";}} setTimeout(() => {{msg.textContent = "";}}, 2500);}} btn.addEventListener("click", copy);}})();</script>""",
        height=90,
    )

def _load_hanzi_writer_script() -> str:
    global _HANZI_WRITER_SCRIPT
    if _HANZI_WRITER_SCRIPT is not None:
        return _HANZI_WRITER_SCRIPT
    try:
        with open(HANZI_WRITER_JS_PATH, "r", encoding="utf-8") as f:
            _HANZI_WRITER_SCRIPT = f.read()
    except Exception:
        _HANZI_WRITER_SCRIPT = ""
    return _HANZI_WRITER_SCRIPT

def _stroke_db_connection():
    global _STROKE_DB_CONN
    if _STROKE_DB_CONN is not None:
        return _STROKE_DB_CONN
    if not os.path.exists(STROKE_DB_PATH):
        return None
    try:
        _STROKE_DB_CONN = sqlite3.connect(STROKE_DB_PATH, check_same_thread=False)
        return _STROKE_DB_CONN
    except Exception:
        return None

def get_stroke_data_json(char: str) -> str | None:
    """Read Radix-bundled HanziWriter stroke JSON for one character."""
    char = (char or "").strip()[:1]
    if not char:
        return None
    conn = _stroke_db_connection()
    if not conn:
        return None
    try:
        row = conn.execute("SELECT data FROM strokes WHERE character = ? LIMIT 1", (char,)).fetchone()
        return row[0] if row else None
    except Exception:
        return None

def get_stroke_animation_html(char: str, size: int = 140, *, element_key: str = "", show_status: bool = False) -> tuple[str, int]:
    """Build an offline-friendly HanziWriter animation using Radix bundled resources."""
    char = (char or "").strip()[:1]
    if not char:
        return "", 0
    script = _load_hanzi_writer_script()
    stroke_data = get_stroke_data_json(char)
    unique = hashlib.md5(f"{element_key}:{char}:{size}:{uuid.uuid4()}".encode()).hexdigest()[:12]
    target_id = f"hw-{unique}"
    status = "" if stroke_data else "No stroke animation available"
    status_html = f"<div style='min-height:14px; font-size:11px; color:#777; text-align:center; line-height:1.2;'>{pyhtml.escape(status) if show_status else ''}</div>"
    stroke_literal = stroke_data if stroke_data else "null"
    fallback_size = int(size * 0.72)
    html_content = f"""
    <div style="display:flex; align-items:center; justify-content:center; width:100%; min-height:{size + 18}px;">
      <div>
        <div id="{target_id}" style="width:{size}px; height:{size}px; margin:auto;"></div>
        {status_html}
      </div>
    </div>
    <script>
    (function() {{
      const ch = {json.dumps(char, ensure_ascii=False)};
      const size = {size};
      const bundledData = {stroke_literal};
      const target = document.getElementById({json.dumps(target_id)});
      function fallback() {{
        if (!target) return;
        target.innerHTML = `<div style="width:${{size}}px;height:${{size}}px;display:flex;align-items:center;justify-content:center;font-size:{fallback_size}px;color:#222;">${{ch}}</div>`;
      }}
      try {{
        {script}
        if (!target || !bundledData || typeof HanziWriter === "undefined") {{
          fallback();
          return;
        }}
        const writer = HanziWriter.create({json.dumps(target_id)}, ch, {{
          width: size,
          height: size,
          padding: 5,
          showOutline: true,
          strokeAnimationSpeed: 1.2,
          delayBetweenStrokes: 120,
          delayBetweenLoops: 800,
          charDataLoader: function(character, onComplete, onError) {{
            onComplete(bundledData);
          }}
        }});
        writer.loopCharacterAnimation();
      }} catch (e) {{
        fallback();
      }}
    }})();
    </script>
    """
    return html_content, size + (26 if show_status else 18)

def get_phrase_animation_grid_html(chars: list[str], size: int = 108, *, element_key: str = "") -> tuple[str, int]:
    """Build a single iframe-safe animation grid for phrase characters."""
    cleaned = [(c or "").strip()[:1] for c in chars if isinstance(c, str) and (c or "").strip()]
    cleaned = cleaned[:4]
    if not cleaned:
        return "", 0

    script = _load_hanzi_writer_script()
    unique = hashlib.md5(f"{element_key}:{''.join(cleaned)}:{size}:{uuid.uuid4()}".encode()).hexdigest()[:12]
    items = []
    for idx, char in enumerate(cleaned):
        strokes = component_map.get(char, {}).get("stroke_count")
        stroke_text = ""
        if strokes:
            stroke_text = f"{strokes} {'stroke' if strokes == 1 else 'strokes'}"
        items.append(
            {
                "char": char,
                "target": f"phrase-hw-{unique}-{idx}",
                "data": json.loads(get_stroke_data_json(char) or "null"),
                "strokeText": stroke_text,
            }
        )

    grid_cells = "".join(
        f"""
        <div class="phrase-cell">
          <div class="phrase-strokes">{pyhtml.escape(item["strokeText"]) or "&nbsp;"}</div>
          <div id="{item["target"]}" class="phrase-target"></div>
        </div>
        """
        for item in items
    )
    payload = json.dumps(items, ensure_ascii=False)
    fallback_size = int(size * 0.62)
    html_content = f"""
    <style>
      .phrase-grid-{unique} {{
        display:grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap:10px;
        width:100%;
      }}
      .phrase-grid-{unique} .phrase-cell {{
        border:1px solid #d9dee7;
        border-radius:8px;
        background:#fff;
        padding:8px;
        text-align:center;
      }}
      .phrase-grid-{unique} .phrase-strokes {{
        min-height:16px;
        font-size:11px;
        font-weight:650;
        color:#334155;
        line-height:1.2;
      }}
      .phrase-grid-{unique} .phrase-target {{
        width:{size}px;
        height:{size}px;
        margin:2px auto;
      }}
    </style>
    <div class="phrase-grid-{unique}">{grid_cells}</div>
    <script>
    (function() {{
      const items = {payload};
      const size = {size};
      function fallback(target, ch) {{
        if (!target) return;
        target.innerHTML = `<div style="width:${{size}}px;height:${{size}}px;display:flex;align-items:center;justify-content:center;font-size:{fallback_size}px;color:#222;">${{ch}}</div>`;
      }}
      try {{
        {script}
        items.forEach(function(item) {{
          const target = document.getElementById(item.target);
          if (!target || !item.data || typeof HanziWriter === "undefined") {{
            fallback(target, item.char);
            return;
          }}
          const writer = HanziWriter.create(item.target, item.char, {{
            width: size,
            height: size,
            padding: 5,
            showOutline: true,
            strokeAnimationSpeed: 1.2,
            delayBetweenStrokes: 120,
            delayBetweenLoops: 800,
            charDataLoader: function(character, onComplete, onError) {{
              onComplete(item.data);
            }}
          }});
          writer.loopCharacterAnimation();
        }});
      }} catch (e) {{
        items.forEach(function(item) {{
          fallback(document.getElementById(item.target), item.char);
        }});
      }}
    }})();
    </script>
    """
    rows = 1 if len(items) <= 2 else 2
    return html_content, rows * (size + 36) + 10

def get_stroke_order_sidebar_html(char: str, size: int = 140) -> tuple[str, int]:
    """Build sidebar stroke order HTML with Radix bundled animation data."""
    char = (char or "").strip()[:1]
    if not char:
        return "", 0
    
    pinyin = clean_field(component_map.get(char, {}).get("meta", {}).get("pinyin", ""))
    anim_html, anim_height = get_stroke_animation_html(char, size=size, element_key="sidebar", show_status=True)
    html_content = f"""
    <div style="display:flex; flex-direction:column; align-items:center; margin:12px 0;">
      <div style="text-align:center; font-size:1.4rem; font-weight:700; color:#c0392b; font-family:'Lora',serif; font-style:italic; margin-bottom:6px;">{pyhtml.escape(pinyin)}</div>
      {anim_html}
    </div>
    """
    return html_content, anim_height + 56

def render_learning_insights_html(char: str) -> tuple[str, int, str]:
    """Render the Logic/Analysis box. Returns (html, height, prompt_text)."""
    if not char: 
        return "", 0, ""
    
    analysis = analyze_component_structure(char)
    sem = analysis.get("semantic")
    pho = analysis.get("phonetic")
    pho_pinyin = analysis.get("phonetic_pinyin", "")
    is_match = analysis.get("is_sound_match")
    
    if not sem and not pho:
        return "", 0, ""

    # Get data for prompt
    decomposition = component_map.get(char, {}).get("meta", {}).get("decomposition", "None")
    def_en = get_char_definition_en(char) or "None"
    p_fam = get_pronunciation_family(char)
    s_fam = get_semantic_family(char)
    
    unique_id = hashlib.md5(char.encode()).hexdigest()[:8]

    # Build HTML components piece by piece
    html_parts = []
    
    # 1. Component Roles section
    html_parts.append('<div style="margin-bottom:20px;">')
    if sem:
        html_parts.append(f'<div class="role-badge role-semantic">💡 {pyhtml.escape(sem)} : Meaning (Radical)</div>')
    if pho:
        match_icon = "📊" if is_match else "🗣️"
        match_text = "Sound Match" if is_match else "Sound Component"
        pinyin_display = f" ({pyhtml.escape(pho_pinyin)})" if pho_pinyin else ""
        html_parts.append(f'<div class="role-badge role-phonetic">{match_icon} {pyhtml.escape(pho)}{pinyin_display} : {match_text}</div>')
    html_parts.append('</div>')
    
    # 2. Sound Family section
    if pho and p_fam:
        html_parts.append('<div style="margin-bottom:15px;">')
        html_parts.append(f'<div style="font-size:0.82em; font-weight:700; color:#6b5e52; margin-bottom:5px; text-transform:uppercase; letter-spacing:0.04em;">📊 SOUND FAMILY (share {pyhtml.escape(pho)}):</div>')
        html_parts.append('<div class="family-list">')
        for c in p_fam:
            html_parts.append(f'<span class="family-char">{pyhtml.escape(c)}</span>')
        html_parts.append('</div>')
        html_parts.append('</div>')
    
    # 3. Meaning Family section
    if sem and s_fam:
        html_parts.append('<div style="margin-bottom:15px;">')
        html_parts.append(f'<div style="font-size:0.82em; font-weight:700; color:#6b5e52; margin-bottom:5px; text-transform:uppercase; letter-spacing:0.04em;">💡 MEANING FAMILY (share {pyhtml.escape(sem)}):</div>')
        html_parts.append('<div class="family-list">')
        for c in s_fam:
            html_parts.append(f'<span class="family-char">{pyhtml.escape(c)}</span>')
        html_parts.append('</div>')
        html_parts.append('</div>')

    # Build prompt text  
    lines = [
        "Task 4 — Logic & Pattern Tutor (From App Fields)",
        "",
        "You are a Chinese character structure tutor. Explain Radix's \"Character Logic & Patterns\" panel clearly and conservatively.",
        "Do not invent etymology; if uncertain, say so. Do not assume any prior tasks have been run.",
        "",
        "INPUT (fields provided by the app):",
        f"- char: {char}",
        f"- def_en: {def_en}",
        f"- decomposition: {decomposition}",
        f"- semantic: {sem or 'None'}",
        f"- phonetic: {pho or 'None'}",
        f"- phonetic_pinyin: {pho_pinyin or 'None'}",
        f"- is_sound_match: {is_match}",
        f"- pronunciation_family: {', '.join(p_fam) if p_fam else 'None'}",
        f"- semantic_family: {', '.join(s_fam) if s_fam else 'None'}",
        "",
        "TASK:",
        "Explain (1) why semantic vs phonetic were assigned, and (2) what the two families mean,",
        "INCLUDING checking for false friends in pronunciation_family (e.g., visual matches caused by simplification).",
        "",
        "OUTPUT:",
        "",
        "1) Component Roles",
        "- If semantic exists: what meaning cue it suggests (1–2 lines).",
        "- If phonetic exists: what sound cue it suggests (1–2 lines).",
        "- Interpret is_sound_match:",
        "  - True: strong phonetic cue in modern Mandarin.",
        "  - False: candidate phonetic component but modern sound mismatch; give 1–2 plausible reasons only if confident.",
        "",
        f"2) Pronunciation Family (share {pho or 'None'})",
        "For each character in pronunciation_family, output ONE line:",
        "- Character: Classification (Likely true member / Visual only / Simplification artefact / Uncertain) — reason (<= 15 words).",
        "Then add ONE summary sentence: label as \"Sound family\" or safer \"Component family.\"",
        "",
        f"3) Meaning Family (share {sem or 'None'})",
        f"- 1–2 sentence theme of what {sem or 'the semantic component'} often signals in modern characters.",
        "- For each character in semantic_family: one short line on how the theme plausibly applies (no overclaiming).",
        "",
        "4) Learner Takeaway (max 2 bullets)",
        "- One rule-of-thumb about radicals (meaning cues).",
        "- One rule-of-thumb about phonetics (sound cues + why false friends occur).",
        "",
        "5) UI Tooltip Copy",
        "- Tooltip for \"Meaning (Radical)\" (<= 18 words)",
        "- Tooltip for \"Sound Match / Sound Component\" (<= 18 words)"
    ]
    prompt_full = "\n".join(lines)

    # Assemble final HTML
    content = ''.join(html_parts)
    
    full_html = f"""<style>
.insight-box {{background: #fff; border: 1px solid #e8e2d8; border-radius: 10px; padding: 18px; box-shadow: 0 1px 3px rgba(26,20,16,0.08);}}
.insight-title {{font-weight: 800; color: #1a1410; font-size: 1.05em; margin-bottom: 13px; font-family: 'Noto Serif SC', serif;}}
.role-badge {{display: inline-flex; align-items: center; padding: 5px 11px; border-radius: 6px; font-size: 0.88em; font-weight: 600; margin-right: 9px; margin-bottom: 7px;}}
.role-semantic {{background: #e3ede9; color: #2a6b55; border: 1px solid #a0c4b8;}}
.role-phonetic {{background: #e4eaf5; color: #2e4a7a; border: 1px solid #c4cedf;}}
.family-list {{display: flex; gap: 8px; flex-wrap: wrap; margin-top: 7px;}}
.family-char {{font-size: 1.35em; color: #3d342a; padding: 2px 8px; background: #f3efe8; border-radius: 6px; border: 1px solid #e8e2d8; font-family: 'Noto Serif SC', serif;}}
</style>
<div class="insight-box">
<div class="insight-title">🧠 Character Logic & Patterns</div>
{content}
</div>"""
    
    base_height = 200
    if p_fam: base_height += 80
    if s_fam: base_height += 80
    
    return full_html, base_height, prompt_full

# Add to radix_ui.py
def render_session_heartbeat():
    """Invisible component that keeps session alive"""
    st_html("""
    <script>
        // Ping the server every 60 seconds
        setInterval(() => {
            fetch(window.location.href, {
                method: 'GET',
                headers: {'Cache-Control': 'no-cache'}
            }).catch(e => console.log('Heartbeat failed:', e));
        }, 60000); // Every 60 seconds
    </script>
    """, height=0)

# Call this in render_sidebar() or main()


# ==================== UI COMPONENTS ====================

def render_definition_search_ui(key_prefix: str):
    """Render definition search interface."""
    st.markdown("**English Definition Search**")
    key = f"{key_prefix}_def_search"
    st.text_input("Search definitions", key=key, placeholder="e.g., water, fire, mountain", label_visibility="collapsed")
    return key  # Return key so caller can check the value
