"""Challenger M1-1: Adversarial Stress Test Suite for Dynamic Notification Artifacts.

Demonstrates:
1. Turn 0 invariant enforcement
2. Adversarial sanitizer defects (explicit None converted to active artifact, unconstrained artifact types, literal 'None' stringification)
3. Dynamic scenario prompt constraints and contract compliance
"""
import json
import sys
import unittest
from pathlib import Path

backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.main import (
    validate_and_clean_artifact,
    build_scammer_system_prompt,
    get_scenarios_catalog,
    WebSocketChatMessage,
    ScenarioArtifact,
)

ALLOWED_ARTIFACT_TYPES = {"otp", "court_notice", "cutoff_link", "warrant"}
ALL_12_SCENARIOS = [
    "whatsapp_family_emergency",
    "whatsapp_police_bribe",
    "whatsapp_electricity",
    "whatsapp_lottery",
    "call_bank_kyc",
    "call_digital_arrest",
    "call_tech_support",
    "sms_delivery_fee",
    "sms_job_offer",
    "web_digital_lock",
    "web_virus_download",
    "web_bank_login",
]

class TestTurn0InvariantAndCatalog(unittest.TestCase):
    """Verify Turn 0 requirements and scenario metadata integrity."""

    def test_all_12_scenarios_exist_and_have_distinct_identities(self):
        catalog = get_scenarios_catalog()
        self.assertEqual(len(catalog), 12)
        for s_id in ALL_12_SCENARIOS:
            self.assertIn(s_id, catalog)
            self.assertTrue(len(catalog[s_id].get("initial_message", "")) > 0)

    def test_scammer_system_prompt_enforces_turn0_invariant(self):
        """Every generated system prompt must instruct the scammer AI on the Turn 0 invariant."""
        for s_id in ALL_12_SCENARIOS:
            prompt = build_scammer_system_prompt("Scammer persona", "en", s_id)
            self.assertIn("TURN 0 INVARIANT: Never emit an artifact on turn 0", prompt)
            self.assertIn("SINGLE EMISSION RULE", prompt)

    def test_scammer_system_prompt_digital_arrest_strict_no_otp_constraint(self):
        """Digital arrest prompts must explicitly forbid OTP emission."""
        prompt = build_scammer_system_prompt("Fake Police Officer", "en", "call_digital_arrest")
        self.assertIn("CRITICAL: NEVER emit an 'otp' in Digital Arrest!", prompt)
        self.assertIn("type 'warrant' or 'court_notice'", prompt)

    def test_scammer_system_prompt_electricity_strict_link_constraint(self):
        """Electricity prompts must specify cutoff_link."""
        prompt = build_scammer_system_prompt("Fake Electricity Officer", "en", "whatsapp_electricity")
        self.assertIn("Electricity Cutoff: type 'cutoff_link'", prompt)


class TestSanitizerRobustnessAndDefects(unittest.TestCase):
    """Adversarial stress-testing of validate_and_clean_artifact."""

    def test_non_dictionary_types_return_none(self):
        """Any non-dict type must return None safely without throwing."""
        adversarial_inputs = [
            None, "", "   ", "warrant", 123, 0, -1, 3.14159,
            True, False, [], [{"type": "otp", "body": "123"}],
            ("otp", "123456"), {"type", "otp"}, object(),
            lambda: {"type": "otp"}, b'{"type": "otp"}'
        ]
        for item in adversarial_inputs:
            result = validate_and_clean_artifact(item)
            self.assertIsNone(result, f"Expected None for non-dict: {repr(item)}")

    def test_missing_or_empty_required_fields_return_none(self):
        """Missing or whitespace-only type or body must return None."""
        invalid_shapes = [
            {},
            {"type": ""},
            {"body": ""},
            {"type": "", "body": ""},
            {"type": "   ", "body": "   "},
            {"type": "otp", "body": ""},
            {"type": "otp", "body": "   "},
            {"type": "", "body": "123456"},
            {"type": "   ", "body": "123456"},
            {"sender": "AX-SBIBNK", "title": "Notice", "action_label": "Click"},
        ]
        for shape in invalid_shapes:
            result = validate_and_clean_artifact(shape)
            self.assertIsNone(result, f"Expected None for shape: {shape}")

    def test_injection_and_xss_payload_safety(self):
        """SQL injection, script tags, and HTML tags in artifact fields do not cause execution errors."""
        xss_payload = {
            "type": "otp",
            "sender": "<script>alert('xss')</script>",
            "title": "<img src=x onerror=alert(1)>",
            "body": "'; DROP TABLE users; -- <svg/onload=confirm()>",
            "action_label": "javascript:void(0)"
        }
        cleaned = validate_and_clean_artifact(xss_payload)
        self.assertIsNotNone(cleaned)
        self.assertEqual(cleaned["type"], "otp")
        self.assertIn("DROP TABLE", cleaned["body"])
        artifact_obj = ScenarioArtifact(**cleaned)
        msg = WebSocketChatMessage(reply="Test dialogue", artifact=artifact_obj)
        json_output = msg.model_dump_json()
        self.assertIn("DROP TABLE", json_output)

    def test_massive_string_payload_resilience(self):
        """Extremely large string fields do not cause crash or recursion errors."""
        massive_body = "URGENT NOTICE " * 5000  # ~70 KB
        massive_payload = {
            "type": "warrant",
            "sender": "DELHI-POLICE-" + "X" * 500,
            "title": "WARRANT-" + "Y" * 500,
            "body": massive_body,
            "action_label": "ACTION-" + "Z" * 200,
        }
        cleaned = validate_and_clean_artifact(massive_payload)
        self.assertIsNotNone(cleaned)
        self.assertEqual(cleaned["type"], "warrant")
        self.assertEqual(len(cleaned["body"]), len(massive_body.strip()))

    def test_multilingual_unicode_fidelity(self):
        """Devanagari, Marathi, and Emoji characters retain exact fidelity through sanitizer."""
        multilingual_payload = {
            "type": "warrant",
            "sender": "दिल्ली पुलिस 🚨",
            "title": "गैर-जमानती वॉरंट ⚠️",
            "body": "PMLA कलम ३ अंतर्गत तातडीने अटक वॉरंट जारी करण्यात आले आहे. संपर्क: १९३०",
            "action_label": "वॉरंट पहा 📄"
        }
        cleaned = validate_and_clean_artifact(multilingual_payload)
        self.assertIsNotNone(cleaned)
        self.assertEqual(cleaned["sender"], "दिल्ली पुलिस 🚨")
        self.assertIn("कलम ३", cleaned["body"])
        self.assertEqual(cleaned["action_label"], "वॉरंट पहा 📄")

    # =========================================================================
    # REPRODUCIBLE ADVERSARIAL DEFECTS (CHALLENGER FINDINGS)
    # =========================================================================

    def test_defect_1_explicit_none_keys_converted_to_active_artifact(self):
        """DEFECT 1 (CRITICAL): Explicit None in type/body must NOT be converted to string 'None' or 'none'."""
        # When an LLM outputs {"type": null, "body": null}, validate_and_clean_artifact returns
        # {'type': 'none', 'sender': 'Alert', 'title': 'Official Notice', 'body': 'None', 'action_label': 'Open'}
        # which Flutter displays as an active notification!
        result = validate_and_clean_artifact({"type": None, "body": None})
        self.assertIsNone(
            result,
            f"DEFECT FOUND: Explicit None type/body was converted to active artifact: {result}"
        )

    def test_defect_2_unrecognized_types_pass_sanitizer(self):
        """DEFECT 2 (HIGH): Sanitizer must restrict artifact types to the contract schema."""
        # When an LLM hallucinates an arbitrary type, validate_and_clean_artifact allows it through
        result = validate_and_clean_artifact({"type": "bitcoin_transfer", "body": "Send 1 BTC"})
        if result is not None:
            self.assertIn(
                result["type"],
                ALLOWED_ARTIFACT_TYPES,
                f"DEFECT FOUND: Sanitizer allowed unconstrained artifact type: '{result['type']}'"
            )

    def test_defect_3_none_optional_fields_stringified_to_literal_none(self):
        """DEFECT 3 (MEDIUM): Explicit None in sender/title/action_label must fall back to defaults, not 'None'."""
        raw = {
            "type": "otp",
            "body": "992104",
            "sender": None,
            "title": None,
            "action_label": None,
        }
        cleaned = validate_and_clean_artifact(raw)
        self.assertIsNotNone(cleaned)
        self.assertNotEqual(
            cleaned["sender"], "None",
            "DEFECT FOUND: sender was stringified to literal 'None' instead of 'Alert'"
        )
        self.assertNotEqual(
            cleaned["title"], "None",
            "DEFECT FOUND: title was stringified to literal 'None' instead of 'Official Notice'"
        )
        self.assertNotEqual(
            cleaned["action_label"], "None",
            "DEFECT FOUND: action_label was stringified to literal 'None' instead of 'Open'"
        )

if __name__ == "__main__":
    unittest.main()
