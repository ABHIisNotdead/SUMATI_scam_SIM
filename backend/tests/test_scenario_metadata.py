"""Tests for scenario metadata loading, enrichment validation, and catalog consistency."""
import sys
import unittest
from pathlib import Path

backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.main import get_scenarios_catalog, generate_debrief_fallback

EXPECTED_SCENARIO_IDS = [
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
    "web_bank_login"
]

class TestScenarioMetadata(unittest.TestCase):
    def test_catalog_loads_all_twelve_scenarios(self):
        """Catalog must contain all 12 defined scenarios."""
        catalog = get_scenarios_catalog()
        self.assertEqual(len(catalog), 12)
        for expected_id in EXPECTED_SCENARIO_IDS:
            self.assertIn(expected_id, catalog, f"Scenario {expected_id} missing from catalog")

    def test_all_scenarios_have_required_core_fields(self):
        """Every scenario must define core simulation attributes."""
        catalog = get_scenarios_catalog()
        required_keys = ["id", "title", "channel", "difficulty", "scammer_name", "persona", "goal", "initial_message"]
        for s_id, s_data in catalog.items():
            for key in required_keys:
                self.assertIn(key, s_data, f"Scenario {s_id} is missing key {key}")
                self.assertTrue(len(str(s_data[key]).strip()) > 0, f"Scenario {s_id} key {key} is empty")

    def test_all_scenarios_have_enriched_educational_metadata(self):
        """Every scenario must include enriched psychological tricks, tactics, red flags, dos, and donts."""
        catalog = get_scenarios_catalog()
        for s_id, s_data in catalog.items():
            # Psychological tricks
            self.assertIn("psychological_tricks", s_data, f"Scenario {s_id} missing psychological_tricks")
            self.assertIsInstance(s_data["psychological_tricks"], list)
            self.assertGreaterEqual(len(s_data["psychological_tricks"]), 2)

            # Tactics explanation
            self.assertIn("tactics_explanation", s_data, f"Scenario {s_id} missing tactics_explanation")
            self.assertIsInstance(s_data["tactics_explanation"], str)
            self.assertGreater(len(s_data["tactics_explanation"]), 30)

            # Red flags
            self.assertIn("red_flags", s_data, f"Scenario {s_id} missing red_flags")
            self.assertIsInstance(s_data["red_flags"], list)
            self.assertGreaterEqual(len(s_data["red_flags"]), 2)

            # Do's and Don'ts
            self.assertIn("dos", s_data, f"Scenario {s_id} missing dos")
            self.assertIsInstance(s_data["dos"], list)
            self.assertGreaterEqual(len(s_data["dos"]), 2)

            self.assertIn("donts", s_data, f"Scenario {s_id} missing donts")
            self.assertIsInstance(s_data["donts"], list)
            self.assertGreaterEqual(len(s_data["donts"]), 2)

            # Audio script template
            self.assertIn("audio_script_template", s_data, f"Scenario {s_id} missing audio_script_template")
            self.assertIsInstance(s_data["audio_script_template"], str)

    def test_fallback_generator_with_valid_and_unknown_scenarios(self):
        """generate_debrief_fallback produces valid output for known and unknown scenarios."""
        catalog = get_scenarios_catalog()

        # Known scenario
        known_fb = generate_debrief_fallback("call_digital_arrest", "success:survived", "en", catalog.get("call_digital_arrest"))
        self.assertIn("Well done", known_fb["headline"])
        self.assertIn("Indian law", known_fb["tactics_explanation"])
        self.assertGreaterEqual(len(known_fb["dos"]), 2)
        self.assertGreaterEqual(len(known_fb["donts"]), 2)

        # Unknown scenario
        unknown_fb = generate_debrief_fallback("unknown_scam_id", "failure:compromised", "en", None)
        self.assertIn("careful", unknown_fb["headline"].lower())
        self.assertGreaterEqual(len(unknown_fb["dos"]), 2)
        self.assertGreaterEqual(len(unknown_fb["donts"]), 2)

if __name__ == "__main__":
    unittest.main()
