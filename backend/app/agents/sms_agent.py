"""SMS AI Agent for SUMATI Multi-Agent OS Simulation.

Specialized in short, high-urgency SMS alerts, OTP requests, and fake portal links.
Enforces strict scenario isolation to eliminate context bleed across drills.
"""

from __future__ import annotations

import json
import os
from typing import Any, Dict, List, Optional

GROQ_MODEL = os.getenv("GROQ_MODEL", "qwen/qwen3.8-27b")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")


class SmsAgent:
    """Specialized AI agent executing realistic SMS scam interactions."""

    def __init__(self, scenario_type: str = "general_sms"):
        self.scenario_type = scenario_type

    def build_system_prompt(self, scenario_type: Optional[str] = None, language: str = "en") -> str:
        active_scenario = scenario_type or self.scenario_type
        lang_instruction = (
            "Keep messages in concise conversational Hindi." if language == "hi"
            else ("Keep messages in concise conversational Marathi." if language == "mr"
                  else "Keep messages in concise English.")
        )

        return (
            f"You are the SMS AI scam agent simulating realistic SMS alerts for an elderly user in India.\n"
            f"ACTIVE SCENARIO: {active_scenario}\n"
            f"LANGUAGE: {lang_instruction}\n\n"
            "STRICT CONSTRAINTS (DO NOT VIOLATE):\n"
            "1. You are executing ONE specific scenario. Do NOT mix scams.\n"
            "2. If the scenario is Family Emergency, do NOT send CBI warrants, electricity links, or legal threats. Only emit payloads that strictly match the active scenario.\n"
            "3. If the scenario is Electricity Disconnection, only talk about unpaid electricity bills and power cutoff. Never threaten CBI arrest or police cases.\n"
            "4. If the scenario is Digital Arrest / Police, only talk about legal summons and police warrants. Never mention electricity bills or lottery prizes.\n"
            "5. If the scenario is Bank KYC, only talk about bank account freeze and verification OTP.\n"
            "6. DO NOT loop or repeat phrases like 'Strict legal action will be initiated within 10 minutes'. Craft realistic, varied SMS alerts.\n\n"
            "Respond in valid JSON with this schema:\n"
            "{\n"
            '  "reply": "Short SMS text under 160 characters",\n'
            '  "sender_header": "e.g. AX-SBIBNK or VM-ELEC-PAY or AD-POLICE",\n'
            '  "payload_type": "text" | "link" | "otp",\n'
            '  "payload_url": "URL if including link, else null",\n'
            '  "otp_code": "6-digit OTP code if applicable, else null"\n'
            "}"
        )

    def get_contextual_fallback(self, user_text: str, scenario_type: Optional[str] = None) -> Dict[str, Any]:
        """Provides non-repeating, scenario-isolated fallback SMS replies when LLM is offline."""
        st = (scenario_type or self.scenario_type).lower()
        lower = user_text.lower()

        if "family" in st or "emergency" in st:
            return {
                "reply": "URGENT: Uncle, please transfer the money to this clinic account right now. The doctor is waiting.",
                "sender_header": "RAHUL-EMERGENCY",
                "payload_type": "text",
                "payload_url": None,
                "otp_code": None,
            }

        elif "elec" in st or "bill" in st or "power" in st:
            if "how" in lower or "pay" in lower or "link" in lower:
                return {
                    "reply": "Pay pending ₹1,450 to avoid tonight's 9:30 PM power cutoff: https://mseb-bill-pay.in/pay - Metro Power",
                    "sender_header": "VM-ELEC-PAY",
                    "payload_type": "link",
                    "payload_url": "https://mseb-bill-pay.in/pay",
                    "otp_code": None,
                }
            return {
                "reply": "ALERT: Your electricity connection #MP-892019 is due for disconnection tonight. Call helpline 9820154321.",
                "sender_header": "VM-ELEC-PAY",
                "payload_type": "text",
                "payload_url": None,
                "otp_code": None,
            }

        elif "arrest" in st or "police" in st or "cbi" in st:
            return {
                "reply": "SUMMONS: Central Crime Branch order #892 issued. Confirm receipt of legal notice immediately or face team visit.",
                "sender_header": "AD-CYBERPOLICE",
                "payload_type": "text",
                "payload_url": None,
                "otp_code": None,
            }

        elif "kyc" in st or "bank" in st:
            return {
                "reply": "SBI Alert: 589201 is your OTP to prevent debit card deactivation. Do not share OTP with anyone.",
                "sender_header": "AX-SBIBNK",
                "payload_type": "otp",
                "payload_url": None,
                "otp_code": "589201",
            }

        return {
            "reply": "Urgent update required on your account. Please respond to this message immediately.",
            "sender_header": "AX-SECURE",
            "payload_type": "text",
            "payload_url": None,
            "otp_code": None,
        }

