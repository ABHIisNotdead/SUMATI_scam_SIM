"""WhatsApp AI Agent for SUMATI Multi-Agent OS Simulation.

Specialized in text-based and multi-modal fraud attempts over WhatsApp.
Enforces strict scenario isolation to prevent context bleed between different scam types.
"""

from __future__ import annotations

import json
import os
from typing import Any, Dict, List, Optional
from pydantic import BaseModel

GROQ_MODEL = os.getenv("GROQ_MODEL", "qwen/qwen3.8-27b")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")


class WhatsAppAgent:
    """Specialized AI agent executing realistic WhatsApp scam interactions."""

    def __init__(self, scenario_type: str = "general_fraud"):
        self.scenario_type = scenario_type

    def build_system_prompt(self, scenario_type: Optional[str] = None, language: str = "en") -> str:
        active_scenario = scenario_type or self.scenario_type
        lang_instruction = (
            "Respond in conversational Hindi (हिंदी)." if language == "hi"
            else ("Respond in conversational Marathi (मराठी)." if language == "mr"
                  else "Respond in conversational English.")
        )

        return (
            f"You are the WhatsApp AI scam agent simulating a realistic fraudster for an elderly user in India.\n"
            f"ACTIVE SCENARIO: {active_scenario}\n"
            f"LANGUAGE: {lang_instruction}\n\n"
            "STRICT CONSTRAINTS (DO NOT VIOLATE):\n"
            "1. You are executing ONE specific scenario. Do NOT mix scams.\n"
            "2. If the scenario is Family Emergency, do NOT send CBI warrants, electricity links, or legal threats. Only emit payloads that strictly match the active scenario.\n"
            "3. If the scenario is Electricity Disconnection, only talk about unpaid electricity bills and power cutoff tonight. Never threaten CBI arrest or police cases.\n"
            "4. If the scenario is Digital Arrest / Police, only talk about legal warrants and police interrogation. Never mention electricity bills or lottery prizes.\n"
            "5. If the scenario is Bank KYC, only talk about bank account freeze and verification OTP. Never send fake police warrants.\n"
            "6. DO NOT loop or repeat phrases like 'Strict legal action will be initiated within 10 minutes'. Adapt each message dynamically to the user's latest statement.\n\n"
            "Respond in valid JSON with this schema:\n"
            "{\n"
            '  "reply": "Your WhatsApp chat message response",\n'
            '  "payload_type": "text" | "link" | "apk" | "qr" | "zip" | "image",\n'
            '  "payload_url": "URL or filename if emitting a payload, else null",\n'
            '  "payload_title": "Short title if emitting a payload, else null"\n'
            "}"
        )

    def get_contextual_fallback(self, user_text: str, scenario_type: Optional[str] = None) -> Dict[str, Any]:
        """Provides non-repeating, scenario-isolated fallback replies when LLM is offline."""
        st = (scenario_type or self.scenario_type).lower()
        lower = user_text.lower()

        if "family" in st or "emergency" in st:
            if "where" in lower or "hospital" in lower or "clinic" in lower:
                return {
                    "reply": "I am at City Care Trauma Center near Civil Hospital. Doctor says surgery can't start without ₹4,500 deposit!",
                    "payload_type": "text",
                    "payload_url": None,
                    "payload_title": None,
                }
            elif "who" in lower or "number" in lower or "phone" in lower:
                return {
                    "reply": "It's me, your nephew Rahul! My phone screen shattered, borrowing clinic phone. Please help urgently.",
                    "payload_type": "text",
                    "payload_url": None,
                    "payload_title": None,
                }
            return {
                "reply": "I am stuck at the clinic and need to clear ₹4,500 medicine bill immediately. Can you please pay to this hospital UPI?",
                "payload_type": "qr",
                "payload_url": "hospital.emergency@oksbi",
                "payload_title": "City Clinic Emergency Desk",
            }

        elif "elec" in st or "bill" in st or "power" in st:
            if "who" in lower or "fake" in lower or "wrong" in lower:
                return {
                    "reply": "This is Junior Engineer Sharma from Electricity Dispatch Desk. Invoice #98214 is showing ₹1,450 unpaid in our database.",
                    "payload_type": "text",
                    "payload_url": None,
                    "payload_title": None,
                }
            elif "how" in lower or "pay" in lower or "link" in lower:
                return {
                    "reply": "Please use this official bill settlement link to clear the ₹1,450 dues and avoid power cutoff tonight.",
                    "payload_type": "link",
                    "payload_url": "https://mseb-bill-pay.in/verify",
                    "payload_title": "Electricity Bill Clearance Portal",
                }
            return {
                "reply": "Consumer #MP-892019, your power supply will be terminated tonight at 9:30 PM due to pending arrears.",
                "payload_type": "link",
                "payload_url": "https://mseb-bill-pay.in/verify",
                "payload_title": "Urgent Disconnection Notice",
            }

        elif "arrest" in st or "police" in st or "cbi" in st:
            if "144" in lower or "section" in lower or "dhara" in lower:
                return {
                    "reply": "Section 144 of CrPC empowers law enforcement to mandate continuous digital surveillance during criminal investigation. Disconnecting is punishable by imprisonment.",
                    "payload_type": "text",
                    "payload_url": None,
                    "payload_title": None,
                }
            elif "id" in lower or "badge" in lower or "number" in lower or "station" in lower:
                return {
                    "reply": "I am Inspector Patil, Badge #MH-7491, Cyber Crime Directorate Unit 4. State your Aadhaar number for identity cross-verification.",
                    "payload_type": "text",
                    "payload_url": None,
                    "payload_title": None,
                }
            elif "not click" in lower or "won't click" in lower or "refuse" in lower or "fake" in lower:
                return {
                    "reply": "Refusal to review judicial court summons will result in immediate dispatch of our local patrol unit to your live GPS coordinates.",
                    "payload_type": "text",
                    "payload_url": None,
                    "payload_title": None,
                }
            elif "order" in lower or "proof" in lower or "warrant" in lower or "who" in lower:
                return {
                    "reply": "Here is the official High Court Digital Arrest Warrant issued against your Aadhaar. Download to inspect charges.",
                    "payload_type": "image",
                    "payload_url": "CONFIDENTIAL_COURT_NOTICE.JPG",
                    "payload_title": "CBI High Court Warrant #892",
                }
            return {
                "reply": "This is Inspector Patil from Cyber Crime Investigation. You are placed under Digital Arrest. You are strictly prohibited from terminating this connection.",
                "payload_type": "text",
                "payload_url": None,
                "payload_title": None,
            }

        elif "kyc" in st or "bank" in st:
            if "who" in lower or "branch" in lower:
                return {
                    "reply": "This is Senior Officer Deshmukh from SBI Card Security Desk. Your debit card was blocked due to pending KYC mandate.",
                    "payload_type": "text",
                    "payload_url": None,
                    "payload_title": None,
                }
            return {
                "reply": "Dear customer, your debit card is blocked. Please verify your 6-digit OTP to prevent permanent account suspension.",
                "payload_type": "text",
                "payload_url": None,
                "payload_title": None,
            }

        return {
            "reply": "Please respond to this urgent notice immediately to avoid penalty.",
            "payload_type": "text",
            "payload_url": None,
            "payload_title": None,
        }

