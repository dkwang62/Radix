#!/usr/bin/env python3
"""
Import HanziWriter-compatible Japanese stroke data into Radix's bundled stroke DB.

Default source:
  npm package: hanzi-writer-data-jp@0.0.1
  file listing: jsDelivr package API
  file payloads: jsDelivr npm CDN

The importer writes rows in Radix's existing schema:
  strokes(character TEXT PRIMARY KEY, data TEXT NOT NULL)
"""

from __future__ import annotations

import argparse
import datetime as dt
import io
import json
import shutil
import sqlite3
import ssl
import sys
import tarfile
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_PACKAGE = "hanzi-writer-data-jp"
DEFAULT_VERSION = "0.0.1"
DEFAULT_DB = Path("Resources/character_strokes.db")
DEFAULT_ARCHIVE_DB = Path("Resources/japanese_character_strokes.db")


def fetch_json(url: str, timeout: int, insecure: bool = False) -> Any:
    request = urllib.request.Request(url, headers={"User-Agent": "Radix stroke importer"})
    context = ssl._create_unverified_context() if insecure else None
    with urllib.request.urlopen(request, timeout=timeout, context=context) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_bytes(url: str, timeout: int, insecure: bool = False) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "Radix stroke importer"})
    context = ssl._create_unverified_context() if insecure else None
    with urllib.request.urlopen(request, timeout=timeout, context=context) as response:
        return response.read()


def encode_package_file_path(path: str) -> str:
    return "/".join(urllib.parse.quote(part, safe="") for part in path.split("/"))


def package_file_listing(package: str, version: str, timeout: int, insecure: bool) -> list[str]:
    url = f"https://data.jsdelivr.com/v1/package/npm/{package}@{version}/flat"
    payload = fetch_json(url, timeout, insecure)
    files = payload.get("files", [])
    paths: list[str] = []
    for item in files:
        name = item.get("name", "") if isinstance(item, dict) else str(item)
        name = name.lstrip("/")
        if name.endswith(".json") and not name.endswith("package.json"):
            paths.append(name)
    return sorted(set(paths))


def package_tarball_url(package: str, version: str, timeout: int, insecure: bool) -> str:
    registry_url = f"https://registry.npmjs.org/{urllib.parse.quote(package, safe='')}/{version}"
    payload = fetch_json(registry_url, timeout, insecure)
    try:
        return payload["dist"]["tarball"]
    except KeyError as error:
        raise RuntimeError(f"npm registry response did not include a tarball URL for {package}@{version}") from error


def package_tarball_payloads(
    package: str,
    version: str,
    timeout: int,
    insecure: bool,
    tarball_file: str | None = None,
) -> list[tuple[str, dict[str, Any]]]:
    if tarball_file:
        tarball_path = Path(tarball_file)
        print(f"Reading npm tarball: {tarball_path}", flush=True)
        tarball_data = tarball_path.read_bytes()
    else:
        tarball_url = package_tarball_url(package, version, timeout, insecure)
        print(f"Downloading npm tarball: {tarball_url}", flush=True)
        tarball_data = fetch_bytes(tarball_url, timeout, insecure)

    payloads: dict[str, dict[str, Any]] = {}
    with tarfile.open(fileobj=io.BytesIO(tarball_data), mode="r:gz") as archive:
        for member in archive.getmembers():
            if not member.isfile() or not member.name.endswith(".json"):
                continue
            if member.name.endswith("/package.json"):
                continue
            character = character_from_path(member.name)
            if character is None:
                continue
            file_obj = archive.extractfile(member)
            if file_obj is None:
                continue
            payload = json.loads(file_obj.read().decode("utf-8"))
            if isinstance(payload, dict):
                payloads[character] = payload

    return sorted(payloads.items(), key=lambda item: item[0])


def character_from_path(path: str) -> str | None:
    filename = path.rsplit("/", 1)[-1]
    if not filename.endswith(".json"):
        return None
    character = filename[:-5]
    if not character:
        return None
    return character


def normalize_stroke_payload(character: str, payload: dict[str, Any]) -> str:
    strokes = payload.get("strokes")
    medians = payload.get("medians")
    if not isinstance(strokes, list) or not isinstance(medians, list):
        raise ValueError("missing strokes or medians arrays")
    if len(strokes) != len(medians):
        raise ValueError("strokes and medians lengths differ")

    normalized = {
        "character": character,
        "strokes": strokes,
        "medians": medians,
    }
    if isinstance(payload.get("radStrokes"), list):
        normalized["radStrokes"] = payload["radStrokes"]
    return json.dumps(normalized, ensure_ascii=False, separators=(",", ":"))


def ensure_db_shape(conn: sqlite3.Connection) -> None:
    row = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='strokes'"
    ).fetchone()
    if row is None:
        raise RuntimeError("target database does not contain a strokes table")

    columns = {row[1] for row in conn.execute("PRAGMA table_info(strokes)")}
    required = {"character", "data"}
    missing = required.difference(columns)
    if missing:
        raise RuntimeError(f"strokes table is missing columns: {', '.join(sorted(missing))}")


def existing_characters(conn: sqlite3.Connection) -> set[str]:
    return {row[0] for row in conn.execute("SELECT character FROM strokes")}


def source_character_payloads(args: argparse.Namespace) -> list[tuple[str, dict[str, Any]]]:
    print(f"Reading package tarball for {args.package}@{args.version}...", flush=True)
    character_payloads = package_tarball_payloads(
        args.package,
        args.version,
        args.timeout,
        args.insecure,
        args.tarball_file,
    )
    if args.limit:
        character_payloads = character_payloads[: args.limit]
    if args.characters:
        requested = requested_characters(args.characters)
        character_payloads = [(char, payload) for char, payload in character_payloads if char in requested]
        found = {char for char, _ in character_payloads}
        missing = sorted(requested.difference(found))
        if missing:
            print(f"Requested characters not found in source package: {''.join(missing)}", flush=True)
    if not character_payloads:
        raise RuntimeError("no character JSON files found in package listing")

    print(f"Found {len(character_payloads)} Japanese stroke files.", flush=True)
    return character_payloads


def create_archive_db(args: argparse.Namespace, character_payloads: list[tuple[str, dict[str, Any]]]) -> int:
    archive_path = Path(args.archive_db)
    if args.dry_run:
        preview = ", ".join(char for char, _ in character_payloads[:12])
        print(f"Dry run only. First characters: {preview}")
        return 0

    if archive_path.exists() and archive_path.stat().st_size > 0:
        timestamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        backup_path = archive_path.with_name(f"{archive_path.name}.backup-{timestamp}")
        shutil.copy2(archive_path, backup_path)
        print(f"Archive backup written: {backup_path}")

    archive_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(archive_path)
    inserted = 0
    skipped_errors = 0
    try:
        conn.execute("DROP TABLE IF EXISTS strokes")
        conn.execute("CREATE TABLE strokes(character TEXT PRIMARY KEY, data TEXT NOT NULL)")

        for index, (character, payload) in enumerate(character_payloads, start=1):
            try:
                data = normalize_stroke_payload(character, payload)
                conn.execute(
                    "INSERT INTO strokes(character, data) VALUES (?, ?)",
                    (character, data),
                )
                inserted += 1
            except Exception as error:
                skipped_errors += 1
                print(f"Skipping {character!r}: {error}")

            if index % args.commit_every == 0:
                conn.commit()
                print(f"Progress: {index}/{len(character_payloads)} archive files processed...", flush=True)

        conn.execute("CREATE INDEX IF NOT EXISTS idx_strokes_character ON strokes(character)")
        conn.commit()
        conn.execute("ANALYZE")
        conn.commit()
    finally:
        conn.close()

    print(f"Archive complete: {inserted} stored, {skipped_errors} errors. Archive: {archive_path}")
    return 0


def import_strokes(args: argparse.Namespace) -> int:
    character_payloads = source_character_payloads(args)

    if args.archive_db:
        return create_archive_db(args, character_payloads)

    db_path = Path(args.db)
    if not db_path.exists():
        raise FileNotFoundError(f"database not found: {db_path}")
    if db_path.stat().st_size == 0:
        raise RuntimeError(f"database is empty: {db_path}")

    if args.dry_run:
        preview = ", ".join(char for char, _ in character_payloads[:12])
        print(f"Dry run only. First characters: {preview}")
        return 0

    timestamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = db_path.with_name(f"{db_path.name}.backup-{timestamp}")
    shutil.copy2(db_path, backup_path)
    print(f"Backup written: {backup_path}")

    conn = sqlite3.connect(db_path)
    try:
        ensure_db_shape(conn)
        known = existing_characters(conn)
        inserted = 0
        updated = 0
        skipped_existing = 0
        skipped_errors = 0

        for index, (character, payload) in enumerate(character_payloads, start=1):
            try:
                data = normalize_stroke_payload(character, payload)
                if character in known:
                    if args.overwrite:
                        conn.execute(
                            "UPDATE strokes SET data = ? WHERE character = ?",
                            (data, character),
                        )
                        updated += 1
                    else:
                        skipped_existing += 1
                else:
                    conn.execute(
                        "INSERT INTO strokes(character, data) VALUES (?, ?)",
                        (character, data),
                    )
                    inserted += 1
                    known.add(character)
            except Exception as error:  # keep importing other characters
                skipped_errors += 1
                print(f"Skipping {character!r}: {error}")

            if index % args.commit_every == 0:
                conn.commit()
                print(f"Progress: {index}/{len(character_payloads)} files processed...", flush=True)

            if args.delay > 0:
                time.sleep(args.delay)

        conn.commit()
        conn.execute("ANALYZE")
        conn.commit()
    finally:
        conn.close()

    print(
        "Import complete: "
        f"{inserted} inserted, {updated} updated, "
        f"{skipped_existing} existing skipped, {skipped_errors} errors. "
        f"Backup: {backup_path}"
    )
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", default=str(DEFAULT_DB), help="Path to character_strokes.db")
    parser.add_argument(
        "--archive-db",
        help=f"Create a separate bundled archive DB instead of writing to --db. Default suggested path: {DEFAULT_ARCHIVE_DB}",
    )
    parser.add_argument("--package", default=DEFAULT_PACKAGE, help="npm package name")
    parser.add_argument(
        "--version",
        default=DEFAULT_VERSION,
        help="npm package version. 0.0.1 is the full Japanese dataset; latest/0.0.2 is incomplete.",
    )
    parser.add_argument("--timeout", type=int, default=20, help="Network timeout in seconds")
    parser.add_argument("--commit-every", type=int, default=50, help="Rows per commit")
    parser.add_argument("--delay", type=float, default=0.03, help="Delay between CDN requests")
    parser.add_argument("--limit", type=int, default=0, help="Import only the first N files")
    parser.add_argument(
        "--characters",
        help="Only import these characters. Accepts a plain string like 働峠込躾 or comma-separated values.",
    )
    parser.add_argument("--dry-run", action="store_true", help="List source files without writing")
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace existing rows. Default is insert-only and skips existing characters.",
    )
    parser.add_argument("--tarball-file", help="Use a local npm .tgz file instead of downloading with Python")
    parser.add_argument(
        "--insecure",
        action="store_true",
        help="Disable TLS certificate verification when the local Python trust store is broken",
    )
    return parser.parse_args()


def requested_characters(raw: str) -> set[str]:
    normalized = raw.replace(",", "").replace(" ", "").replace("\n", "").replace("\t", "")
    return {character for character in normalized if character.strip()}


if __name__ == "__main__":
    try:
        raise SystemExit(import_strokes(parse_args()))
    except KeyboardInterrupt:
        print("Interrupted.", file=sys.stderr)
        raise SystemExit(130)
    except Exception as error:
        print(f"Import failed: {error}", file=sys.stderr)
        raise SystemExit(1)
