"""Tests for POST /api/debrief endpoint, Edge-TTS audio synthesis, and resilient fallbacks."""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from fastapi.testclient import TestClient
from app.main import app, DebriefRequest, DebriefResponse
from tests.fixtures import CANNED_DEBRIEF_SUCCESS_LLM, CANNED_DEBRIEF_COMPROMISED_LLM
from tests.mocks.mock_groq import MockAsyncGroq
from tests.mocks.mock_tts import MockTTSManager

class TestDebriefApi(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.tts_manager = MockTTSManager()

    def test_debrief_success_outcome_digital_arrest(self):
        """Successful defense generates celebratory headline, tactics explanation, dos, donts, and audio."""
        mock_groq = MockAsyncGroq(canned_responses=[CANNED_DEBRIEF_SUCCESS_LLM])

        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", mock_groq):
            payload = {
                "scenario_id": "call_digital_arrest",
                "outcome": "success:hung_up",
                "language": "en",
                "transcript": [
                    {"role": "assistant", "content": "You are under digital arrest."},
                    {"role": "user", "content": "Police do not arrest people over phone calls. I am hanging up."}
                ]
            }
            response = self.client.post("/api/debrief", json=payload)
            self.assertEqual(response.status_code, 200)
            data = response.json()

            # Pydantic schema validation
            DebriefResponse(**data)

            self.assertIn("headline", data)
            self.assertTrue("Well done" in data["headline"] or "defuse" in data["headline"] or "congratulations" in data["headline"].lower())
            self.assertIn("tactics_explanation", data)
            self.assertIn("fear", data["tactics_explanation"].lower())
            self.assertIsInstance(data["dos"], list)
            self.assertGreaterEqual(len(data["dos"]), 2)
            self.assertIsInstance(data["donts"], list)
            self.assertGreaterEqual(len(data["donts"]), 2)
            self.assertIn("audio_script", data)
            self.assertIsNotNone(data["audio_b64"])

            # Verify Edge-TTS was called with rate="+0%" for elderly clarity
            self.assertEqual(len(self.tts_manager.calls), 1)
            self.assertEqual(self.tts_manager.calls[0]["rate"], "+0%")
            self.assertEqual(self.tts_manager.calls[0]["voice"], "en-IN-PrabhatNeural")

    def test_debrief_compromised_outcome_bank_kyc(self):
        """Compromised outcome delivers cautionary, constructive debrief."""
        mock_groq = MockAsyncGroq(canned_responses=[CANNED_DEBRIEF_COMPROMISED_LLM])

        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", mock_groq):
            payload = {
                "scenario_id": "call_bank_kyc",
                "outcome": "failure:compromised",
                "language": "en",
                "transcript": [
                    {"role": "assistant", "content": "Tell me the 6-digit OTP code."},
                    {"role": "user", "content": "The code is 482910."}
                ]
            }
            response = self.client.post("/api/debrief", json=payload)
            self.assertEqual(response.status_code, 200)
            data = response.json()

            self.assertTrue("careful" in data["headline"].lower() or "warning" in data["headline"].lower() or "risk" in data["headline"].lower())
            self.assertIn("otp", data["tactics_explanation"].lower())
            self.assertTrue(any("never" in d.lower() for d in data["donts"]))

    def test_debrief_hindi_language_and_voice(self):
        """Hindi debrief returns Devanagari script and selects hi-IN-MadhurNeural voice."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", None): # tests deterministic fallback
            payload = {
                "scenario_id": "call_digital_arrest",
                "outcome": "success:survived",
                "language": "hi",
                "transcript": []
            }
            response = self.client.post("/api/debrief", json=payload)
            self.assertEqual(response.status_code, 200)
            data = response.json()

            # Confirm Devanagari characters
            self.assertTrue(any('\u0900' <= char <= '\u097F' for char in data["headline"]))
            self.assertTrue(any('\u0900' <= char <= '\u097F' for char in data["audio_script"]))
            self.assertTrue("शाबाश" in data["audio_script"] or "बढ़िया" in data["headline"])

            # Verify Hindi voice selection
            self.assertEqual(self.tts_manager.calls[0]["voice"], "hi-IN-MadhurNeural")
            self.assertEqual(self.tts_manager.calls[0]["rate"], "+0%")

    def test_debrief_marathi_voice_selection(self):
        """Marathi language selects mr-IN-AarohiNeural voice."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", None):
            payload = {
                "scenario_id": "call_bank_kyc",
                "outcome": "success:deflected",
                "language": "mr",
                "transcript": []
            }
            response = self.client.post("/api/debrief", json=payload)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(self.tts_manager.calls[0]["voice"], "mr-IN-AarohiNeural")

    def test_debrief_offline_llm_fallback_resilience(self):
        """If Groq LLM times out or client is None, endpoint falls back to scenarios.json metadata with 200 OK."""
        mock_failing_groq = MockAsyncGroq(canned_responses=[Exception("Groq API Timeout 504")])

        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", mock_failing_groq):
            payload = {
                "scenario_id": "call_tech_support",
                "outcome": "success:hung_up",
                "language": "en"
            }
            response = self.client.post("/api/debrief", json=payload)
            self.assertEqual(response.status_code, 200)
            data = response.json()

            self.assertIn("headline", data)
            self.assertTrue("Well done" in data["headline"])
            self.assertIn("tactics_explanation", data)
            # Enriched tactics from scenarios.json should be present
            self.assertTrue(len(data["dos"]) >= 2)
            self.assertTrue(len(data["donts"]) >= 2)

    def test_debrief_tts_failure_non_blocking(self):
        """If Edge-TTS fails or times out, audio_b64 is None but text debrief returns with 200 OK."""
        failing_tts = MockTTSManager(should_fail=True)

        with patch("app.main.generate_speech_audio", side_effect=failing_tts.mock_generate_speech), \
             patch("app.main.client", None):
            payload = {
                "scenario_id": "call_bank_kyc",
                "outcome": "success:survived",
                "language": "en"
            }
            response = self.client.post("/api/debrief", json=payload)
            self.assertEqual(response.status_code, 200)
            data = response.json()

            self.assertIn("headline", data)
            self.assertIsNone(data["audio_b64"])

    def test_debrief_unknown_scenario_fallback(self):
        """Unknown scenario_id falls back to generic catalog fallback without crashing."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", None):
            payload = {
                "scenario_id": "unknown_future_ai_scam",
                "outcome": "success:survived",
                "language": "en"
            }
            response = self.client.post("/api/debrief", json=payload)
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertIn("headline", data)
            self.assertGreater(len(data["dos"]), 0)

if __name__ == "__main__":
    unittest.main()
