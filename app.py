# app.py
# Main Streamlit app for Radix - WITH AUTO-LOAD OF radix_user_data.json

import streamlit as st
from radix_embed import html as st_html
import math
import html as pyhtml
import uuid
import re
import unicodedata
import os
import json
import time
import radix_core as rc
from radix_core import (
    component_map, get_db_connection, batch_get_phrase_details,
    search_phrases_by_definition, get_stroke_count, component_usage_count,
    apply_script_filter, get_char_definition_en, render_combined_prompt,
    get_stroke_order_view_html, SCRIPT_FILTERS, IDC_CHARS,
    sort_key_usage_primary, sort_key_frequency_primary, stats_cache,
    cc_t2s, cc_s2t, analyze_component_structure, clean_field
)
from radix_state import (
    StateManager, ConfigManager, InputValidator,
    PAGE_CONFIG, PAGE_SIZE, GRID_COLUMNS, PROFILE_FILENAME, PROFILE_SCHEMA_VERSION
)
from radix_ui import (
    apply_styles, generate_clean_card_html, render_ipad_safe_download_html,
    render_copy_to_clipboard,
    render_learning_insights_html, get_stroke_animation_html,
    get_phrase_animation_grid_html
)
from radix_persistence import PersistenceManager
from server import create_editable_copy, save_json_copy, build_download_payload
from radix_backup import (
    BackupValidationError,
    all_phrase_details,
    backup_summary,
    collection_summaries,
    export_backup_package,
    export_validation_summary,
    load_backup,
    load_radix_json_bytes,
    phrase_details_map,
)


# Configure Streamlit
st.set_page_config(**PAGE_CONFIG)
apply_styles()

# Initialize managers
state = StateManager()
config = ConfigManager(state)
persistence = PersistenceManager(state)
DEFAULT_COMPONENT_MAP_FILE = "enhanced_component_map_with_etymology.json"
DEFAULT_SAMPLE_BACKUP_FILE = "radix_unified_backup.json"
NAV_ICON_ONLY_LABEL = "\u200b"
APP_LOGO_PATH = "radix_logo.png"


# ==================== HELPERS ====================

def normalize_pinyin(pinyin_str, *, fuzzy_initials: bool = True, preserving_spaces: bool = False):
    """Match Radix's pinyin normalization: strip tones, compact, and optionally fuzz zh/sh/ch."""
    if not isinstance(pinyin_str, str):
        return ""
    stripped = ''.join(c for c in unicodedata.normalize('NFD', pinyin_str.lower()) if unicodedata.category(c) != 'Mn')
    words = []
    current = []
    for ch in stripped:
        if ch.isalpha() or ch.isdigit():
            current.append(ch)
        elif current:
            words.append("".join(current))
            current = []
    if current:
        words.append("".join(current))

    if fuzzy_initials:
        mapped = []
        for word in words:
            if word.startswith("zh"):
                word = "z" + word[2:]
            elif word.startswith("sh"):
                word = "s" + word[2:]
            elif word.startswith("ch"):
                word = "c" + word[2:]
            mapped.append(word)
        words = mapped

    return " ".join(words) if preserving_spaces else "".join(words)


TIER_NAMES = {
    1: "Core Literacy",
    2: "Fluency Core",
    3: "Educated Native",
    4: "Academic/Pro",
    5: "Niche/Rare",
}

TIER_RECOMMENDATION = {
    1: "Essential",
    2: "Required",
    3: "Recommended",
    4: "Optional",
    5: "Ignore",
}


def _base_tier_from_rank(rank: int, has_freq: bool) -> int:
    # Fixed bucket definition requested by user.
    # Tier 1: top 1500, Tier 2: next 1500, Tier 3: next 1000, Tier 4: next 1000, Tier 5: rest.
    if not has_freq:
        return 5
    if rank <= 1500:
        return 1
    if rank <= 3000:
        return 2
    if rank <= 4000:
        return 3
    if rank <= 5000:
        return 4
    return 5


def _compute_tier_metrics() -> dict[str, dict]:
    freq_pairs = []
    for ch, info in component_map.items():
        freq = float(info.get("freq_per_million", 0.0) or 0.0)
        freq_pairs.append((ch, max(freq, 0.0)))

    ranked_freq = sorted(freq_pairs, key=lambda x: (-x[1], x[0]))
    rank_map = {}
    coverage_map = {}

    total_freq = sum(v for _, v in ranked_freq if v > 0)
    cumulative = 0.0
    current_rank = 0
    for ch, freq in ranked_freq:
        if freq > 0:
            current_rank += 1
            rank_map[ch] = current_rank
            cumulative += freq
            coverage_map[ch] = (cumulative / total_freq * 100.0) if total_freq else 0.0
        else:
            rank_map[ch] = len(component_map) + 1
            coverage_map[ch] = 100.0

    metrics = {}
    for ch, _ in ranked_freq:
        rank = int(rank_map.get(ch, len(component_map) + 1))
        has_freq = rank <= len(component_map)
        tier = _base_tier_from_rank(rank, has_freq)

        notes = []
        if cc_t2s and cc_s2t:
            simp = cc_t2s.convert(ch)
            trad = cc_s2t.convert(ch)
            if simp != trad:
                notes.append(f"Forms: {simp} / {trad}")

        metrics[ch] = {
            "tier": tier,
            "tier_name": TIER_NAMES[tier],
            "base_frequency_rank": rank,
            "coverage_pct": round(float(coverage_map.get(ch, 100.0)), 2),
            "recommendation": TIER_RECOMMENDATION[tier],
            "notes": "; ".join(notes) if notes else "",
            "sort_key": (tier, rank, ch),
        }

    return metrics


def auto_load_user_data():
    """
    Automatically load radix_user_data.json on startup if it exists.
    This replaces the manual upload process with automatic loading.
    """
    # Only load once per session
    if state.get("auto_load_attempted"):
        return
    
    state.set("auto_load_attempted", True)
    
    # Check if file exists
    if not os.path.exists(PROFILE_FILENAME):
        return
    
    try:
        with open(PROFILE_FILENAME, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        # Validate schema
        if not isinstance(data, dict) or data.get("schema_version") != PROFILE_SCHEMA_VERSION:
            st.warning(f"⚠️ Found {PROFILE_FILENAME} but schema version mismatch. Skipping auto-load.")
            return
        
        # Import the data
        config.import_profile_dict(data)
        
        # Show success message
        favs_count = len(data.get("favourites_list", []))
        if favs_count > 0:
            st.toast(f"✅ Auto-loaded profile: {favs_count} favourites restored", icon="💾")
        else:
            st.toast(f"✅ Auto-loaded profile from {PROFILE_FILENAME}", icon="💾")
            
    except json.JSONDecodeError:
        st.error(f"❌ Error: {PROFILE_FILENAME} contains invalid JSON")
    except Exception as e:
        st.error(f"❌ Error loading {PROFILE_FILENAME}: {e}")


def auto_load_sample_memory():
    """Seed the memory strip from the permanent sample backup when no profile has supplied it."""
    if state.get("sample_memory_load_attempted"):
        return
    state.set("sample_memory_load_attempted", True)

    if state.get_remembered() or not os.path.exists(DEFAULT_SAMPLE_BACKUP_FILE):
        return

    try:
        with open(DEFAULT_SAMPLE_BACKUP_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        profile = data.get("profile", {}) if isinstance(data, dict) else {}
        remembered = profile.get("remembered_list", []) if isinstance(profile, dict) else []
        if not isinstance(remembered, list):
            return

        for char in reversed(remembered):
            if isinstance(char, str):
                state.remember_character(char)

        if state.get_remembered():
            st.toast(f"Loaded {len(state.get_remembered())} remembered characters from sample backup", icon="✅")
    except Exception as e:
        st.warning(f"Could not load sample backup memory: {e}")


def set_active_backup(backup: dict, source_name: str, *, is_sample: bool = False) -> None:
    """Store the active Radix backup working copy for browse/search/export."""
    st.session_state["active_backup"] = backup
    st.session_state["active_backup_source"] = source_name
    st.session_state["active_backup_is_sample"] = is_sample
    st.session_state["active_backup_dirty"] = False
    st.session_state["active_backup_dirty_at"] = None
    st.session_state["active_backup_summary"] = backup_summary(backup, source_name)
    profile = backup.get("profile", {}) if isinstance(backup.get("profile"), dict) else {}
    if not state.get_phrase_favourites() and isinstance(profile.get("favourite_phrases_list"), list):
        state.set("favourite_phrases_list", [p for p in profile.get("favourite_phrases_list", []) if isinstance(p, str)])


def get_active_backup() -> dict | None:
    backup = st.session_state.get("active_backup")
    return backup if isinstance(backup, dict) else None


def auto_load_sample_backup():
    """Use the bundled Radix backup as the default working copy until replaced."""
    if st.session_state.get("active_backup_load_attempted"):
        return
    st.session_state["active_backup_load_attempted"] = True

    if get_active_backup() or not os.path.exists(DEFAULT_SAMPLE_BACKUP_FILE):
        return

    try:
        backup = load_backup(DEFAULT_SAMPLE_BACKUP_FILE)
        set_active_backup(backup, DEFAULT_SAMPLE_BACKUP_FILE, is_sample=True)
        st.toast("Loaded permanent sample Radix backup", icon="✅")
    except Exception as e:
        st.warning(f"Could not load sample Radix backup: {e}")


def get_phrase_details(words, conn=None) -> dict:
    """Merge base phrase DB records with phrase records from the active backup."""
    merged = {}
    if conn:
        merged.update(batch_get_phrase_details(words, conn) or {})
    backup = get_active_backup()
    if backup:
        merged.update(phrase_details_map(backup, words))
    for word, item in list(merged.items()):
        if isinstance(item, dict) and not item.get("word"):
            item["word"] = word
    return merged


def _phrase_lookup_target(text: str) -> str:
    clean = (text or "").strip()
    if not clean:
        return ""
    simplified = cc_t2s.convert(clean).strip() if cc_t2s else clean
    return simplified or clean


def _phrase_storage_word(word: str) -> str:
    return _phrase_lookup_target(word)


def _browse_page_display_text(text: str) -> str:
    mode = state.get("browse_page_script_mode", "simplified")
    if mode == "traditional" and cc_s2t:
        return cc_s2t.convert(text)
    if mode == "simplified" and cc_t2s:
        return cc_t2s.convert(text)
    return text


def _browse_page_tile_label(text: str, pinyin: str = "") -> str:
    display_text = _browse_page_display_text(text)
    pinyin = (pinyin or "").strip()
    if not pinyin and len(display_text) == 1:
        pinyin = clean_field(component_map.get(display_text, {}).get("meta", {}).get("pinyin", ""))
    return f"{display_text}\n{pinyin}" if pinyin else display_text


BROWSE_PAGE_COLUMNS = 12
BROWSE_PAGE_SIZE = 240


def _max_base_phrase_length(conn=None, fallback: int = 7) -> int:
    try:
        db = conn or get_db_connection()
        cursor = db.cursor()
        cursor.execute("SELECT MAX(LENGTH(word)) FROM phrases")
        value = cursor.fetchone()[0]
        return max(fallback, int(value or fallback))
    except Exception:
        return fallback


def _page_candidate_words(collection: dict, max_phrase_length: int, start_idx: int = 0, end_idx: int | None = None) -> set[str]:
    chars = collection.get("characters") or []
    end_idx = len(chars) if end_idx is None else min(end_idx, len(chars))
    lookup_chars = [_phrase_lookup_target(c) for c in chars[max(0, start_idx):end_idx]]
    words: set[str] = set()
    for offset in range(len(lookup_chars)):
        max_length = min(max_phrase_length, len(lookup_chars) - offset)
        if max_length < 2:
            continue
        for length in range(2, max_length + 1):
            words.add("".join(lookup_chars[offset:offset + length]))
    return words


def _fetch_page_phrase_lookup(collection: dict, max_phrase_length: int, conn=None, start_idx: int = 0, end_idx: int | None = None) -> dict[str, dict]:
    candidate_words = _page_candidate_words(collection, max_phrase_length, start_idx, end_idx)
    if not candidate_words:
        return {}

    lookup: dict[str, dict] = {}
    db = conn or get_db_connection()
    words = sorted(candidate_words)
    chunk_size = 400
    for start in range(0, len(words), chunk_size):
        chunk = words[start:start + chunk_size]
        placeholders = ",".join("?" for _ in chunk)
        try:
            rows = db.execute(
                f"SELECT word, pinyin, meanings FROM phrases WHERE word IN ({placeholders})",
                chunk,
            ).fetchall()
        except Exception:
            rows = []
        for word, pinyin, meanings in rows:
            phrase = {"word": word, "pinyin": pinyin or "", "meanings": meanings or "", "notes": "", "review_status": ""}
            lookup[_phrase_lookup_target(word)] = phrase

    backup = get_active_backup()
    if backup:
        for phrase in all_phrase_details(backup):
            word = phrase.get("word", "")
            key = _phrase_lookup_target(_phrase_storage_word(word))
            if key in candidate_words:
                lookup[key] = phrase
    return lookup


def _ordered_unique(values: list) -> list:
    out = []
    seen = set()
    for value in values:
        key = value.get("word") if isinstance(value, dict) else value
        if key in seen:
            continue
        seen.add(key)
        out.append(value)
    return out


def _parse_radix_search_query(raw_query: str) -> tuple[str, bool]:
    trimmed = (raw_query or "").strip()
    has_equal_prefix = trimmed.startswith("=")
    quote_pairs = [("'", "'"), ('"', '"'), ("\u2018", "\u2019"), ("\u201c", "\u201d")]
    has_quotes = any(trimmed.startswith(a) and trimmed.endswith(b) and len(trimmed) >= 2 for a, b in quote_pairs)
    if has_equal_prefix:
        return trimmed[1:].strip(), True
    if has_quotes:
        return trimmed[1:-1].strip(), True
    return trimmed, False


def _component_pinyin_list(info: dict) -> list[str]:
    meta = info.get("meta", {}) if isinstance(info, dict) else {}
    pinyin = meta.get("pinyin", [])
    if isinstance(pinyin, list):
        return [p for p in pinyin if isinstance(p, str) and p.strip()]
    if isinstance(pinyin, str) and pinyin.strip():
        return [pinyin]
    return []


def _component_searchable_text(char: str, info: dict) -> str:
    meta = info.get("meta", {}) if isinstance(info, dict) else {}
    etymology = meta.get("etymology", {}) if isinstance(meta.get("etymology"), dict) else {}
    parts = [
        char,
        ", ".join(_component_pinyin_list(info)),
        meta.get("definition", ""),
        meta.get("decomposition", "") or meta.get("idc", ""),
        meta.get("radical", ""),
        etymology.get("hint", ""),
        etymology.get("details", ""),
        meta.get("notes", ""),
        active_backup_character_notes(char),
    ]
    return " ".join([p for p in parts if isinstance(p, str)]).lower()


def radix_smart_character_search(query: str, limit: int = 300, script_filter: str = "Any") -> list[str]:
    """Port Radix smart character ranking from ComponentSearchEngine."""
    if not query:
        return apply_script_filter(list(component_map.keys()), script_filter)[:limit]

    normalized = query.lower().strip()
    exact_pinyin_query = normalize_pinyin(query, fuzzy_initials=False)
    fuzzy_pinyin_query = normalize_pinyin(query, fuzzy_initials=True)

    if len(normalized) == 1 and normalized in component_map:
        return apply_script_filter([normalized], script_filter)[:limit]

    direct = [query] if query in component_map else []
    direct = apply_script_filter(direct, script_filter)

    ranked = []
    for char, info in component_map.items():
        if script_filter != "Any" and char not in apply_script_filter([char], script_filter):
            continue

        exact_tokens = [normalize_pinyin(p, fuzzy_initials=False) for p in _component_pinyin_list(info)]
        exact_tokens = [p for p in exact_tokens if p]
        exact_compact = "".join(exact_tokens)
        fuzzy_tokens = [normalize_pinyin(p, fuzzy_initials=True) for p in _component_pinyin_list(info)]
        fuzzy_tokens = [p for p in fuzzy_tokens if p]
        fuzzy_compact = "".join(fuzzy_tokens)

        match = None
        if exact_pinyin_query:
            for token in exact_tokens:
                if token == exact_pinyin_query:
                    match = (0, len(token), token)
                    break
            if match is None:
                for token in exact_tokens:
                    if token.startswith(exact_pinyin_query):
                        match = (1, len(token), token)
                        break
            if match is None:
                for token in exact_tokens:
                    if exact_pinyin_query in token:
                        match = (2, len(token), token)
                        break
            if match is None and exact_pinyin_query in exact_compact:
                match = (3, len(exact_compact), exact_compact)

        if match is None and fuzzy_pinyin_query:
            for token in fuzzy_tokens:
                if token == fuzzy_pinyin_query:
                    match = (4, len(token), token)
                    break
            if match is None:
                for token in fuzzy_tokens:
                    if token.startswith(fuzzy_pinyin_query):
                        match = (5, len(token), token)
                        break
            if match is None:
                for token in fuzzy_tokens:
                    if fuzzy_pinyin_query in token:
                        match = (6, len(token), token)
                        break
            if match is None and fuzzy_pinyin_query in fuzzy_compact:
                match = (7, len(fuzzy_compact), fuzzy_compact)

        if match is None and normalized in _component_searchable_text(char, info):
            match = (8, 999, "")

        if match is not None:
            freq_key = sort_key_frequency_primary(char)
            ranked.append((match[0], match[1], freq_key, char))

    ranked_chars = [item[3] for item in sorted(ranked, key=lambda x: (x[0], x[1], x[2]))]
    return _ordered_unique(direct + ranked_chars)[:limit]


def radix_definition_character_search(query: str, *, is_strict: bool = False, limit: int = 120, script_filter: str = "Any") -> list[str]:
    normalized = (query or "").lower().strip()
    if len(normalized) < 2:
        return []
    results = []
    for char, info in component_map.items():
        if script_filter != "Any" and char not in apply_script_filter([char], script_filter):
            continue
        definition = info.get("meta", {}).get("definition", "")
        if not isinstance(definition, str):
            continue
        definition = definition.lower()
        if is_strict:
            pattern = r"\b" + re.escape(normalized) + r"\b"
            if re.search(pattern, definition):
                results.append(char)
        elif normalized in definition:
            results.append(char)
        if len(results) >= limit:
            break
    return results


def _sort_phrases_by_pinyin(phrases: list[dict]) -> list[dict]:
    return sorted(
        phrases,
        key=lambda p: (
            normalize_pinyin(p.get("pinyin", ""), fuzzy_initials=True),
            p.get("pinyin", ""),
            p.get("word", ""),
        ),
    )


def search_phrase_meanings(query: str, conn=None, limit: int = 120, *, is_strict: bool = False) -> list[dict]:
    """Search phrase meanings/notes like Radix, merging base DB and active backup."""
    normalized = (query or "").strip()
    if len(normalized) < 2:
        return []
    results = []
    seen = set()
    if conn:
        base_limit = max(limit, 200) if is_strict else limit
        for item in search_phrases_by_definition(normalized, conn, limit=base_limit) or []:
            word = item.get("word")
            meanings = item.get("meanings", "")
            if is_strict and not _phrase_text_matches_meaning(normalized, meanings, ""):
                continue
            if word and word not in seen:
                results.append(item)
                seen.add(word)
                if len(results) >= limit:
                    break

    q = normalized.lower()
    if q:
        for item in all_phrase_details(get_active_backup() or {}):
            word = item.get("word")
            meanings = item.get("meanings", "")
            notes = item.get("notes", "")
            matches = _phrase_text_matches_meaning(normalized, meanings, notes) if is_strict else q in " ".join([meanings, notes]).lower()
            if word and word not in seen and matches:
                results.append(item)
                seen.add(word)
                if len(results) >= limit:
                    break
    return _sort_phrases_by_pinyin(results[:limit])


def _phrase_text_matches_meaning(term: str, meanings: str, notes: str = "") -> bool:
    target = term.lower().strip()
    if not target:
        return False
    for value in (meanings, notes):
        if not isinstance(value, str):
            continue
        text = value.lower().strip()
        if text == target:
            return True
        pattern = r"(^|\s)" + re.escape(target) + r"(\s|$)"
        if re.search(pattern, text):
            return True
    return False


def search_backup_phrase_pinyin(query_norm: str, limit: int = 200) -> list[dict]:
    """Search active-backup phrases by normalized pinyin."""
    results = []
    for item in all_phrase_details(get_active_backup() or {}):
        pinyin = item.get("pinyin", "")
        if not pinyin:
            continue
        phrase_pinyin_norm = normalize_pinyin(pinyin)
        if query_norm in phrase_pinyin_norm or query_norm.replace(" ", "") in phrase_pinyin_norm.replace(" ", ""):
            results.append(item)
            if len(results) >= limit:
                break
    return results


def search_phrase_pinyin(query: str, conn=None, limit: int = 120) -> list[dict]:
    """Search phrase pinyin with Radix-style compact normalized matching."""
    query_norm = normalize_pinyin(query)
    if len(query_norm) <= 2:
        return []
    results = []
    seen = set()
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT word, pinyin, meanings FROM phrases WHERE pinyin IS NOT NULL")
            for word, pinyin, meanings in cursor.fetchall():
                phrase_pinyin_norm = normalize_pinyin(pinyin)
                if query_norm in phrase_pinyin_norm and word not in seen:
                    results.append({"word": word, "pinyin": pinyin, "meanings": meanings})
                    seen.add(word)
                    if len(results) >= limit:
                        break
        except Exception:
            pass
    for phrase in search_backup_phrase_pinyin(query_norm, limit=limit):
        word = phrase.get("word")
        if word and word not in seen:
            results.append(phrase)
            seen.add(word)
            if len(results) >= limit:
                break
    return _sort_phrases_by_pinyin(results[:limit])


def merge_phrase_results(primary: list[dict], secondary: list[dict], limit: int = 120) -> list[dict]:
    return _ordered_unique((primary or []) + (secondary or []))[:limit]


def _cocoa_timestamp() -> float:
    """Return seconds since Apple's 2001 reference date, matching Radix Date JSON."""
    return time.time() - 978307200


def refresh_active_backup_summary() -> None:
    backup = get_active_backup()
    if backup:
        st.session_state["active_backup_summary"] = backup_summary(
            backup,
            st.session_state.get("active_backup_source", "Working backup"),
        )


def mark_active_backup_dirty() -> None:
    if get_active_backup():
        st.session_state["active_backup_dirty"] = True
        st.session_state["active_backup_dirty_at"] = _cocoa_timestamp()


def _notes_to_text(value) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        parts = []
        for item in value:
            if isinstance(item, str):
                text = item.strip()
            elif isinstance(item, dict):
                text = str(item.get("text") or item.get("note") or item.get("content") or "").strip()
            else:
                text = str(item or "").strip()
            if text:
                parts.append(text)
        return "\n".join(parts)
    return str(value or "").strip()


def _text_to_notes_list(text: str) -> list[str]:
    clean = (text or "").strip()
    return [clean] if clean else []


def active_backup_character_notes(char: str) -> str:
    backup = get_active_backup()
    if not backup or not char:
        return ""

    overlay = backup.get("dictionary_patch_overlay")
    overlay = overlay if isinstance(overlay, dict) else {}

    for patch in reversed(overlay.get("patches") or []):
        if not isinstance(patch, dict) or patch.get("character") != char:
            continue
        meta = patch.get("meta") if isinstance(patch.get("meta"), dict) else {}
        if "notes" in meta:
            return _notes_to_text(meta.get("notes"))

    custom_entries = overlay.get("custom_entries") if isinstance(overlay.get("custom_entries"), dict) else {}
    custom = custom_entries.get(char) if isinstance(custom_entries, dict) else None
    custom_meta = custom.get("meta") if isinstance(custom, dict) and isinstance(custom.get("meta"), dict) else {}
    if "notes" in custom_meta:
        return _notes_to_text(custom_meta.get("notes"))

    return ""


def character_notes(char: str) -> str:
    backup_notes = active_backup_character_notes(char)
    if backup_notes:
        return backup_notes
    meta = component_map.get(char, {}).get("meta", {})
    return _notes_to_text(meta.get("notes", ""))


def upsert_active_backup_character_notes(char: str, notes: str) -> None:
    backup = get_active_backup()
    if not backup:
        raise ValueError("No active backup.")
    char = (char or "").strip()
    if len(char) != 1:
        raise ValueError("Choose exactly one character.")

    overlay = backup.setdefault("dictionary_patch_overlay", {})
    if not isinstance(overlay, dict):
        overlay = {
            "schema_version": 1,
            "custom_entries": {},
            "patches": [],
            "deletions": [],
        }
        backup["dictionary_patch_overlay"] = overlay

    overlay.setdefault("schema_version", 1)
    if not isinstance(overlay.get("custom_entries"), dict):
        overlay["custom_entries"] = {}
    if not isinstance(overlay.get("patches"), list):
        overlay["patches"] = []
    if not isinstance(overlay.get("deletions"), list):
        overlay["deletions"] = []

    notes_list = _text_to_notes_list(notes)
    custom = overlay["custom_entries"].get(char)
    if isinstance(custom, dict):
        custom_meta = custom.setdefault("meta", {})
        if isinstance(custom_meta, dict):
            custom_meta["notes"] = notes_list

    for patch in reversed(overlay["patches"]):
        if isinstance(patch, dict) and patch.get("character") == char:
            meta = patch.setdefault("meta", {})
            if isinstance(meta, dict):
                meta["notes"] = notes_list
                patch["updated_at"] = _cocoa_timestamp()
                mark_active_backup_dirty()
                refresh_active_backup_summary()
                return

    overlay["patches"].append(
        {
            "character": char,
            "meta": {"notes": notes_list},
            "updated_at": _cocoa_timestamp(),
        }
    )
    mark_active_backup_dirty()
    refresh_active_backup_summary()


def upsert_active_backup_phrase(word: str, pinyin: str, meanings: str, notes: str, review_status: str) -> None:
    backup = get_active_backup()
    if not backup:
        raise ValueError("No active backup.")
    word = (word or "").strip()
    if not word:
        raise ValueError("Phrase word is required.")

    now = _cocoa_timestamp()
    phrases = backup.setdefault("phrases", [])
    for item in phrases:
        if isinstance(item, dict) and item.get("word") == word:
            item["pinyin"] = pinyin.strip()
            item["meanings"] = meanings.strip()
            item["notes"] = notes.strip()
            item["review_status"] = review_status.strip() or item.get("review_status", "")
            mark_active_backup_dirty()
            refresh_active_backup_summary()
            return

    phrases.append(
        {
            "word": word,
            "pinyin": pinyin.strip(),
            "meanings": meanings.strip(),
            "notes": notes.strip(),
            "review_status": review_status.strip() or "checked",
            "added_at": now,
            "last_reviewed_at": now,
        }
    )
    mark_active_backup_dirty()
    refresh_active_backup_summary()


def delete_active_backup_phrase(word: str) -> None:
    backup = get_active_backup()
    if not backup:
        raise ValueError("No active backup.")
    backup["phrases"] = [
        item for item in backup.get("phrases", [])
        if not (isinstance(item, dict) and item.get("word") == word)
    ]
    mark_active_backup_dirty()
    refresh_active_backup_summary()


def active_backup_collections() -> list[dict]:
    backup = get_active_backup()
    if not backup:
        return []
    return [item for item in backup.get("collections", []) if isinstance(item, dict)]


def active_backup_collection(collection_id: str) -> dict | None:
    for item in active_backup_collections():
        if item.get("id") == collection_id:
            return item
    return None


def _collection_sort_date(collection: dict, order: str) -> float:
    if order == "Scanned":
        return float(collection.get("createdAt") or 0)
    return float(collection.get("lastViewedAt") or collection.get("createdAt") or 0)


def sorted_active_backup_collections(order: str = "Viewed") -> list[dict]:
    collections = active_backup_collections()
    return sorted(
        collections,
        key=lambda c: (
            not bool(c.get("isFavorite", False)),
            -_collection_sort_date(c, order),
            str(c.get("name") or "Untitled").casefold(),
        ),
    )


def select_browse_collection(collection_id: str) -> None:
    collection = active_backup_collection(collection_id)
    if collection is None:
        return
    collection["lastViewedAt"] = _cocoa_timestamp()
    state.set("selected_browse_collection_id", collection_id)
    state.set("page", 1)
    refresh_active_backup_summary()


def selected_browse_collection() -> dict | None:
    collection_id = state.get("selected_browse_collection_id", "")
    collection = active_backup_collection(collection_id) if collection_id else None
    if collection is not None:
        return collection
    collections = sorted_active_backup_collections(state.get("browse_page_sort_order", "Viewed"))
    if not collections:
        state.set("selected_browse_collection_id", "")
        return None
    first = collections[0]
    state.set("selected_browse_collection_id", first.get("id", ""))
    return first


def collection_display_name(collection: dict) -> str:
    name = str(collection.get("name") or "").strip()
    return name or "Scanned Page"


def _extract_collection_characters(text: str) -> list[str]:
    return [c for c in (text or "") if "\u4e00" <= c <= "\u9fff"]


def create_active_backup_collection(*, name: str, text: str, source_type: str = "manual", is_favorite: bool = False) -> str:
    backup = get_active_backup()
    if not backup:
        raise ValueError("No active backup.")
    characters = _extract_collection_characters(text)
    if not characters:
        raise ValueError("Page text must include at least one Chinese character.")

    now = _cocoa_timestamp()
    collection_id = str(uuid.uuid4()).upper()
    collection = {
        "id": collection_id,
        "name": name.strip() or "Untitled",
        "characters": characters,
        "createdAt": now,
        "lastViewedAt": now,
        "sourceType": source_type.strip() or "manual",
        "isFavorite": bool(is_favorite),
    }
    backup.setdefault("collections", []).append(collection)
    state.set("selected_browse_collection_id", collection_id)
    mark_active_backup_dirty()
    refresh_active_backup_summary()
    return collection_id


def update_active_backup_collection(collection_id: str, *, name: str, text: str, source_type: str | None = None, is_favorite: bool | None = None) -> None:
    collection = active_backup_collection(collection_id)
    if collection is None:
        raise ValueError("Collection not found.")
    collection["name"] = name.strip() or "Untitled"
    collection["characters"] = _extract_collection_characters(text)
    if source_type is not None:
        collection["sourceType"] = source_type.strip() or collection.get("sourceType") or "manual"
    if is_favorite is not None:
        collection["isFavorite"] = bool(is_favorite)
    collection["lastViewedAt"] = _cocoa_timestamp()
    mark_active_backup_dirty()
    refresh_active_backup_summary()


def delete_active_backup_collection(collection_id: str) -> None:
    backup = get_active_backup()
    if not backup:
        raise ValueError("No active backup.")
    before = len(backup.get("collections") or [])
    backup["collections"] = [
        item for item in backup.get("collections", [])
        if not (isinstance(item, dict) and item.get("id") == collection_id)
    ]
    if len(backup["collections"]) == before:
        raise ValueError("Collection not found.")
    if state.get("selected_browse_collection_id") == collection_id:
        state.set("selected_browse_collection_id", "")
    mark_active_backup_dirty()
    refresh_active_backup_summary()


def update_active_backup_translation_report(collection_id: str, report: str | None) -> None:
    collection = active_backup_collection(collection_id)
    if collection is None:
        raise ValueError("Collection not found.")
    clean_report = (report or "").strip()
    if clean_report:
        collection["translationReport"] = clean_report
        collection["translationReportUpdatedAt"] = _cocoa_timestamp()
    else:
        collection.pop("translationReport", None)
        collection.pop("translationReportUpdatedAt", None)
    mark_active_backup_dirty()
    refresh_active_backup_summary()


def page_phrase_candidates(collection: dict) -> list[dict]:
    chars = collection.get("characters") or []
    if len(chars) < 2:
        return []

    conn = get_db_connection()
    max_phrase_length = _max_base_phrase_length(conn)
    phrase_by_lookup_word = _fetch_page_phrase_lookup(collection, max_phrase_length, conn)
    lookup_chars = [_phrase_lookup_target(c) for c in chars]
    phrase_by_word: dict[str, dict] = {}
    first_start_by_word: dict[str, int] = {}
    count_by_word: dict[str, int] = {}

    for offset in range(len(lookup_chars)):
        max_length = min(max_phrase_length, len(lookup_chars) - offset)
        if max_length < 2:
            continue
        for length in range(2, max_length + 1):
            segment = "".join(lookup_chars[offset:offset + length])
            phrase = phrase_by_lookup_word.get(segment)
            if not phrase:
                continue
            word = _phrase_storage_word(phrase.get("word", ""))
            phrase_by_word[word] = phrase
            first_start_by_word[word] = min(first_start_by_word.get(word, offset), offset)
            count_by_word[word] = count_by_word.get(word, 0) + 1

    candidates = []
    for word, phrase in phrase_by_word.items():
        item = dict(phrase)
        item["_first_start"] = first_start_by_word.get(word, 0)
        item["_occurrence_count"] = count_by_word.get(word, 1)
        candidates.append(item)

    return sorted(
        candidates,
        key=lambda p: (
            normalize_pinyin(p.get("pinyin", ""), fuzzy_initials=True),
            p.get("word", ""),
            p.get("_first_start", 0),
        ),
    )


def set_collection_hidden_phrases(collection_id: str, hidden_words: list[str]) -> None:
    collection = active_backup_collection(collection_id)
    if collection is None:
        raise ValueError("Collection not found.")
    clean = sorted({w for w in hidden_words if isinstance(w, str) and w.strip()})
    if clean:
        collection["hiddenPhraseWords"] = clean
    else:
        collection.pop("hiddenPhraseWords", None)
    collection["lastViewedAt"] = _cocoa_timestamp()
    mark_active_backup_dirty()
    refresh_active_backup_summary()


def _augment_component_map(data: dict) -> dict:
    """Recompute derived fields required by the runtime after dataset edits."""
    if not rc.SUBTLEX_FREQ:
        rc.load_subtlex_freq()

    for char, info in data.items():
        meta = info.get("meta", {})
        rel = info.get("related_characters", [])
        info["usage_count"] = len({c for c in rel if isinstance(c, str) and len(c) == 1})

        s = meta.get("strokes")
        try:
            if isinstance(s, (int, float)) and s > 0:
                info["stroke_count"] = int(s)
            elif isinstance(s, str) and s.isdigit():
                info["stroke_count"] = int(s)
            else:
                info["stroke_count"] = None
        except Exception:
            info["stroke_count"] = None

        lookup_char = cc_t2s.convert(char) if cc_t2s else char
        info["freq_per_million"] = rc.SUBTLEX_FREQ.get(lookup_char, 0.0)

    return data


def _apply_dataset_to_runtime(content) -> int:
    """Validate and hot-apply edited dataset into the running app."""
    validated = save_json_copy(content=content, persist=False)
    parsed = json.loads(validated["content"])
    _augment_component_map(parsed)
    component_map.clear()
    component_map.update(parsed)
    stats_cache.clear()
    stats_cache.update(rc.get_component_stats(component_map))
    return len(component_map)


def _default_entry_template() -> dict:
    return {
        "meta": {
            "definition": "",
            "pinyin": "",
            "decomposition": "",
            "radical": "",
            "strokes": "",
            "compounds": [],
            "etymology": {"hint": "", "details": ""},
        },
        "related_characters": [],
    }


def _load_dataset_working_copy(source_path: str) -> None:
    payload = create_editable_copy(source_path=source_path, persist=False)
    st.session_state["dataset_working_map"] = json.loads(payload["content"])
    st.session_state["dataset_editor_filename"] = payload.get("suggestedFilename", "component_map_editable.json")
    st.session_state["dataset_entry_loaded_for"] = ""


def _load_entry_into_editor(char_key: str) -> None:
    wm = st.session_state.get("dataset_working_map", {})
    entry = wm.get(char_key, _default_entry_template())
    st.session_state["dataset_entry_raw"] = json.loads(json.dumps(entry, ensure_ascii=False))
    st.session_state["dataset_entry_loaded_for"] = char_key

    meta = entry.get("meta", {}) if isinstance(entry, dict) else {}

    def _to_text_list(value):
        if isinstance(value, list):
            return "\n".join([str(x) for x in value if isinstance(x, str)])
        if isinstance(value, str):
            return value
        return ""

    pinyin_value = meta.get("pinyin", "")
    if isinstance(pinyin_value, list):
        st.session_state["dataset_form_pinyin_type"] = "List"
        st.session_state["dataset_form_pinyin"] = "\n".join([x for x in pinyin_value if isinstance(x, str)])
    else:
        st.session_state["dataset_form_pinyin_type"] = "String"
        st.session_state["dataset_form_pinyin"] = pinyin_value if isinstance(pinyin_value, str) else ""

    ety = meta.get("etymology", {}) if isinstance(meta.get("etymology"), dict) else {}
    st.session_state["dataset_form_definition"] = meta.get("definition", "") if isinstance(meta.get("definition"), str) else ""
    st.session_state["dataset_form_decomposition"] = meta.get("decomposition", "") if isinstance(meta.get("decomposition"), str) else ""
    st.session_state["dataset_form_radical"] = meta.get("radical", "") if isinstance(meta.get("radical"), str) else ""
    st.session_state["dataset_form_strokes"] = str(meta.get("strokes", "") or "")
    st.session_state["dataset_form_compounds"] = _to_text_list(meta.get("compounds", []))
    st.session_state["dataset_form_etym_hint"] = _to_text_list(ety.get("hint", ""))
    st.session_state["dataset_form_etym_details"] = _to_text_list(ety.get("details", ""))
    st.session_state["dataset_form_related"] = _to_text_list(entry.get("related_characters", []))


def _split_lines_csv(raw: str) -> list[str]:
    if not isinstance(raw, str):
        return []
    out = []
    for part in re.split(r"[\n,]+", raw):
        token = part.strip()
        if token:
            out.append(token)
    return out


def _build_entry_from_form() -> dict:
    original = st.session_state.get("dataset_entry_raw", {})
    entry = json.loads(json.dumps(original if isinstance(original, dict) else {}, ensure_ascii=False))

    meta = entry.get("meta")
    if not isinstance(meta, dict):
        meta = {}
    entry["meta"] = meta

    meta["definition"] = st.session_state.get("dataset_form_definition", "")
    pinyin_raw = st.session_state.get("dataset_form_pinyin", "")
    if st.session_state.get("dataset_form_pinyin_type", "String") == "List":
        meta["pinyin"] = _split_lines_csv(pinyin_raw)
    else:
        meta["pinyin"] = pinyin_raw
    meta["decomposition"] = st.session_state.get("dataset_form_decomposition", "")
    meta["radical"] = st.session_state.get("dataset_form_radical", "")

    strokes_raw = st.session_state.get("dataset_form_strokes", "").strip()
    if strokes_raw.isdigit():
        meta["strokes"] = int(strokes_raw)
    else:
        meta["strokes"] = strokes_raw

    meta["compounds"] = _split_lines_csv(st.session_state.get("dataset_form_compounds", ""))

    ety = meta.get("etymology")
    if not isinstance(ety, dict):
        ety = {}
    ety["hint"] = st.session_state.get("dataset_form_etym_hint", "")
    ety["details"] = st.session_state.get("dataset_form_etym_details", "")
    meta["etymology"] = ety

    entry["related_characters"] = _split_lines_csv(st.session_state.get("dataset_form_related", ""))
    return entry


def dataset_pick_char(c: str):
    """Select a character and immediately load its dataset entry into the editor."""
    state.set("preview_comp", c)
    st.session_state["dataset_edit_char"] = c
    _load_entry_into_editor(c)


def open_dataset_editor():
    state.set("backup_workspace_mode", False)
    state.set("dataset_editor_mode", True)


def close_dataset_editor():
    state.set("dataset_editor_mode", False)


def open_backup_workspace():
    state.set("dataset_editor_mode", False)
    state.set("backup_workspace_mode", True)
    state.go_to_root()


def close_backup_workspace():
    state.set("backup_workspace_mode", False)


def go_to_search_root():
    state.set("dataset_editor_mode", False)
    state.set("backup_workspace_mode", False)
    state.go_to_root()


def open_search_screen():
    go_to_search_root()
    state.set("home_screen", "search")


def open_browse_screen():
    go_to_search_root()
    state.set("home_screen", "browse")
    state.set("page", 1)


def open_favourites_screen():
    go_to_search_root()
    state.set("home_screen", "favourites")
    state.set("page", 1)


def _promote_selection_for_navigation(target_char: str):
    """Promote previewed char into selected state before explicit nav actions."""
    if not target_char:
        return
    selected = state.get_selected_component()
    if selected and selected != target_char:
        history = state.get_history()
        history.append(selected)
        state.set("history", history)
    state.set("selected_comp", target_char)
    state.set("last_valid_selected_comp", target_char)
    state.set("text_input_comp", target_char)
    state.set("preview_comp", None)


def commit_preview_as_selection(target_char: str):
    _promote_selection_for_navigation(target_char)
    state.set("show_inputs", False)
    state.set("definition_search_mode", False)
    state.set("definition_search_results", None)
    st.query_params["c"] = target_char


def _search_pick_char(c: str, key_prefix: str = "", on_pick=None, collapse_after_pick: bool = False):
    """Handle character selection from shared search UI."""
    state.remember_character(c)
    if on_pick:
        on_pick(c)
    elif collapse_after_pick:
        pass  # handled below
    else:
        # Navigate directly to character view
        state.enter_character_view(c)
        st.rerun()

    if collapse_after_pick:
        st.session_state[f"{key_prefix}selected_char"] = c
        st.rerun()


def render_dataset_editor():
    """Character-focused dataset editor integrated with app search/selection."""
    st.caption("Search/select a character, then edit it with strict fields (key names are fixed).")
    st.markdown("### Character Search")
    render_smart_search("dataset_", on_pick=dataset_pick_char, collapse_after_pick=True)
    st.markdown("---")
    st.markdown("### Entry Editor")

    if "dataset_source_path" not in st.session_state:
        st.session_state["dataset_source_path"] = DEFAULT_COMPONENT_MAP_FILE
    if "dataset_working_map" not in st.session_state:
        try:
            _load_dataset_working_copy(st.session_state["dataset_source_path"])
        except Exception:
            st.session_state["dataset_working_map"] = json.loads(json.dumps(component_map, ensure_ascii=False))
            st.session_state["dataset_editor_filename"] = "component_map_editable.json"
            st.session_state["dataset_entry_loaded_for"] = ""
    if "dataset_edit_char" not in st.session_state:
        st.session_state["dataset_edit_char"] = ""
    if "dataset_editor_filename" not in st.session_state:
        st.session_state["dataset_editor_filename"] = "component_map_editable.json"
    if "dataset_output_path" not in st.session_state:
        st.session_state["dataset_output_path"] = ""
    if "dataset_entry_raw" not in st.session_state:
        st.session_state["dataset_entry_raw"] = {}

    source_path = st.text_input("Source JSON path", key="dataset_source_path")
    if st.button("Reload Working Copy From Source", key="dataset_load_copy", use_container_width=True):
        try:
            _load_dataset_working_copy(source_path)
            st.success(f"Loaded {source_path} into memory.")
        except Exception as e:
            st.error(str(e))

    selected_char = state.get_preview_component() or state.get_selected_component()
    if selected_char:
        if st.session_state.get("dataset_edit_char") != selected_char:
            st.session_state["dataset_edit_char"] = selected_char
            _load_entry_into_editor(selected_char)
        st.caption(f"Current search selection: `{selected_char}` (auto-loaded)")

    st.text_input("Character key to edit", key="dataset_edit_char", max_chars=1)
    e1, e2 = st.columns(2)
    with e1:
        if st.button("Load Character Entry", key="dataset_load_char", use_container_width=True):
            char_key = (st.session_state["dataset_edit_char"] or "").strip()
            if len(char_key) != 1:
                st.error("Enter exactly one character key.")
            else:
                _load_entry_into_editor(char_key)
    with e2:
        if st.button("New Entry Template", key="dataset_new_entry", use_container_width=True):
            char_key = (st.session_state["dataset_edit_char"] or "").strip()
            if len(char_key) != 1:
                st.error("Enter exactly one character key.")
            else:
                st.session_state["dataset_entry_raw"] = _default_entry_template()
                _load_entry_into_editor(char_key)

    char_key = (st.session_state["dataset_edit_char"] or "").strip()
    wm = st.session_state.get("dataset_working_map", {})
    if len(char_key) == 1 and char_key in wm:
        st.markdown("**Current entry snapshot (read-only full data):**")
        st.json(wm[char_key], expanded=False)

    st.markdown("### Edit Fields (Strict Schema)")
    st.text_input("meta.definition", key="dataset_form_definition")
    st.radio("meta.pinyin type", options=["String", "List"], horizontal=True, key="dataset_form_pinyin_type")
    st.text_area("meta.pinyin", key="dataset_form_pinyin", height=90, help="String or newline/comma separated list.")
    st.text_input("meta.decomposition", key="dataset_form_decomposition")
    st.text_input("meta.radical", key="dataset_form_radical")
    st.text_input("meta.strokes", key="dataset_form_strokes")
    st.text_area("meta.compounds (newline/comma separated)", key="dataset_form_compounds", height=90)
    st.text_area("meta.etymology.hint", key="dataset_form_etym_hint", height=70)
    st.text_area("meta.etymology.details", key="dataset_form_etym_details", height=90)
    st.text_area("related_characters (newline/comma separated)", key="dataset_form_related", height=90)

    a1, a2 = st.columns(2)
    with a1:
        if st.button("Save Entry To Working Copy", key="dataset_save_entry", use_container_width=True):
            try:
                char_key = (st.session_state["dataset_edit_char"] or "").strip()
                if len(char_key) != 1:
                    raise ValueError("Character key must be exactly one character.")

                parsed_entry = _build_entry_from_form()
                updated = dict(st.session_state["dataset_working_map"])
                updated[char_key] = parsed_entry
                validated = save_json_copy(content=updated, persist=False)
                normalized_map = json.loads(validated["content"])
                st.session_state["dataset_working_map"] = normalized_map
                _load_entry_into_editor(char_key)
                st.success(f"Entry '{char_key}' saved to working copy.")
            except Exception as e:
                st.error(str(e))
    with a2:
        if st.button("Delete Entry", key="dataset_delete_entry", use_container_width=True):
            try:
                char_key = (st.session_state["dataset_edit_char"] or "").strip()
                if len(char_key) != 1:
                    raise ValueError("Character key must be exactly one character.")
                updated = dict(st.session_state["dataset_working_map"])
                if char_key not in updated:
                    raise ValueError(f"Entry '{char_key}' not found.")
                del updated[char_key]
                validated = save_json_copy(content=updated, persist=False)
                st.session_state["dataset_working_map"] = json.loads(validated["content"])
                st.success(f"Entry '{char_key}' deleted from working copy.")
            except Exception as e:
                st.error(str(e))

    st.markdown("---")
    st.text_input("Download filename", key="dataset_editor_filename")
    full_dataset = st.session_state.get("dataset_working_map", {})

    o1, o2 = st.columns(2)
    with o1:
        if st.button("Validate Full Dataset", key="dataset_validate_all", use_container_width=True):
            try:
                save_json_copy(content=full_dataset, persist=False)
                st.success("Full dataset is valid and app-compatible.")
            except Exception as e:
                st.error(str(e))
    with o2:
        if st.button("Apply Full Dataset To App", key="dataset_apply_runtime", use_container_width=True, type="primary"):
            try:
                count = _apply_dataset_to_runtime(full_dataset)
                st.success(f"Applied dataset to runtime ({count} characters).")
                st.rerun()
            except Exception as e:
                st.error(str(e))

    try:
        download_payload = build_download_payload(
            content=full_dataset,
            filename=st.session_state["dataset_editor_filename"],
        )
        st.download_button(
            "Download Full Edited JSON",
            data=download_payload["bytes"],
            file_name=download_payload["filename"],
            mime=download_payload["mime"],
            use_container_width=True,
            key="dataset_download_btn",
        )
    except Exception as e:
        st.error(str(e))

    st.caption("Optional: save full edited dataset to disk (writable environments only).")
    st.text_input("Output path", key="dataset_output_path")
    if st.button("Save Full Dataset To Disk", key="dataset_save_disk", use_container_width=True):
        try:
            result = save_json_copy(
                content=full_dataset,
                output_path=st.session_state["dataset_output_path"].strip(),
                persist=True,
            )
            st.success(f"Saved: {result.get('outputPath')}")
        except Exception as e:
            st.error(str(e))


# ==================== CALLBACKS ====================

def tile_click(c):
    """Handle click on a grid tile — navigate directly to character view."""
    state.remember_character(c)
    state.enter_character_view(c)

def list_tile_click(c):
    """Handle click on a list/lineage tile — navigate directly."""
    state.remember_character(c)
    if state.get_selected_component() and state.get_selected_component() != c:
        history = state.get_history()
        history.append(state.get_selected_component())
        state.set("history", history)
    state.enter_character_view(c)

def toggle_favourite(char):
    """Toggle favourite status via checkbox."""
    if state.get(f"fav_chk_{char}", False):
        state.add_to_favourites(char)
    else:
        state.remove_from_favourites(char)

def search_by_definition():
    """Execute search for English definitions (Legacy/Sidebar version)."""
    query = state.get("sidebar_def_search", "").strip()
    is_valid, error_msg = InputValidator.validate_definition_search(query)
    
    if not is_valid:
        st.toast(error_msg)
        return
    
    char_results = radix_definition_character_search(query, is_strict=False, limit=120)
    db_conn = get_db_connection()
    phrase_results = search_phrase_meanings(query, db_conn, limit=120, is_strict=False)
    
    # 3. Update State
    state.update(
        definition_search_mode=True,
        definition_search_query=query,
        definition_search_results={"characters": char_results[:120], "phrases": phrase_results[:200]},
        show_inputs=False,
        selected_comp="",
        preview_comp=None
    )


def memory_strip_pick(c: str):
    """Navigate to a remembered character or phrase."""
    if len(c) == 1 and c in component_map:
        state.set("sidebar_phrase_preview", None)
        state.enter_character_view(c)
        return

    db_conn = get_db_connection()
    phrase = get_phrase_details([c], db_conn).get(c)
    if not phrase:
        phrase = {"word": c, "pinyin": "", "meanings": "", "notes": "", "review_status": ""}
    state.set("sidebar_phrase_preview", phrase)
    state.remember_character(c)
    state.set("dataset_editor_mode", False)
    state.go_to_root()
    state.set("home_screen", "search")
    st.session_state["smart_search_input"] = c


def memory_strip_remove(c: str):
    """Remove a character from the remembered strip."""
    state.remove_from_remembered(c)


def render_memory_strip():
    """Render the lightweight Radix memory strip."""
    remembered = state.get_remembered()
    if not remembered:
        return
    offset = int(state.get("memory_strip_offset", 0) or 0)
    visible_count = 14
    max_offset = max(0, len(remembered) - visible_count)
    offset = max(0, min(offset, max_offset))
    state.set("memory_strip_offset", offset)

    st.markdown(
        """
        <style>
        .st-key-memory_strip {
            background: #f3efe8;
            border: 1px solid #e8e2d8;
            border-radius: 6px;
            padding: 3px 5px;
            margin-bottom: 6px;
        }
        .st-key-memory_strip [data-testid="stElementContainer"] {margin-bottom: 0 !important;}
        .st-key-memory_strip [data-testid="column"] {min-width: 0 !important;}
        .st-key-memory_strip [data-testid="stButton"] > button {
            min-height: 24px;
            height: 24px;
            border-radius: 5px;
            padding: 1px 4px;
            font-size: 0.78rem !important;
            line-height: 1 !important;
            font-weight: 650;
            white-space: nowrap;
            word-break: keep-all;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .st-key-memory_strip [data-testid="stButton"] > button p {
            font-size: 0.78rem !important;
            line-height: 1 !important;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .st-key-memory_strip .st-key-memory_icon [data-testid="stButton"] > button,
        .st-key-memory_strip .st-key-memory_prev [data-testid="stButton"] > button,
        .st-key-memory_strip .st-key-memory_next [data-testid="stButton"] > button {
            padding: 0 !important;
        }
        </style>
        """,
        unsafe_allow_html=True,
    )

    with st.container(key="memory_strip"):
        cols = st.columns([0.45, 0.45] + [1] * visible_count + [0.45], gap="small")
        with cols[0]:
            st.button(NAV_ICON_ONLY_LABEL, key="memory_icon", icon=":material/history:", help="History", use_container_width=True, disabled=True)
        with cols[1]:
            if st.button(NAV_ICON_ONLY_LABEL, key="memory_prev", icon=":material/chevron_left:", help="Previous history", use_container_width=True, disabled=offset <= 0):
                state.set("memory_strip_offset", max(0, offset - visible_count))
                st.rerun()
        visible = remembered[offset:offset + visible_count]
        for i, item in enumerate(visible):
            with cols[i + 2]:
                if st.button(item, key=f"memory_pick_{offset + i}_{abs(hash(item))}", help=f"Open {item}", use_container_width=True):
                    memory_strip_pick(item)
                    st.rerun()
        with cols[-1]:
            if st.button(NAV_ICON_ONLY_LABEL, key="memory_next", icon=":material/chevron_right:", help="Next history", use_container_width=True, disabled=offset >= max_offset):
                state.set("memory_strip_offset", min(max_offset, offset + visible_count))
                st.rerun()


# ==================== HTML HELPERS ====================

def _render_phrase_html(c: str) -> str:
    """Render phrases containing the character."""
    n_map = {"Single Character": 1, "2-Characters": 2, "3-Characters": 3, "4-Characters": 4}
    n = n_map.get(state.get_display_mode(), 2)
    
    raw_compounds = component_map.get(c, {}).get("meta", {}).get("compounds", [])
    
    if not raw_compounds and cc_t2s:
        s_c = cc_t2s.convert(c)
        if s_c != c:
            raw_compounds = component_map.get(s_c, {}).get("meta", {}).get("compounds", [])
            
    compounds = [w for w in (raw_compounds or []) if len(w) == n]
    
    if compounds and (db := get_db_connection()):
        phrases = get_phrase_details(sorted(compounds), db)
        items_html_list = []
        for word in sorted(compounds):
            entry = phrases.get(word)
            if entry:
                p_mean = pyhtml.escape(entry.get('meanings', '')[:130] + ('...' if len(entry.get('meanings', '')) > 130 else ''))
                items_html_list.append(f"<div style='display:flex; align-items:baseline; padding:6px 8px; border-bottom:1px solid #e8e2d8;'><span style='font-weight:700; font-size:1.0rem; min-width:65px; font-family:Noto Serif SC,serif;'>{word}</span><span style='color:#c0392b; font-size:0.88rem; font-family:Lora,Georgia,serif; font-style:italic; margin-right:12px; font-weight:600;'>{entry.get('pinyin', '')}</span><span style='color:#3d342a; font-size:0.84rem; flex:1; line-height:1.3;'>{p_mean}</span></div>")
        
        if items_html_list:
            return f"<div style='padding:12px; background:#f3efe8; border-radius:10px; margin-top:10px; border:1px solid #e8e2d8; max-height:400px; overflow-y:auto;'><div style='font-weight:700; font-size:0.78rem; margin-bottom:8px; color:#2a6b55; text-transform:uppercase; letter-spacing:0.04em;'>{state.get_display_mode()} containing {c}</div>{''.join(items_html_list)}</div>"
    return ""

def render_radix_row(c, is_static=False, minimal=False):
    """Render a standard list row for a character."""
    col_char, col_details = st.columns([2, 10])
    uid = str(uuid.uuid4())[:8]

    with col_char:
        if is_static:
            st.markdown(f"<div class='char-static-box'>{c}</div>", unsafe_allow_html=True)
        else:
            st.markdown("<div class='char-btn-wrap'>", unsafe_allow_html=True)
            st.button(
                c,
                key=f"char_{c}_{uid}",
                type="secondary",
                help=f"Open {c}",
                on_click=list_tile_click,
                args=(c,),
                use_container_width=True
            )
            st.markdown("</div>", unsafe_allow_html=True)

    with col_details:
        st.markdown(generate_clean_card_html(c, usage_count=component_usage_count(c), is_static=is_static, minimal=minimal), unsafe_allow_html=True)

        if not is_static:
            current_mode_str = state.get_display_mode()
            try:
                current_int = int(current_mode_str[0])
            except:
                current_int = 2

            if current_int not in [2, 3, 4]:
                current_int = 2

            def update_phrase_len():
                val = st.session_state[f"ph_len_{c}_{uid}"]
                state.set("display_mode", f"{val}-Characters")

            st.radio(
                "Phrase Length",
                options=[2, 3, 4],
                index=[2, 3, 4].index(current_int),
                key=f"ph_len_{c}_{uid}",
                horizontal=True,
                label_visibility="collapsed",
                on_change=update_phrase_len
            )

            if html := _render_phrase_html(c):
                st.markdown(html, unsafe_allow_html=True)

    st.markdown("<div style='height: 12px'></div>", unsafe_allow_html=True)


# ==================== VIEW RENDERERS ====================

def render_backup_workspace():
    """Main scoped editor for Radix backup phrases, pages, and export."""
    backup = get_active_backup()
    if not backup:
        st.warning("No Radix backup is active. Import a backup or restore the permanent sample from the sidebar.")
        return

    summary = st.session_state.get("active_backup_summary") or backup_summary(backup)
    st.markdown("### Radix Backup")
    st.caption(
        f"{summary.get('phrases_count', 0)} phrases · "
        f"{summary.get('collections_count', 0)} pages · "
        f"schema {summary.get('schema_version', '')}"
    )
    if st.session_state.get("active_backup_dirty"):
        st.warning("This working backup has local edits. Export it before restoring elsewhere.")
    else:
        st.caption("No local backup edits in this session.")

    phrase_tab, char_tab, page_tab, export_tab = st.tabs(["Phrases", "Characters", "Pages", "Export"])

    with phrase_tab:
        phrases = sorted(all_phrase_details(backup), key=lambda p: p.get("word", ""))
        phrase_query = st.text_input("Filter phrases", key="backup_phrase_filter", placeholder="word, pinyin, meaning, or note")
        q = phrase_query.strip().lower()
        if q:
            phrases = [
                p for p in phrases
                if q in " ".join([
                    p.get("word", ""),
                    p.get("pinyin", ""),
                    p.get("meanings", ""),
                    p.get("notes", ""),
                ]).lower()
            ]

        options = ["New phrase"] + [p.get("word", "") for p in phrases[:300]]
        selected_word = st.selectbox("Phrase", options=options, key="backup_phrase_selected")
        existing = phrase_details_map(backup, [selected_word]).get(selected_word, {}) if selected_word != "New phrase" else {}

        with st.form("backup_phrase_form"):
            word = st.text_input("Word", value=existing.get("word", ""), max_chars=32)
            pinyin = st.text_input("Pinyin", value=existing.get("pinyin", ""))
            meanings = st.text_area("Meanings", value=existing.get("meanings", ""), height=90)
            notes = st.text_area("Notes", value=existing.get("notes", ""), height=120)
            review_status = st.text_input("Review status", value=existing.get("review_status", "checked"))
            saved = st.form_submit_button("Save Phrase", type="primary", use_container_width=True)
            if saved:
                try:
                    upsert_active_backup_phrase(word, pinyin, meanings, notes, review_status)
                    state.remember_character(word)
                    st.success(f"Saved phrase {word}.")
                    st.rerun()
                except Exception as e:
                    st.error(str(e))

        if existing and st.button("Delete Selected Phrase", key="delete_backup_phrase", use_container_width=True):
            try:
                delete_active_backup_phrase(selected_word)
                st.success(f"Deleted phrase {selected_word}.")
                st.rerun()
            except Exception as e:
                st.error(str(e))

        if len(phrases) > 300:
            st.caption(f"Showing first 300 of {len(phrases)} matching phrases.")

    with char_tab:
        st.caption("Edit notes only. RadixWeb preserves structural dictionary data as-is.")
        current_char = state.get_preview_component() or state.get_selected_component() or ""
        default_char = current_char if len(current_char) == 1 else ""
        note_char = st.text_input("Character", value=default_char, max_chars=1, key="backup_character_notes_char")
        note_char = (note_char or "").strip()
        if note_char:
            if note_char not in component_map:
                st.warning("This character is not in the bundled dictionary. Notes can still be saved into the backup overlay.")
            meta = component_map.get(note_char, {}).get("meta", {})
            pinyin_text = clean_field(meta.get("pinyin", ""))
            definition = clean_field(meta.get("definition", ""))
            if pinyin_text or definition:
                st.caption(" · ".join([part for part in [pinyin_text, definition] if part and part != "—"]))

            with st.form("backup_character_notes_form"):
                notes = st.text_area("Notes", value=character_notes(note_char), height=180)
                if st.form_submit_button("Save Character Notes", type="primary", use_container_width=True):
                    try:
                        upsert_active_backup_character_notes(note_char, notes)
                        state.remember_character(note_char)
                        st.success(f"Saved notes for {note_char}.")
                        st.rerun()
                    except Exception as e:
                        st.error(str(e))
        else:
            st.info("Choose a character to edit its backup notes.")

    with page_tab:
        collections = active_backup_collections()
        mode_options = ["New page"] + (["Edit page"] if collections else [])
        page_mode = st.segmented_control(
            "Page action",
            options=mode_options,
            default="Edit page" if collections else "New page",
            key="backup_page_mode",
            label_visibility="collapsed",
            width="stretch",
        ) or ("Edit page" if collections else "New page")

        if page_mode == "New page":
            st.markdown("#### New Page")
            with st.form("backup_page_create_form"):
                page_name = st.text_input("Name", value="")
                source_type = st.text_input("Source type", value="manual")
                is_favorite = st.checkbox("Favorite", value=False)
                page_text = st.text_area(
                    "Paste Chinese text",
                    value="",
                    height=180,
                    placeholder="Paste page text here. RadixWeb will keep Chinese characters in reading order.",
                )
                if st.form_submit_button("Create Page", type="primary", use_container_width=True):
                    try:
                        collection_id = create_active_backup_collection(
                            name=page_name,
                            text=page_text,
                            source_type=source_type,
                            is_favorite=is_favorite,
                        )
                        st.success("Page created.")
                        state.set("backup_page_mode", "Edit page")
                        state.set("selected_browse_collection_id", collection_id)
                        st.rerun()
                    except Exception as e:
                        st.error(str(e))
        elif not collections:
            st.info("No saved pages in this backup.")
        else:
            collection_labels = [
                f"{idx + 1}. {c.get('name', 'Untitled')} · {len(c.get('characters') or [])} chars"
                for idx, c in enumerate(collections)
            ]
            selected_label = st.selectbox("Page", options=collection_labels, key="backup_page_selected")
            collection_id = collections[collection_labels.index(selected_label)].get("id", "")
            collection = active_backup_collection(collection_id)

            if collection:
                st.markdown("#### Page Content")
                with st.form("backup_page_content_form"):
                    page_name = st.text_input("Name", value=collection.get("name", "Untitled"))
                    source_type = st.text_input("Source type", value=collection.get("sourceType", "manual") or "manual")
                    is_favorite = st.checkbox("Favorite", value=bool(collection.get("isFavorite", False)))
                    page_text = st.text_area(
                        "Characters",
                        value="".join(collection.get("characters") or []),
                        height=160,
                    )
                    if st.form_submit_button("Save Page Content", type="primary", use_container_width=True):
                        try:
                            update_active_backup_collection(
                                collection_id,
                                name=page_name,
                                text=page_text,
                                source_type=source_type,
                                is_favorite=is_favorite,
                            )
                            st.success("Page content saved.")
                            st.rerun()
                        except Exception as e:
                            st.error(str(e))

                with st.expander("Delete page", expanded=False):
                    st.warning("This removes the page from the active working backup.")
                    if st.button("Delete Page", key=f"delete_page_{collection_id}", use_container_width=True):
                        try:
                            delete_active_backup_collection(collection_id)
                            st.success("Page deleted.")
                            st.rerun()
                        except Exception as e:
                            st.error(str(e))

                st.markdown("#### Translation Report")
                with st.form("backup_page_report_form"):
                    report = st.text_area(
                        "Report",
                        value=collection.get("translationReport", "") or "",
                        height=220,
                    )
                    report_cols = st.columns(2)
                    with report_cols[0]:
                        save_report = st.form_submit_button("Save Report", type="primary", use_container_width=True)
                    with report_cols[1]:
                        clear_report = st.form_submit_button("Clear Report", use_container_width=True)
                    if save_report or clear_report:
                        try:
                            update_active_backup_translation_report(collection_id, None if clear_report else report)
                            st.success("Translation report updated.")
                            st.rerun()
                        except Exception as e:
                            st.error(str(e))

                st.markdown("#### Page Phrases")
                candidates = page_phrase_candidates(collection)
                hidden = set(collection.get("hiddenPhraseWords") or [])
                if not candidates:
                    st.caption("No saved backup phrases currently match this page text.")
                else:
                    st.caption("Checked phrases are selected for this page. Unchecked phrases are exported as hiddenPhraseWords.")
                    shown = candidates[:100]
                    for phrase in shown:
                        word = phrase.get("word", "")
                        st.checkbox(
                            f"{word} · {phrase.get('pinyin', '')} · {phrase.get('meanings', '')[:80]}",
                            value=word not in hidden,
                            key=f"page_phrase_sel_{collection_id}_{word}",
                        )
                    if st.button("Save Phrase Selection", key="save_page_phrase_selection", use_container_width=True):
                        try:
                            hidden_words = [
                                p.get("word", "") for p in shown
                                if not st.session_state.get(f"page_phrase_sel_{collection_id}_{p.get('word', '')}", True)
                            ]
                            # Preserve hidden state for matching candidates not rendered on this page.
                            hidden_words.extend([w for w in hidden if w not in {p.get("word", "") for p in shown}])
                            set_collection_hidden_phrases(collection_id, hidden_words)
                            st.success("Page phrase selection saved.")
                            st.rerun()
                        except Exception as e:
                            st.error(str(e))
                    if len(candidates) > len(shown):
                        st.caption(f"Showing first {len(shown)} of {len(candidates)} matching page phrases.")

    with export_tab:
        st.markdown("#### Radix-Compatible Export")
        st.caption("Exports the active working backup with phrase/page edits preserved in the unified backup schema.")
        try:
            export_summary = export_validation_summary(backup)
            metric_cols = st.columns(5)
            metric_cols[0].metric("Schema", export_summary.get("schema_version", ""))
            metric_cols[1].metric("Phrases", export_summary.get("phrases_count", 0))
            metric_cols[2].metric("Char Notes", export_summary.get("character_notes_count", 0))
            metric_cols[3].metric("Pages", export_summary.get("collections_count", 0))
            metric_cols[4].metric("Reports", export_summary.get("translation_reports_count", 0))
            st.caption(f"Deselected page phrases: {export_summary.get('hidden_phrase_words_count', 0)}")
            preserved = export_summary.get("preserved_top_level_fields") or []
            if preserved:
                st.caption("Preserved unknown fields: " + ", ".join(preserved))
            for warning in export_summary.get("warnings") or []:
                st.warning(warning)

            payload = build_download_payload(
                export_backup_package(backup),
                "radix_unified_backup.json",
                validate_component_map=False,
            )
            st.download_button(
                "Download Radix Backup",
                data=payload["bytes"],
                file_name=payload["filename"],
                mime=payload["mime"],
                key="backup_workspace_download",
                type="primary",
                use_container_width=True,
            )
        except Exception as e:
            st.error(str(e))


def render_backup_panel():
    """Import, summarize, and export the active Radix unified backup."""
    summary = st.session_state.get("active_backup_summary") or {}
    backup = get_active_backup()

    with st.expander("Radix Backup", expanded=False):
        if backup:
            source_name = summary.get("source_name") or "Uploaded backup"
            sample_label = "Permanent sample" if st.session_state.get("active_backup_is_sample") else "Imported"
            st.caption(f"{sample_label}: `{source_name}`")
            if st.session_state.get("active_backup_dirty"):
                st.warning("Working backup has local edits.")
            else:
                st.caption("Working backup has no local edits.")
            c1, c2 = st.columns(2)
            with c1:
                st.metric("Phrases", summary.get("phrases_count", 0))
                st.metric("Collections", summary.get("collections_count", 0))
            with c2:
                st.metric("Remembered", summary.get("remembered_count", 0))
                st.metric("Dictionary Edits", summary.get("patches_count", 0) + summary.get("custom_entries_count", 0))

            collections = collection_summaries(backup)
            with st.expander("Collections in backup", expanded=False):
                if collections:
                    for item in collections[:12]:
                        report = " · report" if item.get("has_translation_report") else ""
                        st.caption(f"{item.get('name', 'Untitled')} · {item.get('characters_count', 0)} chars{report}")
                    if len(collections) > 12:
                        st.caption(f"Showing 12 of {len(collections)} collections.")
                else:
                    st.caption("No collections in this backup.")

            try:
                payload = build_download_payload(
                    export_backup_package(backup),
                    "radix_unified_backup.json",
                    validate_component_map=False,
                )
                st.download_button(
                    "Export Active Backup",
                    data=payload["bytes"],
                    file_name=payload["filename"],
                    mime=payload["mime"],
                    key="active_backup_download_btn",
                    use_container_width=True,
                )
            except Exception as e:
                st.error(str(e))
        else:
            st.info("No Radix backup is active.")

        uploaded = st.file_uploader(
            "Import Radix backup or profile JSON",
            type=["json"],
            key="backup_uploader",
            label_visibility="collapsed",
        )
        if uploaded:
            import hashlib
            uploaded_bytes = uploaded.getvalue()
            upload_hash = hashlib.sha256(uploaded_bytes).hexdigest()
            if upload_hash != st.session_state.get("active_backup_upload_hash", ""):
                try:
                    preview_type, preview_backup = load_radix_json_bytes(uploaded_bytes)
                    preview_summary = export_validation_summary(preview_backup)
                    st.caption("Detected package: " + ("Profile JSON" if preview_type == "profile" else "Unified backup"))
                    pcols = st.columns(4)
                    pcols[0].metric("Phrases", preview_summary.get("phrases_count", 0))
                    pcols[1].metric("Pages", preview_summary.get("collections_count", 0))
                    pcols[2].metric("Favourites", preview_summary.get("favourites_count", 0))
                    pcols[3].metric("Remembered", preview_summary.get("remembered_count", 0))
                    preserved_top = preview_summary.get("preserved_top_level_fields") or []
                    preserved_profile = preview_summary.get("preserved_profile_fields") or []
                    if preserved_top:
                        st.caption("Preserved top-level fields: " + ", ".join(preserved_top))
                    if preserved_profile:
                        st.caption("Preserved profile fields: " + ", ".join(preserved_profile))
                    for warning in preview_summary.get("warnings") or []:
                        st.warning(warning)
                except BackupValidationError as e:
                    st.error(str(e))
                    return
                except Exception as e:
                    st.error(f"Could not inspect upload: {e}")
                    return

                if st.button("Use Uploaded Backup", key="apply_backup_upload", use_container_width=True, type="primary"):
                    try:
                        package_type, imported = load_radix_json_bytes(uploaded_bytes)
                        set_active_backup(imported, uploaded.name, is_sample=False)
                        st.session_state["active_backup_upload_hash"] = upload_hash

                        profile = imported.get("profile", {}) if isinstance(imported.get("profile"), dict) else {}
                        if package_type == "profile":
                            config.import_profile_dict(profile)
                        if not state.get_remembered() and isinstance(profile.get("remembered_list"), list):
                            for item in reversed(profile.get("remembered_list", [])):
                                state.remember_character(item)

                        st.success("Radix profile imported." if package_type == "profile" else "Radix backup imported.")
                        st.rerun()
                    except BackupValidationError as e:
                        st.error(str(e))
                    except Exception as e:
                        st.error(f"Could not import backup: {e}")
            else:
                st.success("Current uploaded backup is active.")

        if st.session_state.get("active_backup_is_sample") is not True and os.path.exists(DEFAULT_SAMPLE_BACKUP_FILE):
            if st.button("Restore Permanent Sample Backup", key="restore_sample_backup", use_container_width=True):
                try:
                    set_active_backup(load_backup(DEFAULT_SAMPLE_BACKUP_FILE), DEFAULT_SAMPLE_BACKUP_FILE, is_sample=True)
                    st.rerun()
                except Exception as e:
                    st.error(str(e))

def render_sidebar():
    with st.sidebar:
        if os.path.exists(APP_LOGO_PATH):
            st.image(APP_LOGO_PATH, use_container_width=True)
        else:
            st.markdown("# 🈳 Radix")

        current_char = state.get("stroke_view_char") if state.is_stroke_view_active() else state.get_selected_component()
        if current_char:
            path_items = ["🏠 Search"] + state.get_history()
            if state.is_stroke_view_active():
                path_items.append(f"<i>{current_char}</i> (AI)")
            else:
                path_items.append(f"<b>{current_char}</b>")
            st.markdown(
                f"<div style='font-size:0.82em; margin:0 0 12px 0; padding:9px 12px; color:#faf8f4; background:#3d342a; border-radius:8px; text-align:center; font-weight:600; letter-spacing:0.02em;'>{' → '.join(path_items)}</div>",
                unsafe_allow_html=True,
            )

        st.markdown(
            """
            <style>
            .st-key-nav_pad [data-testid='stButton'] > button {
                height: 60px;
                min-height: 60px;
                border-radius: 10px;
                background: #f3efe8;
                border: 1px solid #e8e2d8;
                color: #3d342a;
                white-space: normal;
                font-size: 11px;
                font-weight: 600;
                line-height: 1.2;
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                gap: 3px;
                padding: 4px 2px;
                text-align: center;
                box-shadow: none;
                letter-spacing: 0.01em;
            }
            .st-key-nav_pad [data-testid='stButton'] > button:hover {
                border-color: #d8d0c4;
                background: #ede8df;
            }
            .st-key-nav_pad [data-testid='stButton'] > button[kind="primary"] {
                background: #e3ede9;
                border-color: #a0c4b8;
                color: #2a6b55;
            }
            .st-key-nav_pad [data-testid='stButton'] > button [data-testid='stMarkdownContainer'] {
                font-size: 11px;
                line-height: 1.1;
                color: inherit;
            }
            .st-key-nav_pad [data-testid='stButton'] > button [data-testid='stIconMaterial'] {
                font-size: 22px;
                line-height: 1;
            }
            .st-key-nav_bottom [data-testid='stButton'] > button {
                height: 44px;
                border-radius: 999px;
                font-size: 14px;
                font-weight: 500;
                border: 1px solid #e8e2d8;
                background: #f3efe8;
                color: #3d342a;
            }
            </style>
            """,
            unsafe_allow_html=True,
        )

        if state.is_stroke_view_active():
            current_char_for_sidebar = state.get("stroke_view_char")
        elif state.is_showing_inputs() or state.is_definition_search_active():
            current_char_for_sidebar = state.get_preview_component() or state.get_selected_component()
        else:
            current_char_for_sidebar = state.get_selected_component()

        # Determine active screen for nav highlight
        active_screen = state.get("home_screen", "search")
        in_search = state.is_showing_inputs() and active_screen == "search" and not state.get("dataset_editor_mode") and not state.get("backup_workspace_mode")
        in_browse = state.is_showing_inputs() and active_screen == "browse"
        in_favs = state.is_showing_inputs() and active_screen == "favourites"

        with st.container(key="nav_pad"):
            r1c1, r1c2, r1c3 = st.columns(3)
            with r1c1:
                if st.button("Search", key="nav_search_6", icon=":material/search:", help="Search characters", use_container_width=True, type="primary" if in_search else "secondary"):
                    open_search_screen()
                    st.rerun()
            with r1c2:
                has_pages = bool(active_backup_collections())
                browse_label = "Browse ●" if has_pages else "Browse"
                browse_help = "Browse dictionary & saved pages" if has_pages else "Browse all characters"
                if st.button(browse_label, key="nav_browse_6", icon=":material/grid_view:", help=browse_help, use_container_width=True, type="primary" if in_browse else "secondary"):
                    open_browse_screen()
                    st.rerun()
            with r1c3:
                if st.button("Favorites", key="nav_favs_6", icon=":material/star:", help="Your favorites", use_container_width=True, type="primary" if in_favs else "secondary"):
                    open_favourites_screen()
                    st.rerun()

            r2c1, r2c2, r2c3 = st.columns(3)
            with r2c1:
                if st.button("Backup", key="nav_backup_6", icon=":material/database:", help="Import / export backup", use_container_width=True):
                    open_backup_workspace()
                    st.rerun()

        back_disabled = state.is_showing_inputs() and (not state.is_stroke_view_active()) and (not state.get("dataset_editor_mode", False)) and (not state.get("backup_workspace_mode", False))
        with st.container(key="nav_bottom"):
            b1, b2 = st.columns(2)
            with b1:
                if st.button("← Back", key="nav_back_bottom", use_container_width=True, disabled=back_disabled):
                    if state.get("dataset_editor_mode", False):
                        close_dataset_editor()
                    elif state.get("backup_workspace_mode", False):
                        close_backup_workspace()
                    elif state.is_stroke_view_active():
                        state.exit_stroke_view()
                    else:
                        state.go_back()
                    st.rerun()
            with b2:
                if st.button("Search", key="nav_search_bottom", icon=":material/search:", use_container_width=True):
                    open_search_screen()
                    st.rerun()

        sidebar_phrase = state.get("sidebar_phrase_preview")
        if isinstance(sidebar_phrase, dict) and sidebar_phrase.get("word"):
            render_sidebar_phrase_card(sidebar_phrase)
            st.markdown("---")
        elif current_char_for_sidebar:
            if st.button("Replay", key=f"sidebar_replay_{current_char_for_sidebar}", icon=":material/replay:", use_container_width=True):
                st.rerun()
            render_sidebar_variant_animation_selector(current_char_for_sidebar)
            render_sidebar_character_controls(current_char_for_sidebar)

            notes = character_notes(current_char_for_sidebar)
            card_html = generate_clean_card_html(
                current_char_for_sidebar,
                usage_count=component_usage_count(current_char_for_sidebar),
                is_static=True,
                notes_override=notes,
                show_actions=False,
                show_parts=False,
            )
            st.markdown(f"<div style='margin-top: 15px;'>{card_html}</div>", unsafe_allow_html=True)
            render_sidebar_character_phrases(current_char_for_sidebar)
            render_sidebar_character_parts(current_char_for_sidebar)

            if get_active_backup() and state.get(f"sidebar_notes_open_{ord(current_char_for_sidebar[0])}", False):
                with st.expander("Edit character notes", expanded=True):
                    with st.form(f"sidebar_character_notes_{ord(current_char_for_sidebar[0])}"):
                        edited_notes = st.text_area("Notes", value=notes, height=120, key=f"sidebar_character_notes_text_{ord(current_char_for_sidebar[0])}")
                        if st.form_submit_button("Save", use_container_width=True):
                            try:
                                upsert_active_backup_character_notes(current_char_for_sidebar, edited_notes)
                                st.success("Character notes saved.")
                                st.rerun()
                            except Exception as e:
                                st.error(str(e))

            analysis = analyze_component_structure(current_char_for_sidebar)
            if analysis['semantic'] or analysis['phonetic']:
                s_txt = f"💡 <b>{analysis['semantic']}</b> = Meaning" if analysis['semantic'] else ""
                p_txt = f"📊 <b>{analysis['phonetic']}</b> = Sound" if analysis['phonetic'] else ""
                st.markdown(f"""
                <div style='background: #f3efe8; padding: 12px; border-radius: 10px; margin-top: 14px; border: 1px solid #e8e2d8;'>
                    <div style='font-weight:800; margin-bottom:6px; color: #1a1410; font-size: 0.88em; font-family: Noto Serif SC, serif;'>🧠 Logic Breakdown</div>
                    <div style='font-size: 0.84em; color: #3d342a; margin-bottom: 4px; line-height: 1.45;'>{s_txt}</div>
                    <div style='font-size: 0.84em; color: #3d342a; line-height: 1.45;'>{p_txt}</div>
                </div>
                """, unsafe_allow_html=True)

            st.markdown("---")
            st.checkbox("⭐ Favourite", value=(current_char_for_sidebar in state.get_favourites()), key=f"fav_chk_{current_char_for_sidebar}", on_change=toggle_favourite, args=(current_char_for_sidebar,))

        st.markdown("---")
        render_backup_panel()

        st.markdown("---")
        with st.expander("💾 User Data", expanded=False):
            st.info(f"💡 {PROFILE_FILENAME} auto-loads on startup if present in the app directory")
            st.markdown(render_ipad_safe_download_html(config.export_profile_str(), PROFILE_FILENAME, "📥 Download Profile"), unsafe_allow_html=True)

            st.caption("---")
            st.caption("**Manual Upload:**")
            if uf := st.file_uploader("📤 Upload JSON", type=["json"], key="sidebar_uploader", label_visibility="collapsed"):
                import hashlib
                hash_val = hashlib.sha256(uf.getvalue()).hexdigest()
                if hash_val != state.get('_last_upload_hash', ''):
                    st.warning("⚠️ New file detected")
                    if st.button("✅ Apply Now", use_container_width=True, type="primary", key="apply_upload"):
                        state.set("_last_upload_hash", hash_val)
                        config.import_profile_bytes(uf.getvalue())
                        st.rerun()
                else:
                    st.success("✓ Current file active")


def render_grid():
    """Render home routes as separate screens (Search/Browse/Favourites)."""
    screen = state.get("home_screen", "search")
    if screen == "browse":
        render_browse_screen()
    elif screen == "favourites":
        render_favourites_grid()
    else:
        persistence.show_resume_option()
        render_smart_search()


def render_phrase_info_card(phrase_data: dict, key_prefix: str = "", on_pick=None, collapse_after_pick: bool = False):
    """Render a compact phrase result row."""
    word = phrase_data.get("word", "")
    pinyin = phrase_data.get("pinyin", "")
    meanings = phrase_data.get("meanings", "")
    card_key = re.sub(r"[^0-9A-Za-z_]+", "_", f"{key_prefix}_{word}")[:80]
    short_meaning = (meanings or "").split(";")[0].split(",")[0].strip()[:60]

    col_a, col_b = st.columns([1, 8])
    with col_a:
        if st.button(word, key=f"{card_key}_select_phrase", use_container_width=True, help=meanings or "View phrase"):
            state.set("sidebar_phrase_preview", phrase_data)
            state.remember_character(word)
            st.rerun()
    with col_b:
        st.markdown(
            f"<div style='padding:6px 0; line-height:1.3;'>"
            f"<span style='font-family:Lora,serif; font-style:italic; color:#c0392b; font-size:0.95rem; font-weight:600; margin-right:10px;'>{pyhtml.escape(pinyin)}</span>"
            f"<span style='color:#3d342a; font-size:0.88rem;'>{pyhtml.escape(short_meaning)}</span>"
            f"</div>",
            unsafe_allow_html=True,
        )


def _phrase_animation_character(character: str, script_mode: str) -> str:
    if script_mode == "traditional" and cc_s2t:
        candidate = cc_s2t.convert(character)
        if candidate in component_map:
            return candidate
    if script_mode == "simplified" and cc_t2s:
        candidate = cc_t2s.convert(character)
        if candidate in component_map:
            return candidate
    return character


def render_sidebar_phrase_card(phrase_data: dict):
    """Render the Radix-style phrase card in the sidebar."""
    word = phrase_data.get("word", "")
    pinyin = phrase_data.get("pinyin", "")
    meanings = phrase_data.get("meanings", "")
    notes = phrase_data.get("notes", "")
    card_key = re.sub(r"[^0-9A-Za-z_]+", "_", f"sidebar_phrase_{word}")[:80]
    script_key = "phrase_info_animation_script"
    script_mode = state.get(script_key, "simplified")
    if script_mode not in {"simplified", "traditional"}:
        script_mode = "simplified"

    header_cols = st.columns([1, 1, 1, 1])
    with header_cols[0]:
        fav_icon = "★" if word in state.get_phrase_favourites() else "☆"
        if st.button(fav_icon, key=f"{card_key}_fav", use_container_width=True):
            state.toggle_phrase_favourite(word)
            st.rerun()
    with header_cols[1]:
        if st.button("简", key=f"{card_key}_simp", type="primary" if script_mode == "simplified" else "secondary", use_container_width=True):
            state.set(script_key, "simplified")
            st.rerun()
    with header_cols[2]:
        if st.button("繁", key=f"{card_key}_trad", type="primary" if script_mode == "traditional" else "secondary", use_container_width=True):
            state.set(script_key, "traditional")
            st.rerun()
    with header_cols[3]:
        if st.button("×", key=f"{card_key}_close", use_container_width=True):
            state.set("sidebar_phrase_preview", None)
            st.rerun()

    st.markdown(
        f"""
        <div class="radix-info-card" style="margin-bottom:10px;">
          <div class="radix-info-header">
            <div class="radix-info-header-body">
              <div class="radix-info-word">{pyhtml.escape(word)}</div>
              <div class="radix-info-pinyin" style="font-size:1.05rem; margin-top:4px;">{pyhtml.escape(pinyin) if pinyin else "—"}</div>
            </div>
          </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    phrase_chars = [c for c in word if c in component_map]
    if len(phrase_chars) > 1:
        st.markdown("<div class='radix-info-actions'><span class='radix-action-pill'>词 Phrase</span></div>", unsafe_allow_html=True)
        if st.button("Show phrase table", key=f"{card_key}_phrase_lookup", use_container_width=True):
            state.set("smart_search_input", word)
            state.set("home_screen", "search")
            state.go_to_root()
            st.rerun()

    if phrase_chars:
        st.markdown(
            "<div class='radix-section' style='margin-top:10px;'><div class='radix-section-label'>▦ Characters</div></div>",
            unsafe_allow_html=True,
        )
        animation_chars = [_phrase_animation_character(c, script_mode) for c in phrase_chars[:4]]
        grid_html, grid_height = get_phrase_animation_grid_html(animation_chars, size=108, element_key=card_key)
        if grid_html:
            st_html(grid_html, height=grid_height)
        cols = st.columns(2)
        for idx, raw_char in enumerate(phrase_chars[:4]):
            display_char = _phrase_animation_character(raw_char, script_mode)
            with cols[idx % 2]:
                if st.button(display_char, key=f"{card_key}_select_{idx}", use_container_width=True):
                    state.set("sidebar_phrase_preview", None)
                    _search_pick_char(display_char)
                    st.rerun()
        if len(phrase_chars) > 4:
            st.caption(f"Showing first 4 of {len(phrase_chars)} characters.")

    st.markdown(
        f"""
        <div class="radix-section" style="margin-top:10px;">
          <div class="radix-section-label">📕 Meaning</div>
          <div class="radix-section-text">{pyhtml.escape(meanings) if meanings else 'No meaning saved'}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )
    if notes:
        st.markdown(
            f"""
            <div class="radix-section soft" style="margin-top:10px;">
              <div class="radix-section-label">📝 Notes</div>
              <div class="radix-section-text notes">{pyhtml.escape(notes).replace(chr(10), '<br>')}</div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    if get_active_backup() and word in phrase_details_map(get_active_backup() or {}, [word]):
        with st.expander("Edit notes", expanded=False):
            with st.form(f"{card_key}_sidebar_notes_form"):
                edited_notes = st.text_area("Notes", value=notes, height=120, key=f"{card_key}_sidebar_notes")
                if st.form_submit_button("Save", use_container_width=True):
                    try:
                        upsert_active_backup_phrase(word, pinyin, meanings, edited_notes, phrase_data.get("review_status", ""))
                        updated = phrase_details_map(get_active_backup() or {}, [word]).get(word, phrase_data)
                        state.set("sidebar_phrase_preview", updated)
                        st.success("Notes saved.")
                        st.rerun()
                    except Exception as e:
                        st.error(str(e))


def _sidebar_variant_animation_options(char: str) -> list[tuple[str, str, str]]:
    simplified = cc_t2s.convert(char) if cc_t2s else char
    traditional = cc_s2t.convert(char) if cc_s2t else char
    raw_options = [("Simplified", "简", simplified), ("Traditional", "繁", traditional)]
    options = []
    seen = set()
    for title, badge, option_char in raw_options:
        option_char = (option_char or "").strip()[:1]
        if not option_char or option_char in seen:
            continue
        seen.add(option_char)
        options.append((title, badge, option_char))
    return options


def render_sidebar_variant_animation_selector(char: str):
    options = _sidebar_variant_animation_options(char)
    if not options:
        return

    st.markdown(
        """
        <style>
        .st-key-sidebar_variant_selector [data-testid="column"] {min-width:0 !important;}
        .st-key-sidebar_variant_selector .stButton > button {
            height:34px !important;
            min-height:34px !important;
            padding:2px 6px !important;
            border-radius:0 !important;
            background:#eeeeef !important;
            border:1px solid #e1e1e5 !important;
            color:#111 !important;
            font-size:14px !important;
            font-weight:800 !important;
            box-shadow:none !important;
        }
        .st-key-sidebar_variant_selector .stButton > button[kind="primary"] {
            border-color:#ff9f43 !important;
            box-shadow:inset 0 0 0 1px #ff9f43 !important;
        }
        </style>
        """,
        unsafe_allow_html=True,
    )

    with st.container(key="sidebar_variant_selector"):
        cols = st.columns(len(options))
        for idx, (title, badge, option_char) in enumerate(options):
            with cols[idx]:
                strokes = component_map.get(option_char, {}).get("stroke_count")
                stroke_text = f"{strokes}" if strokes else "?"
                button_type = "primary" if option_char == char else "secondary"
                if st.button(
                    f"{badge} {stroke_text}",
                    key=f"sidebar_variant_pick_{idx}_{ord(option_char)}",
                    help=f"Choose {title}: {option_char}",
                    type=button_type,
                    use_container_width=True,
                ):
                    if option_char != char:
                        state.enter_character_view(option_char)
                        st.rerun()
                anim_html, anim_height = get_stroke_animation_html(
                    option_char,
                    size=122 if len(options) > 1 else 140,
                    element_key=f"sidebar_variant_{idx}_{ord(option_char)}",
                    show_status=False,
                )
                if anim_html:
                    st_html(anim_html, height=anim_height)


def _sidebar_character_parts(char: str) -> list[str]:
    info = component_map.get(char, {})
    meta = info.get("meta", {}) if isinstance(info, dict) else {}
    decomp = meta.get("decomposition", "") or ""
    radical = clean_field(meta.get("radical", ""))
    parts = []
    seen = set()
    for part in decomp:
        if part in IDC_CHARS or part in {"?", "—"} or part == char:
            continue
        if part in component_map and part not in seen:
            seen.add(part)
            parts.append(part)
    if radical and radical in component_map and radical not in seen and radical != char:
        parts.insert(0, radical)
    return parts[:12]


def _sidebar_character_supersets(char: str) -> list[str]:
    related = component_map.get(char, {}).get("related_characters", [])
    children = [
        c for c in related
        if isinstance(c, str) and len(c) == 1 and c in component_map and c != char
    ]
    return list(dict.fromkeys(sorted(children, key=sort_key_usage_primary)))


def _sidebar_character_compounds(char: str, phrase_len: int) -> list[str]:
    raw_compounds = component_map.get(char, {}).get("meta", {}).get("compounds", [])
    if not raw_compounds and cc_t2s:
        simplified = cc_t2s.convert(char)
        if simplified != char:
            raw_compounds = component_map.get(simplified, {}).get("meta", {}).get("compounds", [])
    return sorted({w for w in (raw_compounds or []) if isinstance(w, str) and len(w) == phrase_len})


def _preview_character_in_context(char: str):
    state.set("sidebar_phrase_preview", None)
    state.remember_character(char)
    state.set("preview_comp", char)


def render_sidebar_character_controls(char: str):
    safe_key = ord(char[0])
    notes_key = f"sidebar_notes_open_{safe_key}"
    phrases_key = f"sidebar_phrases_open_{safe_key}"

    st.markdown(
        """
        <style>
        .st-key-sidebar_character_actions [data-testid="column"] {min-width:0 !important;}
        .st-key-sidebar_character_actions .stButton > button {
            height:38px !important;
            min-height:38px !important;
            border-radius:8px !important;
            font-weight:700 !important;
            color:#2a6b55 !important;
            background:#e3ede9 !important;
            border:1px solid #a0c4b8 !important;
            box-shadow:none !important;
        }
        .radix-structure-summary {
            display:grid;
            grid-template-columns:1fr 1fr;
            gap:8px;
            margin-top:10px;
        }
        .radix-structure-panel {
            background:#f3efe8;
            border-radius:8px;
            padding:10px;
            min-width:0;
            border:1px solid #e8e2d8;
        }
        .radix-structure-title {
            color:#6b5e52;
            font-size:0.72rem;
            font-weight:700;
            text-transform:uppercase;
            letter-spacing:0.04em;
            line-height:1.1;
            margin-bottom:4px;
        }
        .radix-structure-count {
            color:#1a1410;
            font-size:1.05rem;
            font-weight:800;
            line-height:1.15;
        }
        .st-key-sidebar_parts_grid,
        .st-key-sidebar_superset_grid,
        .st-key-sidebar_part_association_grid {
            background:#f3efe8;
            border-radius:8px;
            padding:10px;
            margin-top:10px;
            border:1px solid #e8e2d8;
        }
        .st-key-sidebar_parts_grid .stButton > button,
        .st-key-sidebar_superset_grid .stButton > button,
        .st-key-sidebar_part_association_grid .stButton > button {
            min-height:58px !important;
            border-radius:8px !important;
            font-size:1.35rem !important;
            font-weight:800 !important;
            color:#c0392b !important;
            background:#fff !important;
            border:1px solid #e8e2d8 !important;
            box-shadow:none !important;
            white-space:normal !important;
            line-height:1.0 !important;
            font-family:'Noto Serif SC',serif !important;
        }
        </style>
        """,
        unsafe_allow_html=True,
    )

    with st.container(key="sidebar_character_actions"):
        notes_col, phrases_col = st.columns(2)
        with notes_col:
            if st.button("□✎ Notes", key=f"sidebar_notes_btn_{safe_key}", use_container_width=True):
                state.set(notes_key, not state.get(notes_key, False))
        with phrases_col:
            if st.button("词 Phrases", key=f"sidebar_phrases_btn_{safe_key}", use_container_width=True):
                state.set(phrases_key, not state.get(phrases_key, False))


def render_sidebar_character_phrases(char: str):
    safe_key = ord(char[0])
    if not state.get(f"sidebar_phrases_open_{safe_key}", False):
        return

    current_mode = state.get_display_mode()
    try:
        current_len = int(current_mode[0])
    except Exception:
        current_len = 2
    if current_len not in {2, 3, 4}:
        current_len = 2

    phrase_len = st.radio(
        "Phrase length",
        options=[2, 3, 4],
        index=[2, 3, 4].index(current_len),
        horizontal=True,
        key=f"sidebar_phrase_len_{safe_key}",
        label_visibility="collapsed",
    )
    state.set("display_mode", f"{phrase_len}-Characters")

    compounds = _sidebar_character_compounds(char, phrase_len)
    if not compounds:
        st.caption("No saved phrases for this length.")
        return

    phrase_map = get_phrase_details(compounds, get_db_connection())
    for idx, word in enumerate(compounds[:16]):
        entry = phrase_map.get(word, {"word": word, "pinyin": "", "meanings": ""})
        label = f"{word}  {entry.get('pinyin', '')}".strip()
        if st.button(label, key=f"sidebar_phrase_pick_{safe_key}_{idx}_{abs(hash(word))}", use_container_width=True):
            state.set("sidebar_phrase_preview", entry)
            state.remember_character(word)
            st.rerun()
        meaning = (entry.get("meanings") or "").strip()
        if meaning:
            st.caption(meaning[:120] + ("..." if len(meaning) > 120 else ""))


def render_sidebar_character_parts(char: str):
    parts = _sidebar_character_parts(char)
    supersets = _sidebar_character_supersets(char)
    safe_key = ord(char[0])
    part_focus_key = f"sidebar_part_focus_{safe_key}"
    focused_part = state.get(part_focus_key, "")
    if focused_part not in parts:
        focused_part = parts[0] if parts else ""
        state.set(part_focus_key, focused_part)

    st.markdown(
        f"""
        <div class="radix-structure-summary">
          <div class="radix-structure-panel">
            <div class="radix-structure-title">Built From</div>
            <div class="radix-structure-count">{len(parts) if parts else 'Root'}</div>
          </div>
          <div class="radix-structure-panel">
            <div class="radix-structure-title">Used In</div>
            <div class="radix-structure-count">{len(supersets)}</div>
          </div>
        </div>
        """,
        unsafe_allow_html=True,
    )

    if not parts:
        st.caption("No smaller saved parts. This behaves like a root in the current data.")
    else:
        st.markdown("<div class='radix-section-label' style='margin-top:10px;'>🧩 Built From</div>", unsafe_allow_html=True)
        with st.container(key="sidebar_parts_grid"):
            cols = st.columns(min(3, len(parts)))
            for idx, part in enumerate(parts):
                with cols[idx % len(cols)]:
                    pinyin = clean_field(component_map.get(part, {}).get("meta", {}).get("pinyin", ""))
                    label = f"{part}\n{pinyin}" if pinyin else part
                    if st.button(
                        label,
                        key=f"sidebar_part_{safe_key}_{idx}_{ord(part)}",
                        help=f"Show characters associated with {part}",
                        type="primary" if part == focused_part else "secondary",
                        use_container_width=True,
                    ):
                        state.set(part_focus_key, part)
                        st.rerun()

        focused_supersets = _sidebar_character_supersets(focused_part) if focused_part else []
        if focused_part:
            st.markdown(
                f"<div class='radix-section-label' style='margin-top:10px;'>Characters Using {pyhtml.escape(focused_part)}</div>",
                unsafe_allow_html=True,
            )
            if not focused_supersets:
                st.caption(f"No larger characters currently use {focused_part}.")
            else:
                preview_related = focused_supersets[:18]
                with st.container(key="sidebar_part_association_grid"):
                    cols = st.columns(3)
                    for idx, related_char in enumerate(preview_related):
                        with cols[idx % 3]:
                            if st.button(
                                related_char,
                                key=f"sidebar_part_assoc_{safe_key}_{ord(focused_part)}_{idx}_{ord(related_char)}",
                                help=f"Preview {related_char} while keeping {char} selected",
                                use_container_width=True,
                            ):
                                _preview_character_in_context(related_char)
                                st.rerun()
                if len(focused_supersets) > len(preview_related):
                    st.caption(f"Showing {len(preview_related)} of {len(focused_supersets)} associated characters.")

    st.markdown("<div class='radix-section-label' style='margin-top:10px;'>🌲 Used In</div>", unsafe_allow_html=True)
    if not supersets:
        st.caption("No larger characters in the current data use this as a component.")
        return

    if st.button(f"Open full used-in map ({len(supersets)})", key=f"sidebar_superset_all_{safe_key}", use_container_width=True):
        state.set("sidebar_phrase_preview", None)
        state.enter_character_view(char)
        st.rerun()

    preview_supersets = supersets[:12]
    with st.container(key="sidebar_superset_grid"):
        cols = st.columns(3)
        for idx, child in enumerate(preview_supersets):
            with cols[idx % 3]:
                if st.button(child, key=f"sidebar_superset_{safe_key}_{idx}_{ord(child)}", help=f"Preview {child} while keeping {char} selected", use_container_width=True):
                    _preview_character_in_context(child)
                    st.rerun()
    if len(supersets) > len(preview_supersets):
        st.caption(f"Showing {len(preview_supersets)} of {len(supersets)}. Use the full map for the rest.")


def render_smart_search(key_prefix: str = "", on_pick=None, collapse_after_pick: bool = False):
    """Render Radix-style Smart/Definition search."""
    selected_key = f"{key_prefix}selected_char"
    if collapse_after_pick and st.session_state.get(selected_key):
        chosen = st.session_state.get(selected_key)
        st.success(f"Selected character: {chosen}")
        if st.button("Change character", key=f"{key_prefix}change_char", use_container_width=False):
            st.session_state[selected_key] = ""
            st.session_state[f"{key_prefix}smart_search_input"] = ""
            st.rerun()
        return

    query = st.text_input(
        "Search",
        key=f"{key_prefix}smart_search_input",
        placeholder="Search by character, pinyin, or English meaning…",
        label_visibility="collapsed",
    )

    # Detect if English search is appropriate
    def _is_english_query(q):
        return bool(q) and all(ord(ch) < 0x4E00 or ord(ch) > 0x9FFF for ch in q) and q[0] != "="

    if not query:
        # Empty state — show helpful prompt
        st.markdown(
            "<div style='padding:32px 0 16px 0; text-align:center; color:#a89e94; font-size:0.95rem;'>"
            "Try <b>水</b> for a character · <b>shuǐ</b> for pinyin · <b>water</b> for meaning"
            "</div>",
            unsafe_allow_html=True,
        )
        return

    raw_query = query.strip()
    search_query, is_forced_english = _parse_radix_search_query(raw_query)
    is_english = is_forced_english or _is_english_query(search_query)

    if len(search_query) < 1:
        st.warning("Please enter at least 1 character.")
        return

    # Single CJK character — go straight to character view
    if len(search_query) == 1 and search_query in component_map and not is_forced_english:
        if on_pick or collapse_after_pick:
            _search_pick_char(search_query, key_prefix=key_prefix, on_pick=on_pick, collapse_after_pick=collapse_after_pick)
        else:
            state.remember_character(search_query)
            state.enter_character_view(search_query)
            st.rerun()
        return

    # Multi-character CJK phrase
    if not is_forced_english and len(search_query) > 1 and all('\u4e00' <= c <= '\u9fff' for c in search_query):
        db_conn = get_db_connection()
        phrase_data = get_phrase_details([search_query], db_conn)
        if search_query in phrase_data:
            entry = phrase_data[search_query]
            state.remember_character(search_query)
            current_sidebar_phrase = state.get("sidebar_phrase_preview")
            if not isinstance(current_sidebar_phrase, dict) or current_sidebar_phrase.get("word") != search_query:
                state.set("sidebar_phrase_preview", entry)
                st.rerun()
            st.info(f"Showing phrase **{search_query}** in the sidebar.")
            return

    db_conn = get_db_connection()
    if is_english:
        results = radix_definition_character_search(search_query, is_strict=is_forced_english, limit=120)
        phrase_results = search_phrase_meanings(search_query, db_conn, limit=120, is_strict=is_forced_english)
    else:
        results = radix_smart_character_search(search_query, limit=300)
        meaning_phrases = search_phrase_meanings(search_query, db_conn, limit=120) if len(search_query) >= 2 else []
        pinyin_phrases = search_phrase_pinyin(search_query, db_conn, limit=120) if len(normalize_pinyin(search_query)) > 2 else []
        phrase_results = merge_phrase_results(meaning_phrases, pinyin_phrases, limit=120)

    if not results and not phrase_results:
        st.markdown(
            f"<div style='padding:24px 0; text-align:center; color:#a89e94; font-size:0.95rem;'>"
            f"No matches for <b>{pyhtml.escape(search_query)}</b></div>",
            unsafe_allow_html=True,
        )
        return

    if results:
        count_label = f"{len(results)} character{'s' if len(results) != 1 else ''}"
        st.markdown(
            f"<div style='font-size:0.8rem; color:#6b5e52; font-weight:700; text-transform:uppercase; "
            f"letter-spacing:0.05em; margin-bottom:8px;'>{count_label}</div>",
            unsafe_allow_html=True,
        )
        st.markdown("<div class='comp-grid'>", unsafe_allow_html=True)
        display_results = results[:100]
        cols = st.columns(GRID_COLUMNS)
        for i, ch in enumerate(display_results):
            with cols[i % GRID_COLUMNS]:
                st.button(
                    ch,
                    key=f"{key_prefix}smart_res_{ch}_{i}",
                    type="secondary",
                    on_click=_search_pick_char,
                    args=(ch,),
                    kwargs={
                        "key_prefix": key_prefix,
                        "on_pick": on_pick,
                        "collapse_after_pick": collapse_after_pick,
                    },
                    use_container_width=True,
                )
        st.markdown("</div>", unsafe_allow_html=True)

        if len(results) > 100:
            st.caption(f"Showing first 100 of {len(results)} results.")

    if phrase_results:
        if results:
            st.markdown("<div style='height:8px'></div>", unsafe_allow_html=True)
        phrase_label = f"{len(phrase_results)} phrase{'s' if len(phrase_results) != 1 else ''}"
        st.markdown(
            f"<div style='font-size:0.8rem; color:#6b5e52; font-weight:700; text-transform:uppercase; "
            f"letter-spacing:0.05em; margin-bottom:8px;'>{phrase_label}</div>",
            unsafe_allow_html=True,
        )
        for phrase_data in phrase_results[:50]:
            render_phrase_info_card(phrase_data, key_prefix=f"{key_prefix}phrase_result", on_pick=on_pick, collapse_after_pick=collapse_after_pick)
        if len(phrase_results) > 50:
            st.caption(f"Showing first 50 of {len(phrase_results)} phrase results.")


def render_browse_screen():
    backup = get_active_backup()
    has_pages = bool(active_backup_collections())
    mode_options = ["Dictionary", "Saved Pages"] if has_pages else ["Dictionary"]
    current_mode = state.get("browse_content_mode", "Dictionary")
    if current_mode not in mode_options:
        current_mode = "Dictionary"

    if has_pages:
        # Prominent tab-style toggle so Pages is never hidden
        tab_cols = st.columns(2)
        with tab_cols[0]:
            dict_active = current_mode == "Dictionary"
            if st.button("📖  Dictionary", key="browse_tab_dict", use_container_width=True,
                         type="primary" if dict_active else "secondary"):
                if not dict_active:
                    state.set("browse_content_mode", "Dictionary")
                    state.set("page", 1)
                    st.rerun()
        with tab_cols[1]:
            pages_active = current_mode == "Saved Pages"
            n_pages = len(active_backup_collections())
            if st.button(f"📄  Pages ({n_pages})", key="browse_tab_pages", use_container_width=True,
                         type="primary" if pages_active else "secondary"):
                if not pages_active:
                    state.set("browse_content_mode", "Saved Pages")
                    state.set("page", 1)
                    st.rerun()
        mode = current_mode
    else:
        mode = "Dictionary"

    state.set("browse_content_mode", mode)

    if mode == "Saved Pages":
        if not backup:
            st.info("Import a Radix backup to browse saved pages.")
            return
        render_saved_pages_browser()
    else:
        render_all_components_grid()


def _page_phrase_tiles(collection: dict, start_idx: int, end_idx: int) -> dict[int, dict]:
    chars = collection.get("characters") or []
    start_idx = max(0, min(start_idx, len(chars)))
    end_idx = max(start_idx, min(end_idx, len(chars)))
    visible_chars = chars[start_idx:end_idx]
    if len(visible_chars) < 2:
        return {}

    conn = get_db_connection()
    max_phrase_length = _max_base_phrase_length(conn)
    phrase_by_lookup_word = _fetch_page_phrase_lookup(collection, max_phrase_length, conn, start_idx, end_idx)
    hidden = {_phrase_storage_word(w) for w in collection.get("hiddenPhraseWords") or []}
    lookup_chars = [_phrase_lookup_target(c) for c in visible_chars]
    matches = []

    for local_offset in range(len(lookup_chars)):
        max_length = min(max_phrase_length, len(lookup_chars) - local_offset)
        if max_length < 2:
            continue
        for length in range(2, max_length + 1):
            local_end = local_offset + length
            segment = "".join(lookup_chars[local_offset:local_end])
            phrase = phrase_by_lookup_word.get(segment)
            if not phrase or _phrase_storage_word(phrase.get("word", "")) in hidden:
                continue
            start = start_idx + local_offset
            end = start_idx + local_end
            matches.append({"phrase": phrase, "start": start, "end": end, "offsets": list(range(start, end))})

    matches.sort(
        key=lambda m: (
            -(m["end"] - m["start"]),
            m["start"],
            normalize_pinyin(m["phrase"].get("pinyin", ""), fuzzy_initials=True),
            m["phrase"].get("word", ""),
        )
    )

    occupied: set[int] = set()
    tiles: dict[int, dict] = {}
    for match in matches:
        offsets = set(range(match["start"], match["end"]))
        if occupied.isdisjoint(offsets):
            tiles[match["start"]] = match
            occupied.update(offsets)
    return tiles


def build_collection_ai_prompt(collection: dict) -> str:
    name = collection_display_name(collection)
    chars = "".join(c for c in (collection.get("characters") or []) if isinstance(c, str))
    cfg = state.get("prompt_config") or {}
    preamble = (cfg.get("collectionPreamble") or "").strip()
    if not preamble:
        preamble = (
            "You are a bilingual Chinese dictionary editor and teacher.\n\n"
            "Work with a page of Chinese characters extracted from OCR or manual input. "
            "Treat the page as the subject rather than analyzing one character at a time.\n"
        )

    values = {
        "collection_name": name,
        "capture_chars": chars,
        "capture_text": chars,
    }
    task_blocks = []
    for task in cfg.get("tasks") or []:
        if not isinstance(task, dict):
            continue
        title = str(task.get("title") or "")
        template = str(task.get("template") or "")
        is_page_task = (
            "{collection_name}" in template
            or "{capture_chars}" in template
            or "{capture_text}" in template
            or "Extract Phrases" in title
            or "Translate" in title
        )
        if not is_page_task:
            continue
        try:
            task_blocks.append(template.format(**values))
        except Exception:
            task_blocks.append(template)

    if not task_blocks:
        task_blocks.append(
            "Translate\n\n"
            "Create a concise bilingual report for this saved page. Decode useful vocabulary, "
            "phrases, contractions, and overall meaning for a Chinese learner.\n\n"
            "Source Material:\n"
            f"Image/Source: {name}\n"
            f"Characters: {chars}\n"
        )

    return "\n\n".join([preamble, *task_blocks]).strip()


def render_saved_pages_browser():
    collections = sorted_active_backup_collections(state.get("browse_page_sort_order", "Viewed"))
    if not collections:
        st.info("No saved pages in this backup.")
        return

    sort_order = state.get("browse_page_sort_order", "Viewed")
    collections = sorted_active_backup_collections(sort_order)
    labels = [
        f"{'★ ' if c.get('isFavorite') else ''}{collection_display_name(c)} · {len(c.get('characters') or [])} chars"
        for c in collections
    ]
    collection_ids = [str(c.get("id", "")) for c in collections]
    label_by_id = {collection_id: labels[idx] for idx, collection_id in enumerate(collection_ids)}
    collection_by_id = {collection_id: collections[idx] for idx, collection_id in enumerate(collection_ids)}
    current_id = state.get("selected_browse_collection_id", "")
    current_index = collection_ids.index(current_id) if current_id in collection_ids else 0
    selected_id = collection_ids[current_index]
    selected_collection = collection_by_id.get(selected_id, collections[current_index])

    collection = selected_collection
    if not collection:
        st.info("Page not found.")
        return

    chars = [c for c in collection.get("characters") or [] if isinstance(c, str) and c]
    with st.container(key="browse_page_tools"):
        tool_cols = st.columns([3.7, 1.0, 0.7, 0.7, 0.8])
        with tool_cols[0]:
            selected_control_id = st.selectbox(
                "Page",
                options=collection_ids,
                index=current_index,
                format_func=lambda collection_id: label_by_id.get(collection_id, "Untitled"),
                key="browse_page_selectbox_id",
                label_visibility="collapsed",
            )
            if selected_control_id != selected_id:
                new_collection = collection_by_id.get(selected_control_id)
                if new_collection:
                    new_collection["lastViewedAt"] = _cocoa_timestamp()
                    state.set("selected_browse_collection_id", new_collection.get("id", ""))
                    state.set("page", 1)
                    refresh_active_backup_summary()
                    st.rerun()
        with tool_cols[1]:
            sort_order = st.segmented_control(
                "Page order",
                options=["Viewed", "Scanned"],
                default=sort_order if sort_order in {"Viewed", "Scanned"} else "Viewed",
                key="browse_page_sort_segmented",
                label_visibility="collapsed",
                width="stretch",
            )
            sort_order = sort_order or state.get("browse_page_sort_order", "Viewed")
            if sort_order != state.get("browse_page_sort_order", "Viewed"):
                state.set("browse_page_sort_order", sort_order)
                st.rerun()
            state.set("browse_page_sort_order", sort_order)
        with tool_cols[2]:
            script_mode = st.segmented_control(
                "Image script",
                options=["简", "繁"],
                default="繁" if state.get("browse_page_script_mode", "simplified") == "traditional" else "简",
                key="browse_page_script_segmented",
                label_visibility="collapsed",
                width="stretch",
            )
            state.set("browse_page_script_mode", "traditional" if script_mode == "繁" else "simplified")
        with tool_cols[3]:
            if st.button("Report", key="browse_page_report_toggle", use_container_width=True):
                state.set("browse_page_show_translation", not state.get("browse_page_show_translation", False))
                st.rerun()
        with tool_cols[4]:
            if st.button("AI Link", key="browse_page_ai_link", use_container_width=True):
                state.set("browse_page_show_ai_link", not state.get("browse_page_show_ai_link", False))
                st.rerun()

    if state.get("browse_page_show_translation", False):
        expanded = bool(state.get("browse_page_show_translation", False))
        st.markdown("<div class='browse-page-translation'>", unsafe_allow_html=True)
        with st.expander("Report", expanded=expanded):
            report_text = (collection.get("translationReport", "") or "").strip()
            if report_text:
                st.markdown(pyhtml.escape(report_text).replace("\n", "<br>"), unsafe_allow_html=True)
            else:
                st.caption("No report saved for this page.")
        st.markdown("</div>", unsafe_allow_html=True)

    if state.get("browse_page_show_ai_link", False):
        prompt_text = build_collection_ai_prompt(collection)
        with st.expander("AI Link", expanded=True):
            st.text_area("Page prompt", value=prompt_text, height=260, label_visibility="collapsed")
            render_copy_to_clipboard(prompt_text, f"page_ai_{collection.get('id', 'page')}")

    if not chars:
        st.info("This page has no saved characters.")
        return

    total = len(chars)
    max_page = max(1, math.ceil(total / BROWSE_PAGE_SIZE))
    page = max(1, min(state.get_current_page(), max_page))
    state.set("page", page)

    p1, p2, p3 = st.columns([1, 3, 1])
    with p1:
        if st.button("◀ Prev", disabled=page <= 1, use_container_width=True, key="browse_page_prev"):
            state.set("page", page - 1)
            st.rerun()
    with p2:
        st.markdown(
            f"<div style='text-align:center; padding:4px 0; color:#555; font-size:0.9rem; font-weight:700;'>{(page - 1) * BROWSE_PAGE_SIZE + 1}–{min(page * BROWSE_PAGE_SIZE, total)} / {total}</div>",
            unsafe_allow_html=True,
        )
    with p3:
        if st.button("Next ▶", disabled=page >= max_page, use_container_width=True, key="browse_page_next"):
            state.set("page", page + 1)
            st.rerun()

    start_idx = (page - 1) * BROWSE_PAGE_SIZE
    end_idx = min(page * BROWSE_PAGE_SIZE, total)
    tiles = _page_phrase_tiles(collection, start_idx, end_idx)
    display_items = []
    offset = start_idx
    while offset < end_idx:
        phrase_tile = tiles.get(offset)
        if phrase_tile and phrase_tile["end"] <= end_idx:
            display_items.append(("phrase", offset, phrase_tile))
            offset = phrase_tile["end"]
        else:
            display_items.append(("character", offset, chars[offset]))
            offset += 1

    with st.container(key="browse_page_flow"):
        for row_start in range(0, len(display_items), BROWSE_PAGE_COLUMNS):
            cols = st.columns(BROWSE_PAGE_COLUMNS, gap="small")
            row_items = display_items[row_start : row_start + BROWSE_PAGE_COLUMNS]
            for col, (kind, offset, payload) in zip(cols, row_items):
                with col:
                    if kind == "phrase":
                        phrase = payload["phrase"]
                        word = phrase.get("word", "")
                        label = _browse_page_tile_label(word, phrase.get("pinyin", ""))
                        safe_word = re.sub(r"[^0-9A-Za-z_]+", "_", word)[:40]
                        if st.button(label, key=f"browse_page_phrase_{offset}_{safe_word}", help=phrase.get("meanings", ""), use_container_width=True):
                            state.set("sidebar_phrase_preview", phrase)
                            state.remember_character(word)
                            st.rerun()
                    else:
                        ch = payload
                        display_ch = _browse_page_display_text(ch)
                        label = _browse_page_tile_label(ch)
                        st.button(
                            label,
                            key=f"browse_page_char_{offset}_{ord(ch[0]) if ch else 0}",
                            type="primary" if state.get_preview_component() in {ch, display_ch} else "secondary",
                            on_click=tile_click,
                            args=(ch,),
                            use_container_width=True,
                        )

    # Phrase selection — inline, below the page tiles
    render_page_phrase_selector(collection)


def render_page_phrase_selector(collection: dict):
    """Inline phrase selector for Browse → Pages. Controls which phrases appear as tiles."""
    collection_id = collection.get("id", "")
    candidates = page_phrase_candidates(collection)
    if not candidates:
        return

    hidden = set(collection.get("hiddenPhraseWords") or [])
    n_hidden = sum(1 for p in candidates if p.get("word", "") in hidden)
    n_shown = len(candidates) - n_hidden

    label = f"✦ Phrases on this page ({n_shown} shown"
    if n_hidden:
        label += f", {n_hidden} hidden"
    label += ")"

    with st.expander(label, expanded=False):
        st.caption("Check a phrase to show it as a tile on this page. Uncheck to hide it.")
        shown = candidates[:100]
        for phrase in shown:
            word = phrase.get("word", "")
            pinyin = phrase.get("pinyin", "")
            meaning = phrase.get("meanings", "")[:70]
            st.checkbox(
                f"{word}  ·  {pinyin}  ·  {meaning}",
                value=word not in hidden,
                key=f"browse_phrase_sel_{collection_id}_{word}",
            )

        if st.button("Save", key=f"browse_save_phrase_sel_{collection_id}", type="primary", use_container_width=True):
            try:
                hidden_words = [
                    p.get("word", "") for p in shown
                    if not st.session_state.get(f"browse_phrase_sel_{collection_id}_{p.get('word', '')}", True)
                ]
                # Preserve hidden state for candidates not rendered here
                hidden_words.extend([w for w in hidden if w not in {p.get("word", "") for p in shown}])
                set_collection_hidden_phrases(collection_id, hidden_words)
                st.toast("Phrase selection saved.", icon="✅")
                st.rerun()
            except Exception as e:
                st.error(str(e))

        if len(candidates) > len(shown):
            st.caption(f"Showing first {len(shown)} of {len(candidates)} matching phrases.")


def render_all_components_grid():
    # Build active-filter summary for the expander label
    cur_min, cur_max_stroke = state.get_stroke_range()
    active_rad = state.get("radical", "none")
    active_idc = state.get("component_idc", "none")
    active_script = state.get("grid_script_filter", "Any")
    active_sort = state.get_grid_sort_mode()
    filter_parts = []
    if (cur_min, cur_max_stroke) != (3, 8):
        filter_parts.append(f"{cur_min}–{cur_max_stroke} strokes")
    if active_rad != "none":
        filter_parts.append(f"radical: {active_rad}")
    if active_idc != "none":
        filter_parts.append(f"structure: {active_idc}")
    if active_script != "Any":
        filter_parts.append(active_script)
    if active_sort == "frequency":
        filter_parts.append("by frequency")
    filter_summary = "  ·  ".join(filter_parts) if filter_parts else "All characters"
    expander_label = f"🔧 Filters  —  {filter_summary}"

    with st.expander(expander_label, expanded=False):
        col_sort, col_script = st.columns([1.2, 1.2])

        with col_sort:
            mode_map = {
                "usage": "Component frequency",
                "frequency": "Character frequency",
            }
            current_mode = state.get_grid_sort_mode()
            if current_mode not in mode_map:
                current_mode = "usage"
            options = ["Component frequency", "Character frequency"]
            sort_choice = st.radio(
                "Sort by",
                options=options,
                index=options.index(mode_map[current_mode]),
                horizontal=True,
                key="grid_sort_radio",
            )
            selected_mode = {v: k for k, v in mode_map.items()}[sort_choice]
            state.set("grid_sort_mode", selected_mode)

        with col_script:
            gsf = state.get("grid_script_filter", "Any")
            script_choice = st.radio(
                "Script",
                options=["Simplified", "Traditional", "Any"],
                index=["Simplified", "Traditional", "Any"].index(gsf),
                horizontal=True,
                key="grid_script_radio",
            )
            state.set("grid_script_filter", script_choice)

        col_stroke, col_radical, col_idc = st.columns([2, 2, 2])

        with col_stroke:
            stroke_range = st.slider("Strokes", 1, 30, value=state.get_stroke_range(), key="grid_stroke_slider")
            state.set("stroke_range", stroke_range)

        with col_radical:
            rad_groups = stats_cache.get("rad_groups", {})
            radical_options = ["none"]
            for stroke_count in sorted(rad_groups.keys()):
                rads_in_group = rad_groups[stroke_count]
                if rads_in_group:
                    for rad in rads_in_group:
                        radical_options.append(rad)

            def format_radical(rad):
                if rad == "none":
                    return "Any radical"
                rad_info = component_map.get(rad, {})
                strokes = rad_info.get("stroke_count")
                if strokes:
                    return f"{rad} ({strokes} strokes)"
                return rad

            current_rad = state.get("radical", "none")
            current_index = radical_options.index(current_rad) if current_rad in radical_options else 0
            radical_choice = st.selectbox(
                "Radical",
                options=radical_options,
                format_func=format_radical,
                index=current_index,
                key="grid_radical_select",
            )
            state.set("radical", radical_choice)

        with col_idc:
            idcs = sorted(stats_cache.get("idc_counts", {}).keys())
            idc = state.get("component_idc", "none")
            idc_choice = st.selectbox(
                "Structure",
                options=["none"] + idcs,
                format_func=lambda x: "Any structure" if x == "none" else x,
                index=(["none"] + idcs).index(idc) if idc in idcs else 0,
                key="grid_idc_select",
            )
            state.set("component_idc", idc_choice)

        if filter_parts:
            if st.button("✕ Clear all filters", key="grid_clear_filters"):
                state.set("stroke_range", (3, 8))
                state.set("radical", "none")
                state.set("component_idc", "none")
                state.set("grid_script_filter", "Any")
                state.set("grid_sort_mode", "usage")
                st.rerun()

    cur_min, cur_max = state.get_stroke_range()
    filtered = [c for c in component_map if (s := get_stroke_count(c)) is not None and cur_min <= s <= cur_max]

    if state.get("radical") != "none":
        filtered = [c for c in filtered if component_map[c]["meta"].get("radical") == state.get("radical")]

    if state.get("component_idc") != "none":
        filtered = [c for c in filtered if component_map[c]["meta"].get("decomposition", "").startswith(state.get("component_idc"))]

    if state.get_grid_sort_mode() == "usage":
        filtered = [c for c in filtered if c in stats_cache["used_components"]]

    if state.get_grid_sort_mode() == "frequency":
        filtered = apply_script_filter(filtered, state.get("grid_script_filter"))

    sorted_comps = sorted(
        filtered,
        key=sort_key_frequency_primary if state.get_grid_sort_mode() == "frequency" else sort_key_usage_primary,
    )

    if not sorted_comps:
        st.info("No components match filters.")
        return

    total = len(sorted_comps)
    max_page = max(1, math.ceil(total / PAGE_SIZE))
    page = max(1, min(state.get_current_page(), max_page))
    state.set("page", page)

    p1, p2, p3 = st.columns([1, 3, 1])
    with p1:
        if st.button("← Prev", disabled=page <= 1, use_container_width=True, key="grid_prev"):
            state.set("page", page - 1)
            st.rerun()
    with p2:
        st.markdown(
            f"<div style='text-align:center; padding:9px 0; color:#6b5e52; font-size:0.88rem; font-weight:600;'>"
            f"Page {page} of {max_page} &nbsp;·&nbsp; {(page-1)*PAGE_SIZE+1}–{min(page*PAGE_SIZE,total)} of {total}"
            f"</div>",
            unsafe_allow_html=True,
        )
    with p3:
        if st.button("Next →", disabled=page >= max_page, use_container_width=True, key="grid_next"):
            state.set("page", page + 1)
            st.rerun()

    page_items = sorted_comps[(page - 1) * PAGE_SIZE : page * PAGE_SIZE]

    st.markdown("<div class='comp-grid'>", unsafe_allow_html=True)
    cols = st.columns(GRID_COLUMNS)
    for i, ch in enumerate(page_items):
        with cols[i % GRID_COLUMNS]:
            st.button(
                _browse_page_tile_label(ch),
                key=f"grid_{ch}_{page}",
                type="primary" if state.get_preview_component() == ch else "secondary",
                on_click=tile_click,
                args=(ch,),
                use_container_width=True,
            )
    st.markdown("</div>", unsafe_allow_html=True)



def render_favourites_grid():
    favs = state.get_favourites()
    phrase_favs = state.get_phrase_favourites()
    has_chars = bool(favs)
    has_phrases = bool(phrase_favs)

    if not has_chars and not has_phrases:
        st.markdown(
            "<div style='padding:48px 0; text-align:center;'>"
            "<div style='font-size:2.5rem; margin-bottom:12px;'>★</div>"
            "<div style='color:#3d342a; font-weight:700; font-size:1.05rem; margin-bottom:6px;'>No favourites yet</div>"
            "<div style='color:#a89e94; font-size:0.88rem;'>Star a character (⭐ in the sidebar) or a phrase (★ on the phrase card) to save it here.</div>"
            "</div>",
            unsafe_allow_html=True,
        )
        return

    # ── Starred characters ─────────────────────────────────────
    if has_chars:
        st.markdown(
            f"<div style='font-size:0.8rem; color:#6b5e52; font-weight:700; text-transform:uppercase; "
            f"letter-spacing:0.05em; margin-bottom:8px;'>"
            f"★ Characters ({len(favs)})</div>",
            unsafe_allow_html=True,
        )
        with st.expander("Edit character list", expanded=False):
            fav_txt = st.text_area("Edit (space/newline separated)", value=" ".join(favs), height=90, key="fav_bulk_editor")
            c1, c2 = st.columns(2)
            with c1:
                if st.button("Apply", use_container_width=True, key="fav_apply"):
                    tokens = [t for t in re.split(r"\s+", (fav_txt or "").strip()) if t]
                    cleaned, seen = [], set()
                    for ch in [t for t in tokens if len(t) == 1]:
                        if ch not in seen:
                            cleaned.append(ch)
                            seen.add(ch)
                    state.set("favourites_list", cleaned)
                    st.toast("Characters updated.", icon="✅")
                    st.rerun()
            with c2:
                if st.button("Clear All", use_container_width=True, key="fav_clear"):
                    state.set("favourites_list", [])
                    st.toast("Cleared.", icon="✅")
                    st.rerun()

        st.markdown("<div class='comp-grid'>", unsafe_allow_html=True)
        cols = st.columns(GRID_COLUMNS)
        for i, ch in enumerate(favs):
            with cols[i % GRID_COLUMNS]:
                st.button(
                    _browse_page_tile_label(ch),
                    key=f"fav_{ch}_{i}",
                    type="secondary",
                    on_click=tile_click,
                    args=(ch,),
                    use_container_width=True,
                )
        st.markdown("</div>", unsafe_allow_html=True)

    # ── Starred phrases ────────────────────────────────────────
    if has_phrases:
        st.markdown(
            f"<div style='font-size:0.8rem; color:#6b5e52; font-weight:700; text-transform:uppercase; "
            f"letter-spacing:0.05em; margin-top:{'18px' if has_chars else '0'}; margin-bottom:8px;'>"
            f"★ Phrases ({len(phrase_favs)})</div>",
            unsafe_allow_html=True,
        )

        # Fetch phrase details for all starred phrases
        db_conn = get_db_connection()
        phrase_map = get_phrase_details(phrase_favs, db_conn)

        for word in phrase_favs:
            entry = phrase_map.get(word)
            if entry:
                render_phrase_info_card(entry, key_prefix="fav_phrase")
            else:
                # Fallback if not in DB — show as a plain button
                if st.button(word, key=f"fav_phrase_plain_{word}", use_container_width=False):
                    state.set("sidebar_phrase_preview", {"word": word})
                    state.remember_character(word)
                    st.rerun()

        if st.button("Clear all phrases", key="fav_phrases_clear", use_container_width=False):
            state.set("favourite_phrases_list", [])
            st.toast("Phrase favourites cleared.", icon="✅")
            st.rerun()


def render_definition_search_results():
    """Render the results of an English definition search (Legacy Sidebar)."""
    results = state.get("definition_search_results")
    if not results:
        st.error("No results state found.")
        return

    st.markdown(f"<div style='font-size:1.2em; font-weight:700; margin-bottom:20px;'>Search Results for \"{pyhtml.escape(state.get('definition_search_query'))}\"</div><div style='font-size:0.85em; color:#666; margin-bottom:20px;'>Found {len(results['characters'])} characters and {len(results['phrases'])} phrases</div>", unsafe_allow_html=True)
    
    if results['characters']:
        st.markdown("<div class='lineage-header'>Characters</div>", unsafe_allow_html=True)
        for char in results['characters'][:30]:
            render_radix_row(char)
    
    if results['phrases']:
        st.markdown("<div class='lineage-header'>Phrases</div>", unsafe_allow_html=True)
        for phrase_data in results['phrases']:
            render_phrase_info_card(phrase_data, key_prefix="definition_phrase")
    
    if not results['characters'] and not results['phrases']:
        st.info(f"No results found for '{state.get('definition_search_query')}'. Try different search terms.")

def _lineage_expanded_key():
    """Session state key for the currently expanded tile in the lineage view."""
    return "lineage_expanded_char"


def _render_lineage_expanded_tile(c: str, section_key: str):
    """Render the expanded inline detail for a lineage tile."""
    from radix_ui import generate_clean_card_html
    uid = f"exp_{section_key}_{ord(c)}"

    # Card detail
    notes = character_notes(c)
    card_html = generate_clean_card_html(
        c,
        usage_count=component_usage_count(c),
        is_static=True,
        notes_override=notes,
        show_actions=False,
        show_parts=False,
    )
    st.markdown(card_html, unsafe_allow_html=True)

    # Phrase length picker + phrases
    current_mode_str = state.get_display_mode()
    try:
        current_int = int(current_mode_str[0])
    except Exception:
        current_int = 2
    if current_int not in [2, 3, 4]:
        current_int = 2

    def _update_len():
        val = st.session_state[f"ph_len_{uid}"]
        state.set("display_mode", f"{val}-Characters")

    st.radio(
        "Phrases",
        options=[2, 3, 4],
        index=[2, 3, 4].index(current_int),
        key=f"ph_len_{uid}",
        horizontal=True,
        label_visibility="collapsed",
        on_change=_update_len,
    )
    if phrase_html := _render_phrase_html(c):
        st.markdown(phrase_html, unsafe_allow_html=True)

    # Go deeper
    if st.button(f"Go deeper into {c} →", key=f"go_deeper_{uid}", use_container_width=True):
        history = state.get_history()
        history.append(state.get_selected_component())
        state.set("history", history)
        state.enter_character_view(c)
        st.rerun()


def render_lineage():
    """Render the lineage view — compact tile grid with single-accordion expansion."""
    sel = state.get_selected_component()
    info = component_map.get(sel, {})
    exp_key = _lineage_expanded_key()

    # Script filter — compact, top right
    lc1, lc2 = st.columns([3, 1])
    with lc2:
        script_choice = st.selectbox(
            "Script",
            options=SCRIPT_FILTERS,
            index=SCRIPT_FILTERS.index(state.get_script_filter()),
            key="lineage_script_filter",
            label_visibility="collapsed",
        )
        state.set("script_filter", script_choice)

    # ── PARTS section ──────────────────────────────────────────────
    decomp = info.get("meta", {}).get("decomposition", "")
    parents = [p for p in decomp
               if p in component_map and p not in IDC_CHARS
               and p not in ["?", "—"] and p != sel]
    parents = apply_script_filter(parents, state.get_script_filter())

    if parents:
        st.markdown("<div class='lineage-header'>🧩 Parts of this character</div>", unsafe_allow_html=True)
        _render_tile_section(parents, section_key="parts", exp_key=exp_key)

    # ── SUPERSET section ───────────────────────────────────────────
    rel = info.get("related_characters", [])
    children = [c for c in rel
                if isinstance(c, str) and len(c) == 1
                and c in component_map and c != sel]
    visible_children = apply_script_filter(
        sorted(children, key=sort_key_usage_primary),
        state.get_script_filter()
    )
    unique_children = list(dict.fromkeys(visible_children))

    if unique_children:
        BATCH_SIZE = 25
        total_derivs = len(unique_children)
        total_pages = max(1, math.ceil(total_derivs / BATCH_SIZE))
        current_page = min(state.get("derivative_page", 0), total_pages - 1)
        start_idx = current_page * BATCH_SIZE
        end_idx = min(start_idx + BATCH_SIZE, total_derivs)
        current_batch = unique_children[start_idx:end_idx]

        st.markdown(
            f"<div class='lineage-header'>🌲 Characters that contain this ({total_derivs})</div>",
            unsafe_allow_html=True,
        )

        if total_pages > 1:
            nav_c1, nav_c2, nav_c3 = st.columns([1, 2, 1])
            with nav_c1:
                if st.button("← Prev", key="deriv_prev", use_container_width=True, disabled=current_page == 0):
                    state.set("derivative_page", current_page - 1)
                    state.set(exp_key, None)
                    st.rerun()
            with nav_c2:
                st.markdown(
                    f"<div style='text-align:center; padding:8px; font-weight:600; "
                    f"color:#6b5e52; font-size:0.85rem;'>Page {current_page + 1} of {total_pages}</div>",
                    unsafe_allow_html=True,
                )
            with nav_c3:
                if st.button("Next →", key="deriv_next", use_container_width=True, disabled=end_idx >= total_derivs):
                    state.set("derivative_page", current_page + 1)
                    state.set(exp_key, None)
                    st.rerun()

        _render_tile_section(current_batch, section_key="superset", exp_key=exp_key)


def _render_tile_section(chars: list, section_key: str, exp_key: str):
    """Render a grid of selectable tiles; the expanded one shows full detail inline."""
    expanded = state.get(exp_key)

    # Tile grid — GRID_COLUMNS wide
    st.markdown("<div class='comp-grid'>", unsafe_allow_html=True)
    cols = st.columns(GRID_COLUMNS)
    for i, c in enumerate(chars):
        with cols[i % GRID_COLUMNS]:
            is_exp = expanded == f"{section_key}:{c}"
            st.button(
                _browse_page_tile_label(c),
                key=f"tile_{section_key}_{ord(c)}_{i}",
                type="primary" if is_exp else "secondary",
                use_container_width=True,
                on_click=_tile_section_click,
                args=(c, section_key, exp_key),
            )
    st.markdown("</div>", unsafe_allow_html=True)

    # Expanded detail — shown once, below the full grid
    if expanded and expanded.startswith(f"{section_key}:"):
        exp_char = expanded.split(":", 1)[1]
        if exp_char in [c for c in chars]:
            st.markdown(
                "<div style='background:#fff; border:1px solid #e8e2d8; border-radius:10px; "
                "padding:16px; margin-top:10px;'>",
                unsafe_allow_html=True,
            )
            _render_lineage_expanded_tile(exp_char, section_key)
            st.markdown("</div>", unsafe_allow_html=True)


def _tile_section_click(c: str, section_key: str, exp_key: str):
    """Toggle expansion of a tile; collapse if already expanded."""
    current = state.get(exp_key)
    new_val = f"{section_key}:{c}"
    state.set(exp_key, None if current == new_val else new_val)
    state.remember_character(c)
def render_ai_link():
    """Render the AI Link / Stroke View."""
    char = state.get("stroke_view_char")
    
    st.markdown("### Stroke Order Animation")
    if st.button("Replay", key=f"stroke_view_replay_{char}", icon=":material/replay:"):
        st.rerun()

    s_char = cc_t2s.convert(char) if cc_t2s else char
    t_char = cc_s2t.convert(char) if cc_s2t else char
    chars_to_show = list(dict.fromkeys([c for c in [s_char, t_char] if c]))
    anim_cols = st.columns(len(chars_to_show) if chars_to_show else 1)
    for idx, display_char in enumerate(chars_to_show):
        with anim_cols[idx]:
            label = ""
            if s_char != t_char:
                label = "Simplified" if display_char == s_char else "Traditional"
            pinyin = component_map.get(display_char, {}).get("meta", {}).get("pinyin", "")
            pinyin_text = ", ".join(pinyin) if isinstance(pinyin, list) else str(pinyin or "")
            if label:
                st.caption(label)
            st.markdown(f"<div style='font-size:1.6rem; font-weight:700; color:#c0392b; font-family:Lora,Georgia,serif; font-style:italic; text-align:center;'>{pyhtml.escape(pinyin_text)}</div>", unsafe_allow_html=True)
            anim_html, anim_height = get_stroke_animation_html(display_char, size=260, element_key=f"stroke_view_{idx}", show_status=True)
            st_html(anim_html, height=anim_height)
    
    # Insights
    insights_result = render_learning_insights_html(char)
    if isinstance(insights_result, tuple):
        if len(insights_result) == 3:
            insights_html, insights_height, prompt_text = insights_result
        elif len(insights_result) == 2:
            insights_html, insights_height = insights_result
            prompt_text = None
        else:
            insights_html, insights_height, prompt_text = None, 0, None
            
        if insights_html:
            st_html(insights_html, height=insights_height)
        if prompt_text:
            st.markdown("---")
            st.markdown("**🤖 Verify Logic & Patterns with AI**")
            render_copy_to_clipboard(prompt_text, f"verify_{char}")
    
    # Phrases
    if state.get_display_mode() != "Single Character":
        if phrase_html := _render_phrase_html(char):
            st.markdown(phrase_html, unsafe_allow_html=True)

    st.markdown("---")
    st.markdown("### ChatGPT Prompt")
    
    # Prompt Config
    config.normalize_prompt_state()
    cfg = state.get("prompt_config")
    tasks = cfg.get("tasks", []) or []
    all_task_ids = [t.get("id") for t in tasks if t.get("id")]
    
    cur_sel = [tid for tid in (state.get("prompt_selected_task_ids") or []) if tid in all_task_ids]
    if not cur_sel:
        cur_sel = list(state.get("prompt_ui").get("default_selected_task_ids", all_task_ids)) or list(all_task_ids)
    state.set("prompt_selected_task_ids", cur_sel)

    with st.expander("Prompt tasks (choose what to include)", expanded=False):
        if st.button("Select all tasks", key="select_all_prompt_tasks"):
            state.set("prompt_selected_task_ids", list(all_task_ids))
            for tid in all_task_ids:
                state.state[f"prompt_task_cb_{tid}"] = True
            st.rerun()
        sel = []
        for t in tasks:
            tid = t.get("id", "")
            if tid and st.checkbox(t.get("title", tid), key=f"prompt_task_cb_{tid}"):
                sel.append(tid)
        state.set("prompt_selected_task_ids", sel)

    prompt_text = render_combined_prompt(
        char=char,
        prompt_config=state.get("prompt_config"),
        selected_task_ids=state.get("prompt_selected_task_ids"),
        definition_en=get_char_definition_en(char)
    )
    st.text_area("Copy this prompt into ChatGPT", value=prompt_text, height=320, label_visibility="collapsed")
    render_copy_to_clipboard(prompt_text, str(hash(char)))


# ==================== MAIN ====================

def main():
    if not component_map:
        st.error("Component dataset not loaded.")
        st.stop()

    # Initialize
    state.initialize()
    config.load_server_data()
    config.initialize_prompt_config()
    
    # AUTO-LOAD user data file if present (NEW!)
    auto_load_user_data()
    auto_load_sample_backup()
    auto_load_sample_memory()

    # Restore from URL
    persistence.try_restore()

    # Layout
    render_sidebar()
    persistence.add_heartbeat()
    render_memory_strip()

    # Routing
    if state.get("dataset_editor_mode", False):
        render_dataset_editor()
    elif state.get("backup_workspace_mode", False):
        render_backup_workspace()
    elif state.is_stroke_view_active():
        render_ai_link()
    elif state.is_definition_search_active():
        render_definition_search_results()
    elif state.is_showing_inputs():
        render_grid()
    else:
        render_lineage()
    
    # Auto-save
    persistence.auto_save()

if __name__ == "__main__":
    main()
