"""Radix unified backup helpers for the Streamlit companion app."""

from __future__ import annotations

import copy
import json
import time
from pathlib import Path
from typing import Any, Iterable


SUPPORTED_SCHEMA_VERSIONS = {4}
PROFILE_SCHEMA_VERSION = 1


class BackupValidationError(ValueError):
    """Raised when a Radix backup cannot be used as a working copy."""


def load_backup(path: str | Path) -> dict[str, Any]:
    """Load and validate a Radix unified backup from disk."""
    source = Path(path)
    with source.open("r", encoding="utf-8") as f:
        data = json.load(f)
    return validate_backup(data)


def load_backup_bytes(file_bytes: bytes) -> dict[str, Any]:
    """Load and validate a Radix unified backup from uploaded bytes."""
    try:
        data = json.loads(file_bytes.decode("utf-8"))
    except UnicodeDecodeError as exc:
        raise BackupValidationError("Backup must be UTF-8 JSON.") from exc
    return validate_backup(data)


def load_radix_json_bytes(file_bytes: bytes) -> tuple[str, dict[str, Any]]:
    """Load a Radix unified backup or profile-style JSON upload."""
    try:
        data = json.loads(file_bytes.decode("utf-8"))
    except UnicodeDecodeError as exc:
        raise BackupValidationError("Radix JSON must be UTF-8.") from exc

    package_type = detect_radix_json_type(data)
    if package_type == "unified_backup":
        return package_type, validate_backup(data)
    if package_type == "profile":
        return package_type, profile_to_backup(data)
    raise BackupValidationError("Unsupported Radix JSON package.")


def detect_radix_json_type(data: Any) -> str:
    """Return the supported Radix JSON package kind."""
    if not isinstance(data, dict):
        raise BackupValidationError("Radix JSON must be an object.")
    if data.get("schema_version") in SUPPORTED_SCHEMA_VERSIONS and (
        "profile" in data or "phrases" in data or "collections" in data or "dictionary_patch_overlay" in data
    ):
        return "unified_backup"
    if data.get("schema_version") == PROFILE_SCHEMA_VERSION and (
        "favourites_list" in data or "favourite_phrases_list" in data or "remembered_list" in data or "prompt_config" in data
    ):
        return "profile"
    schema_version = data.get("schema_version")
    raise BackupValidationError(f"Unsupported Radix JSON schema_version {schema_version!r}.")


def profile_to_backup(profile: dict[str, Any]) -> dict[str, Any]:
    """Wrap a profile-style JSON file in a minimal unified backup working copy."""
    if not isinstance(profile, dict) or profile.get("schema_version") != PROFILE_SCHEMA_VERSION:
        raise BackupValidationError("Unsupported profile JSON.")
    return validate_backup(
        {
            "schema_version": 4,
            "exported_at": time.time() - 978307200,
            "backup_id": "",
            "base_dictionary_fingerprint": "",
            "profile": copy.deepcopy(profile),
            "phrases": [],
            "collections": [],
            "dictionary_patch_overlay": {
                "schema_version": 1,
                "custom_entries": {},
                "patches": [],
                "deletions": [],
            },
        }
    )


def validate_backup(data: Any) -> dict[str, Any]:
    """Return a normalized deep copy of a supported Radix unified backup."""
    if not isinstance(data, dict):
        raise BackupValidationError("Backup JSON must be an object.")

    schema_version = data.get("schema_version")
    if schema_version not in SUPPORTED_SCHEMA_VERSIONS:
        supported = ", ".join(str(v) for v in sorted(SUPPORTED_SCHEMA_VERSIONS))
        raise BackupValidationError(f"Unsupported schema_version {schema_version!r}. Supported: {supported}.")

    normalized = copy.deepcopy(data)
    for key in ("phrases", "collections"):
        if not isinstance(normalized.get(key), list):
            normalized[key] = []

    profile = normalized.get("profile")
    if not isinstance(profile, dict):
        normalized["profile"] = {}

    overlay = normalized.get("dictionary_patch_overlay")
    if not isinstance(overlay, dict):
        normalized["dictionary_patch_overlay"] = {
            "schema_version": 1,
            "custom_entries": {},
            "patches": [],
            "deletions": [],
        }

    return normalized


def backup_summary(backup: dict[str, Any], source_name: str = "") -> dict[str, Any]:
    """Build compact display metadata for the active working backup."""
    profile = backup.get("profile") if isinstance(backup.get("profile"), dict) else {}
    overlay = backup.get("dictionary_patch_overlay")
    overlay = overlay if isinstance(overlay, dict) else {}

    custom_entries = overlay.get("custom_entries")
    patches = overlay.get("patches")
    deletions = overlay.get("deletions")

    return {
        "source_name": source_name,
        "backup_id": backup.get("backup_id", ""),
        "schema_version": backup.get("schema_version"),
        "exported_at": backup.get("exported_at", ""),
        "phrases_count": len(backup.get("phrases") or []),
        "collections_count": len(backup.get("collections") or []),
        "remembered_count": len(profile.get("remembered_list") or []),
        "favourites_count": len(profile.get("favourites_list") or []),
        "phrase_favourites_count": len(profile.get("favourite_phrases_list") or []),
        "custom_entries_count": len(custom_entries) if isinstance(custom_entries, dict) else 0,
        "patches_count": len(patches) if isinstance(patches, list) else 0,
        "deletions_count": len(deletions) if isinstance(deletions, list) else 0,
    }


def phrase_details_map(backup: dict[str, Any], words: Iterable[str] | None = None) -> dict[str, dict[str, Any]]:
    """Return phrase records indexed by word, optionally restricted to words."""
    wanted = set(words or [])
    restrict = bool(wanted)
    out: dict[str, dict[str, Any]] = {}
    for item in backup.get("phrases") or []:
        if not isinstance(item, dict):
            continue
        word = item.get("word")
        if not isinstance(word, str) or not word:
            continue
        if restrict and word not in wanted:
            continue
        out[word] = normalize_phrase(item)
    return out


def all_phrase_details(backup: dict[str, Any]) -> list[dict[str, Any]]:
    """Return normalized phrase records from the backup."""
    return list(phrase_details_map(backup).values())


def normalize_phrase(item: dict[str, Any]) -> dict[str, Any]:
    """Keep Radix phrase fields while ensuring app-required keys are strings."""
    phrase = copy.deepcopy(item)
    for key in ("word", "pinyin", "meanings", "notes", "review_status"):
        value = phrase.get(key, "")
        phrase[key] = value if isinstance(value, str) else str(value or "")
    return phrase


def collection_summaries(backup: dict[str, Any]) -> list[dict[str, Any]]:
    """Return compact collection metadata for browse views."""
    summaries = []
    for item in backup.get("collections") or []:
        if not isinstance(item, dict):
            continue
        chars = item.get("characters") if isinstance(item.get("characters"), list) else []
        report = item.get("translationReport")
        summaries.append(
            {
                "id": item.get("id", ""),
                "name": item.get("name", "Untitled"),
                "sourceType": item.get("sourceType", ""),
                "isFavorite": bool(item.get("isFavorite", False)),
                "characters_count": len(chars),
                "has_translation_report": isinstance(report, str) and bool(report.strip()),
            }
        )
    return summaries


def export_backup_package(backup: dict[str, Any]) -> dict[str, Any]:
    """Return a Radix unified backup payload ready for download."""
    payload = validate_backup(backup)
    payload["exported_at"] = time.time() - 978307200
    return payload


def export_validation_summary(backup: dict[str, Any]) -> dict[str, Any]:
    """Summarize export contents and preserved fields before download."""
    overlay = backup.get("dictionary_patch_overlay") if isinstance(backup.get("dictionary_patch_overlay"), dict) else {}
    patches = overlay.get("patches") if isinstance(overlay.get("patches"), list) else []
    custom_entries = overlay.get("custom_entries") if isinstance(overlay.get("custom_entries"), dict) else {}
    collections = [c for c in backup.get("collections") or [] if isinstance(c, dict)]

    note_chars = set()
    for patch in patches:
        if not isinstance(patch, dict):
            continue
        meta = patch.get("meta") if isinstance(patch.get("meta"), dict) else {}
        if meta.get("notes"):
            note_chars.add(patch.get("character", ""))
    for char, entry in custom_entries.items():
        meta = entry.get("meta") if isinstance(entry, dict) and isinstance(entry.get("meta"), dict) else {}
        if meta.get("notes"):
            note_chars.add(char)
    note_chars.discard("")

    known_top_level = {
        "api_keys",
        "backup_id",
        "base_dictionary_fingerprint",
        "collections",
        "dictionary_overlay",
        "dictionary_patch_overlay",
        "exported_at",
        "phrases",
        "profile",
        "schema_version",
        "selected_ai_collection_id",
    }
    preserved_top_level = sorted(k for k in backup.keys() if k not in known_top_level)
    profile = backup.get("profile") if isinstance(backup.get("profile"), dict) else {}
    known_profile_fields = {
        "schema_version",
        "favourites_list",
        "favourite_phrases_list",
        "remembered_list",
        "prompt_config",
        "prompt_ui",
    }
    preserved_profile_fields = sorted(k for k in profile.keys() if k not in known_profile_fields)

    hidden_count = 0
    report_count = 0
    for collection in collections:
        if isinstance(collection.get("translationReport"), str) and collection.get("translationReport").strip():
            report_count += 1
        hidden = collection.get("hiddenPhraseWords")
        if isinstance(hidden, list):
            hidden_count += len([w for w in hidden if isinstance(w, str) and w.strip()])

    warnings = []
    if backup.get("api_keys"):
        warnings.append("Imported api_keys are preserved; RadixWeb does not edit or add API keys.")
    if preserved_top_level:
        warnings.append("Unknown top-level fields will be preserved unchanged.")
    if preserved_profile_fields:
        warnings.append("Unknown profile fields will be preserved unchanged.")

    return {
        "schema_version": backup.get("schema_version"),
        "phrases_count": len(backup.get("phrases") or []),
        "character_notes_count": len(note_chars),
        "collections_count": len(collections),
        "translation_reports_count": report_count,
        "hidden_phrase_words_count": hidden_count,
        "favourites_count": len(profile.get("favourites_list") or []),
        "phrase_favourites_count": len(profile.get("favourite_phrases_list") or []),
        "remembered_count": len(profile.get("remembered_list") or []),
        "profile_fields_count": len(profile),
        "preserved_top_level_fields": preserved_top_level,
        "preserved_profile_fields": preserved_profile_fields,
        "warnings": warnings,
    }
