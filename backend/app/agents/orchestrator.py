"""Central Cross-App Trap Orchestrator & AI Agent Coordinator.

Manages isolated memory buffers for 4 specialized AI agents (Call, WhatsApp, SMS, Web),
tracks simulated smartphone OS sessions, and handles bi-directional WebSocket message
routing and cross-app event triggering.
"""

from __future__ import annotations

import asyncio
import json
import time
import uuid
from enum import Enum
from typing import Any, Dict, List, Literal, Optional, Set
from fastapi import WebSocket
from pydantic import BaseModel, Field
from starlette.websockets import WebSocketState


class AgentType(str, Enum):
    """The four isolated AI agents operating within the simulated OS."""
    CALL = "call"
    WHATSAPP = "whatsapp"
    SMS = "sms"
    WEB = "web"


class CrossAppEvent(BaseModel):
    """Schema for cross-app events dispatched between backend agents and Flutter OS."""
    event_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    event: Literal[
        "trigger_notification",
        "trigger_call",
        "trigger_sms",
        "trigger_whatsapp",
        "trigger_browser",
        "badge_update",
        "compromise_alert",
        "drill_completed",
    ] = Field(..., description="Action trigger type for the Flutter OS")
    target_app: Literal["Phone", "Messages", "FWhatsApp", "Browser"] = Field(
        ..., description="The simulated app on the phone targeted by this event"
    )
    sender: str = Field(
        ..., description="Display sender/header, e.g. 'AX-SBIBNK', 'CBI Mumbai', 'Power Corp'"
    )
    title: str = Field(
        ..., description="Title for the heads-up notification banner"
    )
    body: str = Field(
        ..., description="Body text of notification or message content"
    )
    payload_type: Optional[Literal["text", "link", "apk", "qr", "zip", "image"]] = Field(
        default="text", description="Type of multi-modal attachment or trap"
    )
    payload_url: Optional[str] = Field(
        default=None, description="URL for link/web, or filename for apk/zip/image"
    )
    badge_increment: int = Field(
        default=1, description="Number to increment on the target app's home screen icon badge"
    )
    timestamp: float = Field(
        default_factory=time.time, description="Unix timestamp of event generation"
    )
    metadata: Dict[str, Any] = Field(
        default_factory=dict, description="Scenario-specific contextual parameters"
    )

    def to_client_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary for client consumption."""
        return {
            "event_id": self.event_id,
            "event": self.event,
            "target_app": self.target_app,
            "sender": self.sender,
            "title": self.title,
            "body": self.body,
            "payload_type": self.payload_type,
            "payload_url": self.payload_url,
            "badge_increment": self.badge_increment,
            "timestamp": self.timestamp,
            "metadata": self.metadata,
        }


class ScenarioSession(BaseModel):
    """Maintains isolated memory buffers and state for a single drill session."""
    session_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    scenario_id: str = "call_digital_arrest"
    language: str = "en"
    active_app: str = "Home"
    status: Literal["ongoing", "compromised", "deflected"] = "ongoing"
    compromised_leaks: List[str] = Field(default_factory=list)

    # Isolated memory buffers for each agent
    call_memory: List[Dict[str, str]] = Field(default_factory=list)
    whatsapp_memory: List[Dict[str, str]] = Field(default_factory=list)
    sms_memory: List[Dict[str, str]] = Field(default_factory=list)
    web_memory: List[Dict[str, str]] = Field(default_factory=list)

    created_at: float = Field(default_factory=time.time)
    last_activity: float = Field(default_factory=time.time)

    def get_agent_memory(self, agent_type: AgentType) -> List[Dict[str, str]]:
        """Retrieve memory buffer for a specific agent."""
        if agent_type == AgentType.CALL:
            return self.call_memory
        elif agent_type == AgentType.WHATSAPP:
            return self.whatsapp_memory
        elif agent_type == AgentType.SMS:
            return self.sms_memory
        elif agent_type == AgentType.WEB:
            return self.web_memory
        return []

    def append_turn(self, agent_type: AgentType, role: str, content: str) -> None:
        """Append turn to the agent's isolated memory."""
        self.last_activity = time.time()
        mem = self.get_agent_memory(agent_type)
        mem.append({"role": role, "content": content})


class Orchestrator:
    """Manages active simulated OS drill sessions and dispatches cross-app events."""

    def __init__(self) -> None:
        self._sessions: Dict[str, ScenarioSession] = {}
        self._active_sockets: Dict[str, Set[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def create_session(
        self,
        scenario_id: str = "call_digital_arrest",
        language: str = "en",
        session_id: Optional[str] = None,
    ) -> ScenarioSession:
        """Create or initialize a scenario session."""
        sid = session_id or str(uuid.uuid4())
        session = ScenarioSession(
            session_id=sid,
            scenario_id=scenario_id,
            language=language,
        )
        async with self._lock:
            self._sessions[sid] = session
            if sid not in self._active_sockets:
                self._active_sockets[sid] = set()
        return session

    def get_session(self, session_id: str) -> Optional[ScenarioSession]:
        """Fetch session by ID."""
        return self._sessions.get(session_id)

    async def register_socket(self, session_id: str, websocket: WebSocket) -> None:
        """Register a connected WebSocket for a session."""
        async with self._lock:
            if session_id not in self._active_sockets:
                self._active_sockets[session_id] = set()
            self._active_sockets[session_id].add(websocket)

    async def unregister_socket(self, session_id: str, websocket: WebSocket) -> None:
        """Remove disconnected WebSocket from session."""
        async with self._lock:
            if session_id in self._active_sockets:
                self._active_sockets[session_id].discard(websocket)
                if not self._active_sockets[session_id]:
                    del self._active_sockets[session_id]

    async def broadcast_event(self, session_id: str, event: CrossAppEvent) -> int:
        """Broadcast cross-app event to all connected sockets for a session."""
        sockets = self._active_sockets.get(session_id, set()).copy()
        if not sockets:
            return 0

        payload_str = json.dumps({
            "type": "cross_app_event",
            "data": event.to_client_dict(),
        })

        delivered_count = 0
        dead_sockets: List[WebSocket] = []

        for ws in sockets:
            try:
                if ws.client_state == WebSocketState.CONNECTED:
                    await ws.send_text(payload_str)
                    delivered_count += 1
                else:
                    dead_sockets.append(ws)
            except Exception:
                dead_sockets.append(ws)

        if dead_sockets:
            async with self._lock:
                for dead in dead_sockets:
                    if session_id in self._active_sockets:
                        self._active_sockets[session_id].discard(dead)

        return delivered_count

    async def trigger_cross_app_action(
        self,
        session_id: str,
        target_app: Literal["Phone", "Messages", "FWhatsApp", "Browser"],
        sender: str,
        title: str,
        body: str,
        payload_type: Literal["text", "link", "apk", "qr", "zip", "image"] = "text",
        payload_url: Optional[str] = None,
        event_type: Literal[
            "trigger_notification", "trigger_call", "trigger_sms", "trigger_whatsapp", "trigger_browser"
        ] = "trigger_notification",
        metadata: Optional[Dict[str, Any]] = None,
    ) -> CrossAppEvent:
        """Helper to construct, record, and dispatch a cross-app event."""
        session = self.get_session(session_id)
        scenario_id = session.scenario_id if session else "unknown"

        meta = metadata or {}
        meta["scenario_id"] = scenario_id

        event = CrossAppEvent(
            event=event_type,
            target_app=target_app,
            sender=sender,
            title=title,
            body=body,
            payload_type=payload_type,
            payload_url=payload_url,
            badge_increment=1,
            metadata=meta,
        )

        # Record incoming message in the target agent's memory
        if session:
            target_agent = {
                "Phone": AgentType.CALL,
                "Messages": AgentType.SMS,
                "FWhatsApp": AgentType.WHATSAPP,
                "Browser": AgentType.WEB,
            }.get(target_app, AgentType.CALL)
            session.append_turn(target_agent, "assistant", f"[{payload_type.upper()}] {body}")

        await self.broadcast_event(session_id, event)
        return event

    async def route_client_message(
        self, session_id: str, source_app: str, message_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Route client user action/input to the designated backend AI agent."""
        session = self.get_session(session_id)
        if not session:
            session = await self.create_session(session_id=session_id)

        session.active_app = source_app
        action_type = message_data.get("action", "send_message")
        text = message_data.get("text", "").strip()

        # Check for compromise triggers (e.g. user submitted OTP or agreed to download APK)
        lower_text = text.lower()
        if "482910" in lower_text or ("otp" in lower_text and ("hai" in lower_text or "is" in lower_text)):
            session.status = "compromised"
            session.compromised_leaks.append("Shared 6-digit Banking OTP")
            compromise_event = CrossAppEvent(
                event="compromise_alert",
                target_app=source_app if source_app in ["Phone", "Messages", "FWhatsApp", "Browser"] else "Phone",
                sender="SYSTEM_TRAP",
                title="🚨 TRAP TRIGGERED!",
                body="You revealed your secret OTP code to the scammer!",
                metadata={"reason": "OTP_SHARED", "leaks": session.compromised_leaks},
            )
            await self.broadcast_event(session_id, compromise_event)
            return {"status": "compromised", "reason": "OTP_SHARED"}

        if "download_apk" in action_type or "install_app" in action_type:
            session.status = "compromised"
            session.compromised_leaks.append("Installed malicious APK remote access tool")
            compromise_event = CrossAppEvent(
                event="compromise_alert",
                target_app=source_app if source_app in ["Phone", "Messages", "FWhatsApp", "Browser"] else "FWhatsApp",
                sender="SYSTEM_TRAP",
                title="🚨 DEVICE COMPROMISED!",
                body="You granted permission to install an untrusted remote access APK!",
                metadata={"reason": "MALICIOUS_APK_INSTALLED", "leaks": session.compromised_leaks},
            )
            await self.broadcast_event(session_id, compromise_event)
            return {"status": "compromised", "reason": "MALICIOUS_APK_INSTALLED"}

        # Record user turn in the agent's memory
        agent_type = {
            "Phone": AgentType.CALL,
            "Messages": AgentType.SMS,
            "FWhatsApp": AgentType.WHATSAPP,
            "Browser": AgentType.WEB,
        }.get(source_app, AgentType.CALL)
        session.append_turn(agent_type, "user", text)

        return {
            "status": "received",
            "session_id": session_id,
            "source_app": source_app,
            "agent": agent_type.value,
        }


# Global singleton orchestrator instance
orchestrator = Orchestrator()

