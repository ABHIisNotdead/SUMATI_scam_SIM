"""Mock implementation of Groq client for deterministic offline testing."""
import json
from unittest.mock import AsyncMock, MagicMock
from typing import List, Dict, Any, Optional

class MockGroqChoice:
    def __init__(self, content: str):
        self.message = MagicMock(content=content)

class MockGroqResponse:
    def __init__(self, content: str):
        self.choices = [MockGroqChoice(content)]

class MockAsyncGroq:
    """Configurable mock for AsyncGroq client."""
    def __init__(self, canned_responses: Optional[List[Any]] = None):
        self.chat = MagicMock()
        self.chat.completions = MagicMock()
        self.canned_responses: List[Any] = list(canned_responses or [])
        self._call_count = 0
        self.history: List[Dict[str, Any]] = []

        async def _create(**kwargs):
            self.history.append(kwargs)
            if self.canned_responses and self._call_count < len(self.canned_responses):
                resp_payload = self.canned_responses[self._call_count]
                self._call_count += 1
                if isinstance(resp_payload, Exception):
                    raise resp_payload
            else:
                # Default ongoing conversation fallback
                resp_payload = {
                    "reply": "This is an automated test response.",
                    "suggestions": ["Why are you calling?", "I will check this."],
                    "status": "ongoing",
                    "evaluation": None,
                    "artifact": None
                }
            json_str = json.dumps(resp_payload) if isinstance(resp_payload, dict) else str(resp_payload)
            return MockGroqResponse(json_str)

        self.chat.completions.create = AsyncMock(side_effect=_create)

    def set_next_response(self, response: Any):
        """Queue a specific response for the next completion call."""
        self.canned_responses.append(response)
