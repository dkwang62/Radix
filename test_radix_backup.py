import copy
import json
import unittest

from radix_backup import (
    BackupValidationError,
    detect_radix_json_type,
    export_backup_package,
    export_validation_summary,
    load_backup,
    load_backup_bytes,
    load_radix_json_bytes,
    profile_to_backup,
    validate_backup,
)
from server import build_download_payload


FIXTURE = "radix_unified_backup.json"


class RadixBackupRoundTripTests(unittest.TestCase):
    def test_permanent_sample_imports_and_summarizes(self):
        backup = load_backup(FIXTURE)

        self.assertEqual(backup["schema_version"], 4)
        self.assertEqual(len(backup["phrases"]), 123)
        self.assertEqual(len(backup["collections"]), 24)

        summary = export_validation_summary(backup)
        self.assertEqual(summary["schema_version"], 4)
        self.assertEqual(summary["phrases_count"], 123)
        self.assertEqual(summary["collections_count"], 24)
        self.assertEqual(summary["translation_reports_count"], 12)
        self.assertGreaterEqual(summary["favourites_count"], 1)
        self.assertGreaterEqual(summary["profile_fields_count"], 1)

    def test_export_preserves_unknown_fields_and_refreshes_export_date(self):
        backup = load_backup(FIXTURE)
        original_exported_at = backup["exported_at"]
        backup["radixweb_unknown_fixture"] = {"preserve": True}

        exported = export_backup_package(backup)

        self.assertIn("radixweb_unknown_fixture", exported)
        self.assertEqual(exported["radixweb_unknown_fixture"], {"preserve": True})
        self.assertNotEqual(exported["exported_at"], original_exported_at)
        self.assertEqual(validate_backup(exported)["schema_version"], 4)

    def test_load_backup_bytes_matches_file_loader(self):
        with open(FIXTURE, "rb") as f:
            from_bytes = load_backup_bytes(f.read())
        from_file = load_backup(FIXTURE)

        self.assertEqual(from_bytes["backup_id"], from_file["backup_id"])
        self.assertEqual(len(from_bytes["phrases"]), len(from_file["phrases"]))

    def test_package_loader_detects_unified_backup(self):
        with open(FIXTURE, "rb") as f:
            package_type, backup = load_radix_json_bytes(f.read())

        self.assertEqual(package_type, "unified_backup")
        self.assertEqual(backup["schema_version"], 4)

    def test_profile_json_wraps_as_minimal_backup(self):
        profile = {
            "schema_version": 1,
            "favourites_list": ["示"],
            "favourite_phrases_list": ["美日"],
            "remembered_list": ["股价"],
            "prompt_config": {"version": 2},
            "extra_profile_field": "preserved",
        }

        self.assertEqual(detect_radix_json_type(profile), "profile")
        backup = profile_to_backup(profile)
        summary = export_validation_summary(backup)

        self.assertEqual(backup["schema_version"], 4)
        self.assertEqual(backup["profile"]["extra_profile_field"], "preserved")
        self.assertEqual(backup["phrases"], [])
        self.assertEqual(backup["collections"], [])
        self.assertEqual(summary["favourites_count"], 1)
        self.assertEqual(summary["phrase_favourites_count"], 1)
        self.assertEqual(summary["remembered_count"], 1)
        self.assertEqual(summary["preserved_profile_fields"], ["extra_profile_field"])

    def test_package_loader_accepts_profile_bytes(self):
        profile = {"schema_version": 1, "favourites_list": ["示"]}

        package_type, backup = load_radix_json_bytes(json.dumps(profile).encode("utf-8"))

        self.assertEqual(package_type, "profile")
        self.assertEqual(backup["profile"]["favourites_list"], ["示"])

    def test_validate_backup_normalizes_optional_containers(self):
        minimal = {"schema_version": 4, "phrases": None, "collections": None, "profile": None}

        normalized = validate_backup(minimal)

        self.assertEqual(normalized["phrases"], [])
        self.assertEqual(normalized["collections"], [])
        self.assertEqual(normalized["profile"], {})
        self.assertEqual(normalized["dictionary_patch_overlay"]["patches"], [])

    def test_validate_backup_rejects_unsupported_schema(self):
        with self.assertRaises(BackupValidationError):
            validate_backup({"schema_version": 999})

    def test_summary_counts_character_notes_and_hidden_phrases(self):
        backup = copy.deepcopy(load_backup(FIXTURE))
        backup["dictionary_patch_overlay"]["patches"].append(
            {"character": "测", "meta": {"notes": ["note"]}, "updated_at": 1}
        )
        backup["collections"][0]["hiddenPhraseWords"] = ["美日", "股价", ""]

        summary = export_validation_summary(backup)

        self.assertGreaterEqual(summary["character_notes_count"], 1)
        self.assertEqual(summary["hidden_phrase_words_count"], 2)

    def test_backup_download_payload_is_not_component_map_validated(self):
        backup = export_backup_package(load_backup(FIXTURE))

        payload = build_download_payload(
            backup,
            "radix_unified_backup.json",
            validate_component_map=False,
        )
        parsed = json.loads(payload["content"])

        self.assertEqual(payload["mime"], "application/json")
        self.assertEqual(parsed["schema_version"], 4)
        self.assertIn("collections", parsed)


if __name__ == "__main__":
    unittest.main()
