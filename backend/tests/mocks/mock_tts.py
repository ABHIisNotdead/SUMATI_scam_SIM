"""Mock implementation of Edge-TTS speech generation."""
import base64

# Standard ID3 MP3 mock bytes header
DUMMY_MP3_BYTES = b"ID3\x03\x00\x00\x00\x00\x00\x00\xff\xfb\x90\x44" + (b"\x00" * 32)
DUMMY_MP3_B64 = base64.b64encode(DUMMY_MP3_BYTES).decode("utf-8")

class MockTTSManager:
    """Tracks TTS generation calls and returns instant mock audio bytes."""
    def __init__(self, should_fail: bool = False):
        self.calls = []
        self.should_fail = should_fail

    async def mock_generate_speech(self, text: str, voice: str | None = None, rate: str = "+18%") -> bytes:
        self.calls.append({"text": text, "voice": voice, "rate": rate})
        if self.should_fail:
            raise Exception("Mock Edge-TTS Network Failure")
        return DUMMY_MP3_BYTES
