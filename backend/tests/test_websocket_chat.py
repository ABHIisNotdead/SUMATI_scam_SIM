"""Tests for WebSocket chat initialization and Turn 0 invariant."""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

# Ensure backend root is on sys.path
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from fastapi.testclient import TestClient
from app.main import app
from tests.mocks.mock_groq import MockAsyncGroq
from tests.mocks.mock_tts import MockTTSManager

class TestWebSocketChat(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.tts_manager = MockTTSManager()
        self.mock_groq = MockAsyncGroq()

    def test_ws_chat_turn0_default_artifact_is_null(self):
        """Turn 0 on /ws/chat must emit greeting with artifact == None."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", self.mock_groq):
            with self.client.websocket_connect("/ws/chat") as ws:
                data = ws.receive_json()
                self.assertIn("reply", data)
                self.assertEqual(data["status"], "ongoing")
                self.assertIsNone(data["evaluation"])
                # Key Invariant: Turn 0 artifact must be None (null in JSON)
                self.assertIn("artifact", data)
                self.assertIsNone(data["artifact"])
                self.assertIsNotNone(data["audio_b64"])
                self.assertIsInstance(data["suggestions"], list)
                self.assertGreater(len(data["suggestions"]), 0)

    def test_ws_chat_scenario_path_digital_arrest_turn0_no_artifact(self):
        """Digital arrest scenario must never show OTP or any artifact on Turn 0."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", self.mock_groq):
            with self.client.websocket_connect("/ws/chat/call_digital_arrest") as ws:
                data = ws.receive_json()
                self.assertEqual(data["status"], "ongoing")
                self.assertIsNone(data["artifact"])
                # Confirm scammer greeting is scenario-related
                self.assertTrue("digital" in data["reply"].lower() or "cbi" in data["reply"].lower() or "arrest" in data["reply"].lower())

    def test_ws_chat_scenario_path_electricity_turn0_no_artifact(self):
        """Electricity cutoff scenario must not show cutoff link on Turn 0."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", self.mock_groq):
            with self.client.websocket_connect("/ws/chat/whatsapp_electricity") as ws:
                data = ws.receive_json()
                self.assertEqual(data["status"], "ongoing")
                self.assertIsNone(data["artifact"])
                self.assertTrue("electricity" in data["reply"].lower() or "power" in data["reply"].lower() or "bill" in data["reply"].lower())

    def test_ws_chat_scenario_path_bank_kyc_turn0_no_artifact(self):
        """Bank KYC scenario must not emit OTP popup on Turn 0 (only on dynamic trigger)."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", self.mock_groq):
            with self.client.websocket_connect("/ws/chat/call_bank_kyc") as ws:
                data = ws.receive_json()
                self.assertEqual(data["status"], "ongoing")
                self.assertIsNone(data["artifact"])

    def test_ws_chat_turn0_multilingual_localization(self):
        """Turn 0 suggestions localize according to lang parameter."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", self.mock_groq):
            # Hindi
            with self.client.websocket_connect("/ws/chat?lang=hi") as ws:
                data = ws.receive_json()
                self.assertIsNone(data["artifact"])
                self.assertTrue(any('\u0900' <= char <= '\u097F' for s in data["suggestions"] for char in s))

            # Marathi
            with self.client.websocket_connect("/ws/chat?lang=mr") as ws:
                data = ws.receive_json()
                self.assertIsNone(data["artifact"])
                self.assertTrue(any('\u0900' <= char <= '\u097F' for s in data["suggestions"] for char in s))

    def test_ws_chat_disconnect_clean_exit(self):
        """Client disconnecting without error completes session cleanly."""
        with patch("app.main.generate_speech_audio", side_effect=self.tts_manager.mock_generate_speech), \
             patch("app.main.client", self.mock_groq):
            with self.client.websocket_connect("/ws/chat") as ws:
                data = ws.receive_json()
                self.assertIsNotNone(data)
                # Simply close the connection
                ws.close()

if __name__ == "__main__":
    unittest.main()
