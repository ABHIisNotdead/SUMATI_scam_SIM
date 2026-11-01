"""Empirical Challenger stress test suite for POST /api/debrief endpoint and Edge-TTS synthesis."""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch, AsyncMock

backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from fastapi.testclient import TestClient
from app.main import app, DebriefResponse
from tests.mocks.mock_groq import MockAsyncGroq
from tests.mocks.mock_tts import MockTTSManager

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
    "web_bank_login"
]

class TestChallengerDebriefStress(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app, raise_server_exceptions=False)
        self.tts_manager = MockTTSManager()

    def test_stress_all_twelve_scenarios_success_and_compromised(self):
        """Stress-test all 12 scenarios with both success and failure outcomes."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", None):
            for scenario_id in ALL_12_SCENARIOS:
                for outcome in ["success:survived", "failure:compromised"]:
                    payload = {
                        "scenario_id": scenario_id,
                        "outcome": outcome,
                        "language": "en",
                        "transcript": [{"role": "assistant", "content": "Hello"}]
                    }
                    resp = self.client.post("/api/debrief", json=payload)
                    self.assertEqual(resp.status_code, 200, f"Failed for {scenario_id} outcome {outcome}")
                    data = resp.json()
                    DebriefResponse(**data)
                    self.assertTrue(len(data["headline"]) > 0)
                    self.assertTrue(len(data["tactics_explanation"]) > 0)
                    self.assertGreaterEqual(len(data["dos"]), 2)
                    self.assertGreaterEqual(len(data["donts"]), 2)
                    self.assertTrue(len(data["audio_script"]) > 0)
                    self.assertIsNotNone(data["audio_b64"])

    def test_stress_invalid_and_adversarial_scenario_ids(self):
        """Adversarial scenario IDs must never return 500, but fall back safely to 200 OK."""
        adversarial_ids = [
            "",
            "completely_unknown_scam_id_9999",
            "!@#$%^&*()_+{}[]:;<>,.?/|",
            "A" * 1000,
            "' OR 1=1 -- <script>alert('xss')</script>",
            "🚨🔥詐欺デジタル逮捕👮‍♂️🚨"
        ]
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", None):
            for adv_id in adversarial_ids:
                payload = {
                    "scenario_id": adv_id,
                    "outcome": "success:survived",
                    "language": "en"
                }
                resp = self.client.post("/api/debrief", json=payload)
                self.assertEqual(resp.status_code, 200, f"Adversarial ID failed: {adv_id[:20]}")
                data = resp.json()
                DebriefResponse(**data)
                self.assertTrue(len(data["headline"]) > 0)
                self.assertGreaterEqual(len(data["dos"]), 2)

    def test_stress_payload_missing_and_extreme_transcripts(self):
        """Test minimal payloads, empty transcripts, large transcripts, and 422 validations."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", None):
            # 1. Minimal payload: only scenario_id
            resp = self.client.post("/api/debrief", json={"scenario_id": "call_digital_arrest"})
            self.assertEqual(resp.status_code, 200)
            DebriefResponse(**resp.json())

            # 2. Empty transcript
            resp = self.client.post("/api/debrief", json={"scenario_id": "call_bank_kyc", "transcript": []})
            self.assertEqual(resp.status_code, 200)

            # 3. Mixed format transcript (strings and dicts)
            resp = self.client.post("/api/debrief", json={
                "scenario_id": "call_bank_kyc",
                "transcript": ["Plain text turn", {"role": "user", "content": "Hello"}]
            })
            self.assertEqual(resp.status_code, 200)

            # 4. Large transcript (100 turns)
            large_transcript = [{"role": "user" if i % 2 == 0 else "assistant", "content": f"Turn {i}"} for i in range(100)]
            resp = self.client.post("/api/debrief", json={"scenario_id": "call_tech_support", "transcript": large_transcript})
            self.assertEqual(resp.status_code, 200)

            # 5. Missing required scenario_id -> 422 (never 500)
            resp = self.client.post("/api/debrief", json={})
            self.assertEqual(resp.status_code, 422)

            # 6. Null scenario_id -> 422
            resp = self.client.post("/api/debrief", json={"scenario_id": None})
            self.assertEqual(resp.status_code, 422)

            # 7. Invalid transcript type -> 422
            resp = self.client.post("/api/debrief", json={"scenario_id": "call_bank_kyc", "transcript": "not-a-list"})
            self.assertEqual(resp.status_code, 422)

    def test_stress_multilingual_matrix(self):
        """Verify language parameters, Devanagari script, and voice routing across en, hi, mr, and unhandled."""
        languages = [
            ("en", "en-IN-PrabhatNeural", False),
            ("hi", "hi-IN-MadhurNeural", True),
            ("mr", "mr-IN-AarohiNeural", True),
            ("es", "en-IN-PrabhatNeural", False)  # unsupported language falls back to English voice
        ]
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", None):
            for lang, expected_voice, expect_devanagari in languages:
                self.tts_manager.calls.clear()
                payload = {
                    "scenario_id": "call_digital_arrest",
                    "outcome": "success:survived",
                    "language": lang
                }
                resp = self.client.post("/api/debrief", json=payload)
                self.assertEqual(resp.status_code, 200)
                data = resp.json()
                DebriefResponse(**data)
                if expect_devanagari:
                    self.assertTrue(any('\u0900' <= c <= '\u097f' for c in data["headline"]))
                self.assertEqual(len(self.tts_manager.calls), 1)
                self.assertEqual(self.tts_manager.calls[0]["voice"], expected_voice)
                self.assertEqual(self.tts_manager.calls[0]["rate"], "+0%")

    def test_stress_groq_llm_exceptions_and_timeouts(self):
        """Groq exceptions, timeouts, and syntax errors must fall back cleanly without 500."""
        failure_scenarios = [
            ("Client is None", None),
            ("TimeoutError", MockAsyncGroq(canned_responses=[TimeoutError("Groq timeout")])),
            ("ConnectionError", MockAsyncGroq(canned_responses=[ConnectionError("DNS failure")])),
            ("HTTP 504 Gateway Timeout", MockAsyncGroq(canned_responses=[Exception("504 Gateway Timeout")])),
            ("HTTP 429 Rate Limit", MockAsyncGroq(canned_responses=[Exception("429 Rate limit exceeded")])),
            ("Invalid JSON syntax", MockAsyncGroq(canned_responses=["{ invalid json string })),"])),
            ("Markdown code block", MockAsyncGroq(canned_responses=[
                "```json\n{\"headline\": \"Great job\", \"tactics_explanation\": \"Fear manipulation\", \"dos\": [\"step 1\", \"step 2\"], \"donts\": [\"dont 1\", \"dont 2\"], \"audio_script\": \"Well done.\"}\n```"
            ])),
            ("Empty JSON object", MockAsyncGroq(canned_responses=["{}"]))
        ]
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech):
            for name, groq_mock in failure_scenarios:
                with patch("app.main.client", groq_mock):
                    payload = {
                        "scenario_id": "call_tech_support",
                        "outcome": "success:survived",
                        "language": "en"
                    }
                    resp = self.client.post("/api/debrief", json=payload)
                    self.assertEqual(resp.status_code, 200, f"Failed on {name}: status {resp.status_code}")
                    data = resp.json()
                    DebriefResponse(**data)
                    self.assertTrue(len(data["headline"]) > 0)
                    self.assertTrue(len(data["tactics_explanation"]) > 0)
                    self.assertGreaterEqual(len(data["dos"]), 2)
                    self.assertGreaterEqual(len(data["donts"]), 2)

    def test_stress_edge_tts_failure_modes_and_rate_contract(self):
        """TTS failure or timeout returns 200 OK with audio_b64=None, and rate is strictly '+0%'."""
        # 1. TTS raises exception
        failing_tts = MockTTSManager(should_fail=True)
        with patch("app.main.generate_speech_audio", side_effect=failing_tts.mock_generate_speech), \
             patch("app.main.client", None):
            resp = self.client.post("/api/debrief", json={"scenario_id": "call_bank_kyc"})
            self.assertEqual(resp.status_code, 200)
            data = resp.json()
            self.assertIsNone(data["audio_b64"])
            self.assertTrue(len(data["headline"]) > 0)

        # 2. TTS returns empty bytes
        async def mock_empty_tts(*args, **kwargs):
            return b""
        with patch("app.main.generate_speech_audio", side_effect=mock_empty_tts), \
             patch("app.main.client", None):
            resp = self.client.post("/api/debrief", json={"scenario_id": "call_bank_kyc"})
            self.assertEqual(resp.status_code, 200)
            data = resp.json()
            self.assertIsNone(data["audio_b64"])

        # 3. TTS rate is strictly +0%
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", None):
            self.tts_manager.calls.clear()
            resp = self.client.post("/api/debrief", json={"scenario_id": "call_digital_arrest"})
            self.assertEqual(resp.status_code, 200)
            self.assertEqual(len(self.tts_manager.calls), 1)
            self.assertEqual(self.tts_manager.calls[0]["rate"], "+0%")

    def test_stress_llm_malformed_field_types_must_not_cause_500(self):
        """CRITICAL: If Groq LLM returns valid JSON but with invalid field types (e.g. dos is a string), endpoint must not crash with HTTP 500."""
        malformed_groq = MockAsyncGroq(canned_responses=[{
            "headline": "Scam Alert",
            "tactics_explanation": "Fear manipulation",
            "dos": "Verify caller independently",  # string instead of list of strings
            "donts": ["Never share OTP"],
            "audio_script": "Well done."
        }])
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", malformed_groq):
            resp = self.client.post("/api/debrief", json={"scenario_id": "call_digital_arrest"})
            self.assertEqual(resp.status_code, 200, f"Expected HTTP 200 fallback, got {resp.status_code}: {resp.text}")

    def test_stress_marathi_fallback_audio_script_is_in_marathi(self):
        """When language='mr' and LLM is offline, fallback audio script must be in authentic Marathi, not Hindi."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", None):
            resp = self.client.post("/api/debrief", json={"scenario_id": "call_digital_arrest", "language": "mr"})
            self.assertEqual(resp.status_code, 200)
            data = resp.json()
            # In Marathi, 'तुम्ही' (you) or 'करा' (do) is expected, not Hindi 'आपने' / 'दी'
            self.assertTrue("तुम्ही" in data["audio_script"] or "करा" in data["audio_script"] or "सावध" in data["audio_script"],
                            f"Expected Marathi text, got Hindi: {data['audio_script']}")

if __name__ == "__main__":
    unittest.main()
