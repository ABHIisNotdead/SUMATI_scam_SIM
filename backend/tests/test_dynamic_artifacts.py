"""Tests for Dynamic Notification Artifact triggering and defensive parsing."""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from fastapi.testclient import TestClient
from app.main import app, validate_and_clean_artifact
from tests.fixtures import (
    CANNED_DIGITAL_ARREST_TURN1,
    CANNED_BANK_KYC_TURN1,
    CANNED_ELECTRICITY_TURN1
)
from tests.mocks.mock_groq import MockAsyncGroq
from tests.mocks.mock_tts import MockTTSManager

class TestDynamicArtifacts(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.tts_manager = MockTTSManager()

    def test_dynamic_artifact_emission_digital_arrest_warrant(self):
        """Digital arrest scenario dynamically emits warrant/court_notice artifact when triggered."""
        mock_groq = MockAsyncGroq(canned_responses=[CANNED_DIGITAL_ARREST_TURN1])

        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", mock_groq):
            with self.client.websocket_connect("/ws/chat/call_digital_arrest") as ws:
                # Turn 0 greeting
                turn0 = ws.receive_json()
                self.assertIsNone(turn0["artifact"])

                # Turn 1: Senior asks for warrant
                ws.send_text("Who is this? Show me the warrant.")
                turn1 = ws.receive_json()

                self.assertIsNotNone(turn1["artifact"])
                artifact = turn1["artifact"]
                self.assertIn(artifact["type"], ["court_notice", "warrant"])
                # STRICT CONSTRAINT: Digital arrest MUST NOT emit an OTP!
                self.assertNotEqual(artifact["type"], "otp")
                self.assertEqual(artifact["sender"], "DELHI-POLICE")
                self.assertEqual(artifact["action_label"], "View Warrant")
                self.assertIn("Section 120B/420 IPC", artifact["body"])

    def test_dynamic_artifact_emission_bank_kyc_otp(self):
        """Bank KYC scenario dynamically emits OTP artifact with 6-digit code."""
        mock_groq = MockAsyncGroq(canned_responses=[CANNED_BANK_KYC_TURN1])

        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", mock_groq):
            with self.client.websocket_connect("/ws/chat/call_bank_kyc") as ws:
                # Turn 0
                turn0 = ws.receive_json()
                self.assertIsNone(turn0["artifact"])

                # Turn 1: Senior asks about OTP
                ws.send_text("Why are you calling about my KYC?")
                turn1 = ws.receive_json()

                self.assertIsNotNone(turn1["artifact"])
                artifact = turn1["artifact"]
                self.assertEqual(artifact["type"], "otp")
                self.assertEqual(artifact["sender"], "AX-SBIBNK")
                self.assertEqual(artifact["action_label"], "Copy OTP")
                self.assertIn("482910", artifact["body"])

    def test_dynamic_artifact_emission_electricity_cutoff_link(self):
        """Electricity cutoff scenario dynamically emits cutoff link artifact."""
        mock_groq = MockAsyncGroq(canned_responses=[CANNED_ELECTRICITY_TURN1])

        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", mock_groq):
            with self.client.websocket_connect("/ws/chat/whatsapp_electricity") as ws:
                turn0 = ws.receive_json()
                self.assertIsNone(turn0["artifact"])

                ws.send_text("Where do I pay my bill?")
                turn1 = ws.receive_json()

                self.assertIsNotNone(turn1["artifact"])
                artifact = turn1["artifact"]
                self.assertEqual(artifact["type"], "cutoff_link")
                self.assertEqual(artifact["sender"], "VM-ELEC-PAY")
                self.assertEqual(artifact["action_label"], "Pay Now")
                self.assertIn("http://bijli-pay.xyz/m", artifact["body"])

    def test_turn2_no_artifact_returns_null(self):
        """Subsequent turns where no new artifact is delivered emit artifact == null (single emission rule)."""
        turn2_payload = {
            "reply": "Do not disconnect this call or talk to anyone else in your house.",
            "suggestions": ["I am calling my family.", "I will wait."],
            "status": "ongoing",
            "evaluation": None,
            "artifact": None
        }
        mock_groq = MockAsyncGroq(canned_responses=[CANNED_DIGITAL_ARREST_TURN1, turn2_payload])

        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", mock_groq):
            with self.client.websocket_connect("/ws/chat/call_digital_arrest") as ws:
                ws.receive_json() # Turn 0

                ws.send_text("Show me proof.")
                turn1 = ws.receive_json()
                self.assertIsNotNone(turn1["artifact"])

                ws.send_text("I need to speak to my son.")
                turn2 = ws.receive_json()
                # Verify Turn 2 resets to None
                self.assertIsNone(turn2["artifact"])

    def test_defensive_sanitizer_validation(self):
        """validate_and_clean_artifact defensively sanitizes input and handles malformed data."""
        # Non-dict inputs
        self.assertIsNone(validate_and_clean_artifact(None))
        self.assertIsNone(validate_and_clean_artifact("invalid"))
        self.assertIsNone(validate_and_clean_artifact(123))

        # Missing required fields
        self.assertIsNone(validate_and_clean_artifact({}))
        self.assertIsNone(validate_and_clean_artifact({"type": ""}))
        self.assertIsNone(validate_and_clean_artifact({"type": "otp", "body": ""}))

        # Valid input with normalization
        valid_otp = {
            "type": "sms_code",
            "sender": "AX-SBIBNK",
            "title": "Your OTP",
            "body": "992104 is your verification code.",
            "action_label": "Copy"
        }
        cleaned = validate_and_clean_artifact(valid_otp)
        self.assertIsNotNone(cleaned)
        self.assertEqual(cleaned["type"], "otp")
        self.assertEqual(cleaned["sender"], "AX-SBIBNK")
        self.assertEqual(cleaned["body"], "992104 is your verification code.")

        # Synonym normalization for warrant
        court_doc = {
            "type": "court_order",
            "body": "Seizure notice issued."
        }
        cleaned_court = validate_and_clean_artifact(court_doc)
        self.assertIsNotNone(cleaned_court)
        self.assertEqual(cleaned_court["type"], "court_notice")
        self.assertEqual(cleaned_court["sender"], "Alert") # default fallback
        self.assertEqual(cleaned_court["action_label"], "Open") # default fallback

    def test_http_chat_dynamic_artifact_emission(self):
        """POST /api/chat also sanitizes and returns dynamic artifact."""
        mock_groq = MockAsyncGroq(canned_responses=[CANNED_BANK_KYC_TURN1])

        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", mock_groq):
            payload = {
                "persona": "Bank KYC manager",
                "initial_message": "Hello, KYC verification required.",
                "user_message": "Send the code.",
                "lang": "en"
            }
            response = self.client.post("/api/chat", json=payload)
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertIn("artifact", data)
            self.assertIsNotNone(data["artifact"])
            self.assertEqual(data["artifact"]["type"], "otp")

if __name__ == "__main__":
    unittest.main()
