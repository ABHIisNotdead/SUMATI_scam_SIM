import asyncio
import base64
import json
import os
import re
import traceback
from pathlib import Path

import edge_tts
from dotenv import load_dotenv
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field
from starlette.websockets import WebSocketState
from typing import Optional, List, Dict, Any, Union, Literal

from . import db
from .agents.orchestrator import orchestrator, CrossAppEvent, AgentType

# Ensure .env is loaded regardless of current working directory
backend_dir = Path(__file__).resolve().parent.parent
env_path = backend_dir / ".env"
if env_path.exists():
    load_dotenv(dotenv_path=env_path)
else:
    load_dotenv()

# Select model: default to qwen/qwen3.8-27b (direct chat, ultra-fast, zero wasted reasoning tokens)
GROQ_MODEL = os.getenv("GROQ_MODEL", "qwen/qwen3.8-27b")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

app = FastAPI(title="Sumati Backend")

# Enable CORS for Flutter Web and cross-origin requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize the Groq client
client = None
try:
    from groq import AsyncGroq
    client = AsyncGroq(api_key=GROQ_API_KEY)
except ImportError:
    from openai import AsyncOpenAI
    client = AsyncOpenAI(
        api_key=GROQ_API_KEY,
        base_url="https://api.groq.com/openai/v1"
    )

class TTSRequest(BaseModel):
    text: str
    voice: Optional[str] = None
    rate: Optional[str] = "+18%"

class TextCheckRequest(BaseModel):
    text: str
    lang: str | None = "en"

class EmergencyTriageRequest(BaseModel):
    text: str
    lang: str | None = "en"

class RecordScamRequest(BaseModel):
    user_phone: str | None = None
    phone: str | None = None
    upi: str | None = None
    link: str | None = None
    amount: str | None = None
    story: str
    lang: str | None = "en"

class UserSyncRequest(BaseModel):
    phone: str
    name: str
    pin: str | None = None
    safety_score: int | None = 100
    total_drills: int | None = 0
    avoided_drills: int | None = 0

class BatchDrillSyncRequest(BaseModel):
    user_phone: str
    drills: list[dict] = []

class FamilyAuthRequest(BaseModel):
    senior_phone: str
    pin: str
    family_phone: str | None = None
    family_name: str | None = None

class DrillRecordRequest(BaseModel):
    user_phone: str
    scenario_title: str
    channel: str
    status: str

class ChatTurnRequest(BaseModel):
    persona: str = "a scammer attempting fraud"
    initial_message: str = "Hello. Please respond urgently."
    messages: list[dict] = []  # List of {"role": "user"|"assistant", "content": "..."}
    user_message: str
    lang: str = "en"
    scenario_id: Optional[str] = None

class ScenarioArtifact(BaseModel):
    """Notification artifact displayed dynamically on user device during scam simulation."""
    type: str = Field(
        ...,
        description="Artifact type: 'otp', 'court_notice', 'cutoff_link', or 'warrant'"
    )
    sender: str = Field(
        ...,
        description="Sender ID / Header, e.g. 'AX-SBIBNK', 'DELHI-POLICE', 'VM-ELEC-PAY'"
    )
    title: str = Field(
        ...,
        description="Notification title, e.g. 'Arrest Warrant Issued', 'SBI KYC Verification'"
    )
    body: str = Field(
        ...,
        description="Body text of notification including OTP code, link, or warrant details"
    )
    action_label: str = Field(
        ...,
        description="Action button label, e.g. 'View Warrant', 'Copy OTP', 'Pay Now'"
    )

class WebSocketChatMessage(BaseModel):
    """Payload sent over WebSocket (/ws/chat) to Flutter client."""
    reply: str = Field(..., description="Scammer speech dialogue text")
    suggestions: List[str] = Field(default_factory=list, description="Suggested user response chips")
    status: Literal["ongoing", "compromised", "deflected"] = "ongoing"
    evaluation: Optional[str] = Field(None, description="Debrief explanation if status != ongoing")
    audio_b64: Optional[str] = Field(None, description="Base64 encoded MP3 audio bytes from Edge-TTS")
    artifact: Optional[ScenarioArtifact] = Field(None, description="Dynamic notification artifact or null")

class DebriefRequest(BaseModel):
    scenario_id: str
    outcome: str = "success:survived"
    language: str = "en"
    transcript: List[Union[Dict[str, Any], str]] = []

class DebriefResponse(BaseModel):
    headline: str
    tactics_explanation: str
    dos: List[str]
    donts: List[str]
    audio_script: str
    audio_b64: Optional[str] = None

# Global cached scenarios catalog
_SCENARIOS_CACHE: Dict[str, Dict[str, Any]] = {}

def get_scenarios_catalog() -> Dict[str, Dict[str, Any]]:
    global _SCENARIOS_CACHE
    if _SCENARIOS_CACHE:
        return _SCENARIOS_CACHE

    backend_data_path = backend_dir / "data" / "scenarios.json"
    assets_data_path = backend_dir.parent / "assets" / "scenarios" / "scenarios.json"

    for path in [backend_data_path, assets_data_path]:
        if path.exists():
            try:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        _SCENARIOS_CACHE = {item["id"]: item for item in data if isinstance(item, dict) and "id" in item}
                        return _SCENARIOS_CACHE
                    elif isinstance(data, dict):
                        _SCENARIOS_CACHE = data
                        return _SCENARIOS_CACHE
            except Exception as e:
                print(f"Error loading scenarios from {path}: {e}")

    return _SCENARIOS_CACHE

def validate_and_clean_artifact(raw_artifact: Any, scenario_id: Optional[str] = None) -> Optional[dict]:
    """Defensively validate and sanitize dynamic artifact output from LLM.
    
    Enforces:
    1. Rejection of non-dict, empty, or explicit null/None artifact structures (Defect 1).
    2. Strict mapping to contract schema: 'otp', 'court_notice', 'cutoff_link', 'warrant'.
    3. Rejection of unmapped / unrecognized artifact types (e.g. 'bitcoin_transfer') (Defect 2).
    4. Safe fallback defaults for missing or null optional fields (no literal 'None' strings) (Defect 3).
    5. Programmatic suppression of 'otp' artifacts in non-OTP scenarios (digital arrest, police, electricity) (Requirement R1).
    """
    if not isinstance(raw_artifact, dict):
        return None

    raw_type = raw_artifact.get("type")
    raw_body = raw_artifact.get("body")
    if not raw_type or not raw_body:
        return None

    artifact_type = str(raw_type).strip().lower()
    body = str(raw_body).strip()
    if not artifact_type or not body or artifact_type in ("none", "null") or body.lower() in ("none", "null"):
        return None

    # Normalize common synonyms to contract schema
    if "warrant" in artifact_type or "court" in artifact_type or "order" in artifact_type:
        artifact_type = "warrant" if "warrant" in artifact_type else "court_notice"
    elif "otp" in artifact_type or "code" in artifact_type:
        artifact_type = "otp"
    elif "link" in artifact_type or "bill" in artifact_type or "cut" in artifact_type or "url" in artifact_type:
        artifact_type = "cutoff_link"
    else:
        # Strictly reject unmapped / unrecognized types (Defect 2 fix)
        return None

    # Programmatic scenario constraint: non-OTP scenarios NEVER emit an OTP (Requirement R1 / Defect 4 fix)
    if scenario_id:
        sid_lower = scenario_id.lower()
        if any(kw in sid_lower for kw in ("digital_arrest", "police", "electricity")):
            if artifact_type == "otp":
                return None

    # Extract optional fields with defensive fallback defaults (Defect 3 fix)
    raw_sender = raw_artifact.get("sender")
    raw_title = raw_artifact.get("title")
    raw_action = raw_artifact.get("action_label") or raw_artifact.get("action")

    sender_str = str(raw_sender).strip() if raw_sender is not None else ""
    title_str = str(raw_title).strip() if raw_title is not None else ""
    action_str = str(raw_action).strip() if raw_action is not None else ""

    sender = sender_str if sender_str and sender_str.lower() not in ("none", "null") else "Alert"
    title = title_str if title_str and title_str.lower() not in ("none", "null") else "Official Notice"
    action_label = action_str if action_str and action_str.lower() not in ("none", "null") else "Open"

    return {
        "type": artifact_type,
        "sender": sender,
        "title": title,
        "body": body,
        "action_label": action_label
    }

def detect_and_enrich_conversational_artifact(
    reply_text: str,
    current_artifact: Optional[dict],
    scenario_id: Optional[str] = None,
    persona: str = ""
) -> Optional[dict]:
    """Dynamically trigger or ensure the appropriate notification artifact based on AI conversation context."""
    # If the LLM already emitted a valid artifact, use it
    if current_artifact and isinstance(current_artifact, dict) and current_artifact.get("type"):
        return current_artifact

    reply_lower = reply_text.lower()
    persona_lower = persona.lower()
    sid_lower = (scenario_id or "").lower()

    # Rule 1: Scammer demands OTP / SMS verification code
    is_otp_context = (
        "otp" in reply_lower or "ओटीपी" in reply_text or "code" in reply_lower or
        "6-digit" in reply_lower or "verification code" in reply_lower or
        "सिक्स डिजिट" in reply_text or "पासवर्ड" in reply_text or "पिन" in reply_text or
        ("sms" in reply_lower and ("check" in reply_lower or "dekho" in reply_lower or "bheja" in reply_lower or "sent" in reply_lower))
    )
    is_non_otp_scenario = any(kw in sid_lower for kw in ("digital_arrest", "police", "electricity", "cbi"))
    if is_otp_context and not is_non_otp_scenario:
        sender = "AX-SBIBNK" if "sbi" in persona_lower else ("VM-HDFCBK" if "hdfc" in persona_lower else "VK-BANKALERT")
        return {
            "type": "otp",
            "sender": sender,
            "title": "Bank Account Verification Code",
            "body": "Do NOT share with anyone. Your secret OTP is 482910 to verify your account. Valid for 10 minutes.",
            "action_label": "Copy OTP"
        }

    # Rule 2: Scammer sends payment link / electricity cutoff / phishing URL
    is_link_context = (
        "link" in reply_lower or "लिंक" in reply_text or "http" in reply_lower or
        "pay" in reply_lower or "cutoff" in reply_lower or "kat jayegi" in reply_lower or
        "disconnected" in reply_lower or "bill" in reply_lower or "bijli" in reply_lower or
        "बिजली" in reply_text or "payment" in reply_lower or "click" in reply_lower
    )
    if is_link_context and not any(kw in sid_lower for kw in ("digital_arrest", "cbi")):
        return {
            "type": "cutoff_link",
            "sender": "VM-ELEC-PAY",
            "title": "Urgent Disconnection Notice",
            "body": "Electricity bill payment of ₹4,820 is overdue. Power disconnects tonight. Pay now: http://power-pay.in/bill",
            "action_label": "Pay Now"
        }

    # Rule 3: Digital arrest / warrant / official court notice
    is_warrant_context = (
        "arrest" in reply_lower or "warrant" in reply_lower or "वारंट" in reply_text or
        "अरेस्ट" in reply_text or "cbi" in reply_lower or "court" in reply_lower or
        "police" in reply_lower or "narcotics" in reply_lower or "digital arrest" in reply_lower
    )
    if is_warrant_context and any(kw in sid_lower for kw in ("digital_arrest", "cbi", "police")):
        return {
            "type": "warrant",
            "sender": "DELHI-POLICE-HQ",
            "title": "Digital Arrest Warrant Issued",
            "body": "ORDER: Non-bailable arrest warrant issued under IPC Sec 420/120B. You are under live digital surveillance.",
            "action_label": "View Warrant"
        }

    return None

def build_scammer_system_prompt(persona: str, lang: str = "en", scenario_id: Optional[str] = None) -> str:
    lang_name = "Hindi (हिंदी)" if lang == "hi" else ("Marathi (मराठी)" if lang == "mr" else "English")
    scenario_hint = f"Scenario ID: {scenario_id}.\n" if scenario_id else ""
    return (
        "You are an elite AI roleplaying a realistic, cunning fraudster/scammer in an interactive scam drill for elderly users in India.\n"
        f"Your specific persona: {persona}.\n"
        f"{scenario_hint}"
        "Your objective: Pressure, deceive, and manipulate the senior into complying (transferring money, sharing OTP/PIN, clicking links, or downloading apps).\n\n"
        "LANGUAGE ADAPTABILITY & MULTILINGUAL FLUENCY (CRITICAL):\n"
        f"- Initial conversation language: {lang_name}.\n"
        "- MULTILINGUAL CAPABILITY: You are completely fluent in Hindi (हिंदी), English, Marathi (मराठी), and Hinglish.\n"
        "- INSTANT LANGUAGE SWITCHING: If the user asks you to speak in Hindi ('speak in hindi', 'हिंदी में बात करो', 'हिंदी बोलो', 'mujhe english nahi aati') OR replies in Hindi/Marathi, you MUST IMMEDIATELY SWITCH TO THAT LANGUAGE (in authentic Devanagari script for Hindi/Marathi: 'हाँ जी, सुनिए...', 'हो, नक्की...').\n"
        "- NEVER say 'I cannot speak Hindi' or 'I am an AI'. Real Indian fraudsters seamlessly switch between Hindi and English to trick victims.\n"
        "- Keep replies short (1-2 sentences), conversational, urgent, and emotionally manipulative.\n\n"
        "DYNAMIC SCENARIO NOTIFICATION ARTIFACTS:\n"
        "During the drill, you can dynamically trigger an on-screen simulated notification artifact (such as a simulated SMS OTP, official court notice, power cutoff warning, or APK download link) to pressure the senior into complying.\n\n"
        "MANDATORY ARTIFACT RULES:\n"
        "1. CALL START / TURN 0 INVARIANT: Never emit an artifact on turn 0 or before the scenario context is established. Turn 0 artifact is always null.\n"
        "2. CONVERSATIONAL TRIGGER: Only emit an artifact on the exact turn where your persona tells the victim that you have sent, issued, or dispatched it, or when directing them to check their phone/screen.\n"
        "3. SINGLE EMISSION RULE: On turns where no artifact is being delivered or referenced, set 'artifact': null. Do NOT emit an artifact on every turn. Once an artifact has been emitted, keep 'artifact': null on subsequent turns unless issuing a distinct, updated document.\n"
        "4. SCENARIO MATCHING (CRITICAL):\n"
        "   - Digital Arrest / Police / CBI: type 'warrant' or 'court_notice', sender 'DELHI-POLICE' or 'CBI-HQ-DELHI', title 'Arrest Warrant Issued', action_label 'View Warrant'. CRITICAL: NEVER emit an 'otp' in Digital Arrest!\n"
        "   - Bank KYC: type 'otp', sender 'AX-SBIBNK' or 'VM-HDFCBK', title 'SBI KYC Verification Code', body with 6-digit OTP, action_label 'Copy OTP'.\n"
        "   - Electricity Cutoff: type 'cutoff_link', sender 'VM-ELEC-PAY', title 'Electricity Cutoff Notice', action_label 'Pay Now'.\n"
        "   - Other scenarios: Set 'artifact': null unless a concrete document or link is sent.\n\n"
        "RESPONSE FORMAT:\n"
        "You MUST respond ONLY in valid JSON format with this exact structure:\n"
        "{\n"
        '  "reply": "Your next scammer dialogue (1-2 sentences in the active language)",\n'
        '  "suggestions": ["3 short suggested user replies in the active language (2 defensive/suspicious and 1 compliant)"],\n'
        '  "status": "ongoing", "compromised", or "deflected",\n'
        '  "evaluation": "If compromised or deflected, 1 sentence in the active language debriefing why. If ongoing, null",\n'
        '  "artifact": null OR {"type": "otp"|"court_notice"|"cutoff_link"|"warrant", "sender": "...", "title": "...", "body": "...", "action_label": "..."}\n'
        "}\n\n"
        "STATUS RULES:\n"
        "- 'ongoing': The user is chatting, arguing, or asking questions.\n"
        "- 'compromised': The user agrees to pay, provides OTP/PIN, clicks link, or agrees to install app. Drill ends.\n"
        "- 'deflected': The user firmly refuses, threatens police/1930, says they will visit official bank branch, or hangs up. Drill ends."
    )

def _to_clean_str_list(raw_val: Any, fallback_list: Optional[List[str]] = None) -> List[str]:
    """Defensively convert any LLM output (str, list of dicts/strings, dict, or None) into a clean List[str]."""
    fb = fallback_list if fallback_list is not None else ["Verify caller independently.", "Report scams to 1930."]
    if raw_val is None:
        return fb

    if isinstance(raw_val, list):
        cleaned: List[str] = []
        for item in raw_val:
            if isinstance(item, str):
                s = item.strip()
                if s:
                    cleaned.append(s)
            elif isinstance(item, dict):
                # Extract values if LLM emitted [{"step": "Verify badge", "tip": "..."}]
                vals = [str(v).strip() for v in item.values() if v and isinstance(v, (str, int, float))]
                if vals:
                    cleaned.append(" - ".join(vals))
            elif isinstance(item, (int, float)):
                cleaned.append(str(item).strip())
        if cleaned:
            return cleaned
        return fb

    if isinstance(raw_val, str):
        s = raw_val.strip()
        if not s:
            return fb
        # Handle multiline string or bulleted/numbered list
        lines = [re.sub(r"^[\s\-\*\•\d+\.\)]+", "", line).strip() for line in s.splitlines()]
        cleaned = [l for l in lines if l]
        if cleaned:
            return cleaned
        return [s]

    if isinstance(raw_val, dict):
        # Handle dictionary e.g. {"1": "step 1", "2": "step 2"}
        vals = [str(v).strip() for v in raw_val.values() if v and isinstance(v, (str, int, float))]
        if vals:
            return vals
        return fb

    return fb

def generate_debrief_fallback(scenario_id: str, outcome: str, language: str, scenario_data: Optional[dict] = None) -> dict:
    is_success = outcome.startswith("success")
    lang = language.lower() if language else "en"
    data = scenario_data or {}

    title = data.get("title", scenario_id.replace("_", " ").title())
    tactics_expl = data.get("tactics_explanation") or (
        "Real fraudsters exploit emotional urgency, false authority, and social pressure to bypass your rational defenses."
    )

    dos = data.get("dos") or [
        "Always independently verify the caller's identity through official channels.",
        "Hang up immediately if an unverified caller pressures you for money or codes.",
        "Report any suspicious interaction to the 1930 Cyber Helpline."
    ]

    donts = data.get("donts") or [
        "Never share OTPs, PINs, or banking credentials over the phone.",
        "Never transfer money to any unverified account claimed to be for security.",
        "Never allow strangers remote access to your computer or mobile phone."
    ]

    if lang == "hi":
        dos_spoken = " ".join([f"पहला, {d}" if i == 0 else (f"दूसरा, {d}" if i == 1 else f"तीसरा, {d}") for i, d in enumerate(dos)])
        donts_spoken = " ".join([f"{d}" for d in donts])
        if is_success:
            headline = "बहुत बढ़िया! आपने धोखाधड़ी को पहचान कर खुद को सुरक्षित रखा।"
            audio_script = (
                f"बहुत बढ़िया! आपने {title} के खतरे को बहुत समझदारी से मात दी। "
                f"आइए समझें कि असली ठग कैसे दिमाग से खेलते हैं: {tactics_expl} "
                f"यहाँ बताया गया है कि आपको क्या करना चाहिए: {dos_spoken} "
                f"और इन बातों से हमेशा बचें: {donts_spoken} "
                "हमेशा सतर्क रहें, सुरक्षित रहें!"
            )
        else:
            headline = "सावधान रहें! असली स्थिति में ऐसे कॉल से आपका नुकसान हो सकता था।"
            audio_script = (
                f"सावधान! असली स्थिति में {title} के निर्देशों का पालन करने से आपके पैसे का नुकसान हो सकता था। "
                f"आइए समझें कि असली ठग कैसे डराते हैं: {tactics_expl} "
                f"यहाँ बताया गया है कि आपको क्या करना चाहिए: {dos_spoken} "
                f"और इन गलतियों से हमेशा बचें: {donts_spoken} "
                "याद रखें, किसी भी संदेह पर तुरंत कॉल काटें और 1930 पर सहायता लें।"
            )
    elif lang == "mr":
        dos_spoken = " ".join([f"पहिले, {d}" if i == 0 else (f"दुसरे, {d}" if i == 1 else f"तिसरे, {d}") for i, d in enumerate(dos)])
        donts_spoken = " ".join([f"{d}" for d in donts])
        if is_success:
            headline = "खूप छान! तुम्ही या फसवणुकीला ओळखून स्वतःला सुरक्षित ठेवले."
            tactics_expl = "खरे सायबर गुन्हेगार भीती, घाई आणि खोट्या अधिकाराचा गैरवापर करून लोकांवर मानसिक दबाव आणतात."
            audio_script = (
                f"शाब्बास! तुम्ही {title} चा धोका अत्यंत हुशारीने टाळला. "
                f"खरे भामटे कशी फसवणूक करतात ते समजून घ्या: {tactics_expl} "
                f"नेहमी हे उपाय करा: {dos_spoken} "
                f"या गोष्टी कटाक्षाने टाळा: {donts_spoken} "
                "नेहमी सावध राहा आणि सुरक्षित राहा!"
            )
        else:
            headline = "सावध राहा! प्रत्यक्ष संभाषणात अशा कॉलमुळे तुमचे मोठे नुकसान झाले असते."
            tactics_expl = "सायबर गुन्हेगार बँक खाते बंद करण्याची किंवा अटकेची खोटी भीती दाखवून घाईघाईत निर्णय घेण्यास भाग पाडतात."
            audio_script = (
                f"सावध राहा! प्रत्यक्ष संभाषणात {title} च्या जाळ्यात अडकल्यामुळे तुमचे आर्थिक नुकसान झाले असते. "
                f"भामटे कशी फसवणूक करतात ते समजून घ्या: {tactics_expl} "
                f"नेहमी हे उपाय करा: {dos_spoken} "
                f"या गोष्टी कटाक्षाने टाळा: {donts_spoken} "
                "दबावाखाली येऊन कधीही पैसे पाठवू नका. नेहमी फोन कट करा आणि १९३० वर मदत मागा."
            )
    else:
        dos_spoken = " ".join([f"Step {i+1}: {d}" for i, d in enumerate(dos)])
        donts_spoken = " ".join([f"Avoid: {d}" for d in donts])
        if is_success:
            headline = "Well done! You successfully identified and defused the scam."
            audio_script = (
                f"Well done! You stayed calm and successfully defused this {title} attempt. "
                f"Here is how real scammers operate: {tactics_expl} "
                f"Here is what you should always do: {dos_spoken} "
                f"Here is what you must always avoid: {donts_spoken} "
                "Stay vigilant and protect your hard-earned savings!"
            )
        else:
            headline = "Be careful! In a real call, following these steps could cost you money."
            audio_script = (
                f"Be careful! In a real situation, following these instructions during {title} could have put your money at risk. "
                f"Here is how real scammers manipulate victims: {tactics_expl} "
                f"Here is what you should always do: {dos_spoken} "
                f"Here is what you must always avoid: {donts_spoken} "
                "Remember, immediately hang up and report any suspicious interaction to 1930."
            )

    return {
        "headline": headline,
        "tactics_explanation": tactics_expl,
        "dos": dos,
        "donts": donts,
        "audio_script": audio_script
    }

@app.on_event("startup")
async def on_startup():
    db.init_db()

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "message": "Sumati backend is running",
        "model": GROQ_MODEL,
        "api_key_configured": bool(GROQ_API_KEY)
    }

def select_voice(text: str, requested_voice: str | None = None) -> str:
    if requested_voice:
        return requested_voice
    # Check for Devanagari script (Hindi/Marathi)
    if any('\u0900' <= char <= '\u097F' for char in text):
        return "hi-IN-MadhurNeural"
    return "en-IN-PrabhatNeural"

async def generate_speech_audio(text: str, voice: str | None = None, rate: str = "+18%") -> bytes:
    async def _fetch() -> bytes:
        selected = select_voice(text, voice)
        communicate = edge_tts.Communicate(text, selected, rate=rate)
        audio_data = b""
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_data += chunk["data"]
        return audio_data

    try:
        # Enforce strict 8-second timeout on external neural audio synthesis
        return await asyncio.wait_for(_fetch(), timeout=8.0)
    except (asyncio.TimeoutError, Exception) as e:
        print(f"Edge-TTS synthesis error/timeout: {e}")
        return b""

@app.post("/tts")
async def tts_audio_endpoint(request: TTSRequest):
    try:
        audio = await generate_speech_audio(request.text, request.voice, rate=request.rate or "+18%")
        return Response(content=audio, media_type="audio/mpeg")
    except Exception as e:
        print(f"TTS endpoint error: {e}")
        return Response(status_code=500, content=b"")

@app.get("/tts")
async def tts_audio_endpoint_get(text: str, voice: str | None = None, rate: str | None = "+18%"):
    try:
        audio = await generate_speech_audio(text, voice, rate=rate or "+18%")
        return Response(content=audio, media_type="audio/mpeg")
    except Exception as e:
        print(f"TTS endpoint error: {e}")
        return Response(status_code=500, content=b"")

@app.post("/check")
async def check_text(request: TextCheckRequest):
    lang_name = "Hindi" if request.lang == "hi" else ("Marathi" if request.lang == "mr" else "English")
    system_prompt = (
        f"You are a cybersecurity AI protecting elderly users in India. Active language: {lang_name}. "
        "Analyze the user's message/text and determine if it is a scam, phishing, or safe. "
        "Respond strictly in valid JSON format with these exact keys: "
        '1. "is_scam": boolean (true/false), '
        '2. "risk_level": "HIGH_RISK", "SUSPICIOUS", or "SAFE", '
        f'3. "title": Short impactful headline in {lang_name}, '
        f'4. "explanation": 1-2 sentence plain language explanation of why it is dangerous in {lang_name}, '
        f'5. "what_to_do": list of 3-4 bullet steps on what the user must do right now in {lang_name}, '
        '6. "color": "red" (High Risk), "amber" (Suspicious), or "green" (Safe).'
    )
    
    try:
        response = await client.chat.completions.create(
            model=GROQ_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": request.text}
            ],
            temperature=0.0,
            max_tokens=400,
            response_format={"type": "json_object"}
        )
        
        raw_content = response.choices[0].message.content or "{}"
        cleaned = raw_content.strip()
        if cleaned.startswith("```"):
            lines = cleaned.split("\n")
            if lines[0].startswith("```"):
                lines = lines[1:]
            if lines and lines[-1].startswith("```"):
                lines = lines[:-1]
            cleaned = "\n".join(lines).strip()
            
        result = json.loads(cleaned)
        
        # Synthesize realistic neural voice audio
        title = result.get("title", "")
        expl = result.get("explanation", "")
        speech_text = f"{title}. {expl}"
        audio_b64 = None
        try:
            audio_bytes = await generate_speech_audio(speech_text)
            audio_b64 = base64.b64encode(audio_bytes).decode('utf-8')
        except Exception as tts_err:
            print(f"Edge-TTS check error: {tts_err}")
            
        result["audio_b64"] = audio_b64
        return result
        
    except Exception as e:
        print(f"Groq Checker Error: {type(e).__name__}: {e}")
        traceback.print_exc()
        return {
            "is_scam": True,
            "risk_level": "SUSPICIOUS",
            "title": "Warning / चेतावनी",
            "explanation": "Could not analyze the text via remote AI. Please remain cautious and never share OTPs.",
            "what_to_do": ["Never share OTP or PIN.", "Do not click links."],
            "color": "amber",
            "audio_b64": None
        }

@app.post("/emergency_triage")
async def emergency_triage(request: EmergencyTriageRequest):
    lang_name = "Hindi" if request.lang == "hi" else ("Marathi" if request.lang == "mr" else "English")
    system_prompt = (
        f"You are the Emergency Cybersecurity Triage AI for elderly victims in India. Active language: {lang_name}. "
        "The user is panicking after facing a cyber fraud. "
        "Provide comforting, calm, clear step-by-step emergency instructions in 2-3 sentences. "
        "Always emphasize: "
        "1. Golden Hour rule: Immediately call 1930 Cyber Helpline to freeze funds. "
        "2. Call bank customer care to freeze debit card and UPI. "
        "3. If AnyDesk/TeamViewer was downloaded, turn off internet immediately and uninstall it. "
        f"Respond in {lang_name}. Format strictly as JSON with key 'advice'."
    )
    
    try:
        response = await client.chat.completions.create(
            model=GROQ_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": request.text}
            ],
            temperature=0.2,
            max_tokens=300,
            response_format={"type": "json_object"}
        )
        raw_content = response.choices[0].message.content or "{}"
        result = json.loads(raw_content)
        advice = result.get("advice", "Please call 1930 Cyber Helpline immediately and contact your bank to block your cards.")
        
        # Synthesize realistic neural voice audio
        audio_b64 = None
        try:
            audio_bytes = await generate_speech_audio(advice)
            audio_b64 = base64.b64encode(audio_bytes).decode('utf-8')
        except Exception as tts_err:
            print(f"Triage TTS error: {tts_err}")
            
        return {"advice": advice, "audio_b64": audio_b64}
    except Exception as e:
        print(f"Emergency Triage Error: {e}")
        fallback = (
            "घबराएं नहीं, शांत रहें। तुरंत 1930 पर कॉल करें और बैंक को फोन करके डेबिट कार्ड ब्लॉक करवाएं।"
            if request.lang in ["hi", "mr"]
            else "Stay calm. Immediately call 1930 Cyber Helpline and call your bank to block your debit cards."
        )
        return {"advice": fallback, "audio_b64": None}

@app.post("/record_scam")
@app.post("/api/scam_reports")
async def record_scam(request: RecordScamRequest):
    lang_name = "Hindi" if request.lang == "hi" else ("Marathi" if request.lang == "mr" else "English")
    
    # Generate tailored response via Groq AI
    system_prompt = (
        f"You are an AI Cyber Intelligence Analyst for Sumati in India. Active language: {lang_name}. "
        "A user has submitted how a scammer tried to target them. "
        "Provide a 2-sentence confirmation and tailored guidance in {lang_name} based on whether they sent money, clicked links, or shared numbers. "
        "Format strictly as JSON with key 'advice'."
    )
    user_payload = f"Phone: {request.phone}, UPI: {request.upi}, Link: {request.link}, Amount: {request.amount}, Story: {request.story}"
    
    advice = "Details recorded safely. If money was transferred, call 1930 immediately."
    audio_b64 = None
    report_id = None
    
    try:
        response = await client.chat.completions.create(
            model=GROQ_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_payload}
            ],
            temperature=0.2,
            max_tokens=250,
            response_format={"type": "json_object"}
        )
        raw_content = response.choices[0].message.content or "{}"
        result = json.loads(raw_content)
        advice = result.get("advice", advice)
    except Exception as e:
        print(f"Record Scam AI Error: {e}")
        advice = "विवरण सुरक्षित रूप से रिकॉर्ड कर लिया गया है। यदि पैसे कटे हैं तो 1930 पर तुरंत कॉल करें।" if request.lang in ["hi", "mr"] else advice

    # Synthesize realistic neural voice audio on the fly (in RAM only, zero disk files)
    try:
        audio_bytes = await generate_speech_audio(advice)
        audio_b64 = base64.b64encode(audio_bytes).decode('utf-8')
    except Exception as tts_err:
        print(f"Record scam TTS error: {tts_err}")

    # Save to SQLite Database
    try:
        report_id = db.insert_scam_report(
            user_phone=request.user_phone,
            scammer_phone=request.phone,
            scammer_upi=request.upi,
            scammer_link=request.link,
            scam_amount=request.amount,
            story=request.story,
            ai_analysis=advice,
            language=request.lang or 'en'
        )
    except Exception as db_err:
        print(f"Failed to save scam report to DB: {db_err}")

    return {
        "report_id": report_id,
        "advice": advice,
        "audio_b64": audio_b64,
        "recorded": True
    }

@app.get("/api/scam_reports")
async def get_scam_reports_endpoint(limit: int = 50):
    try:
        return db.list_scam_reports(limit=limit)
    except Exception as e:
        print(f"Error listing scam reports: {e}")
        return {"total_reports": 0, "reports": []}

@app.post("/api/users/sync")
async def sync_user_endpoint(request: UserSyncRequest):
    try:
        user = db.sync_user(
            phone=request.phone,
            name=request.name,
            pin=request.pin,
            safety_score=request.safety_score or 100,
            total_drills=request.total_drills or 0,
            avoided_drills=request.avoided_drills or 0
        )
        return {"success": True, "user": user}
    except Exception as e:
        print(f"Error syncing user: {e}")
        return {"success": False, "error": str(e)}

@app.get("/api/users/{phone}")
async def get_user_endpoint(phone: str):
    user = db.get_user_by_phone(phone)
    if not user:
        return {"found": False, "user": None}
    return {"found": True, "user": user}

@app.post("/api/family/authorize")
async def family_authorize_endpoint(request: FamilyAuthRequest):
    success, message, senior = db.authorize_family_connect(
        senior_phone=request.senior_phone,
        pin=request.pin,
        family_phone=request.family_phone,
        family_name=request.family_name
    )
    if not success:
        return {"authorized": False, "message": message, "data": None}
    
    dashboard_data = db.get_senior_dashboard_data(request.senior_phone)
    return {"authorized": True, "message": message, "data": dashboard_data}

@app.get("/api/family/senior_status")
async def senior_status_endpoint(senior_phone: str):
    data = db.get_senior_dashboard_data(senior_phone)
    if not data:
        return {"found": False, "data": None}
    return {"found": True, "data": data}

@app.post("/api/drills/record")
async def record_drill_endpoint(request: DrillRecordRequest):
    try:
        db.record_drill(
            user_phone=request.user_phone,
            scenario_title=request.scenario_title,
            channel=request.channel,
            status=request.status
        )
        return {"success": True}
    except Exception as e:
        print(f"Error recording drill: {e}")
        return {"success": False, "error": str(e)}

@app.post("/api/drills/batch_sync")
async def batch_sync_drills_endpoint(request: BatchDrillSyncRequest):
    try:
        count = db.batch_sync_drills(
            user_phone=request.user_phone,
            drills=request.drills
        )
        return {"success": True, "synced_count": count}
    except Exception as e:
        print(f"Error batch syncing drills: {e}")
        return {"success": False, "error": str(e), "synced_count": 0}

@app.post("/api/chat")
async def chat_http_endpoint(request: ChatTurnRequest):
    system_prompt = build_scammer_system_prompt(request.persona, request.lang, scenario_id=request.scenario_id)

    conv_messages = [{"role": "system", "content": system_prompt}]
    for m in request.messages:
        role = "assistant" if m.get("isUser") is False or m.get("role") == "assistant" else "user"
        content = m.get("text") or m.get("content") or ""
        if content:
            conv_messages.append({"role": role, "content": content})
            
    conv_messages.append({"role": "user", "content": request.user_message})
    
    # Use sliding window of last 6 messages
    turns = conv_messages[1:][-6:]
    payload_messages = [conv_messages[0]] + turns

    try:
        max_tokens = 500
        response = await client.chat.completions.create(
            model=GROQ_MODEL,
            messages=payload_messages,
            max_tokens=max_tokens,
            temperature=0.7,
            response_format={"type": "json_object"}
        )
        ai_json_reply = response.choices[0].message.content or "{}"
        cleaned = ai_json_reply.strip()
        if cleaned.startswith("```"):
            lines = cleaned.split("\n")
            if lines[0].startswith("```"):
                lines = lines[1:]
            if lines and lines[-1].startswith("```"):
                lines = lines[:-1]
            cleaned = "\n".join(lines).strip()

        parsed = json.loads(cleaned)
        reply_text = parsed.get("reply", "Please respond immediately, this is urgent.")
        suggestions = parsed.get("suggestions", ["I am hanging up.", "I will call the official helpline."])
        status = parsed.get("status", "ongoing")
        evaluation = parsed.get("evaluation")
        raw_artifact = parsed.get("artifact")
        cleaned_artifact = validate_and_clean_artifact(raw_artifact, scenario_id=request.scenario_id)

        reply_audio_b64 = None
        try:
            if reply_text:
                reply_bytes = await generate_speech_audio(reply_text)
                reply_audio_b64 = base64.b64encode(reply_bytes).decode("utf-8")
        except Exception as e:
            print(f"HTTP Chat Edge-TTS error: {e}")

        return {
            "reply": reply_text,
            "suggestions": suggestions,
            "status": status,
            "evaluation": evaluation,
            "audio_b64": reply_audio_b64,
            "artifact": cleaned_artifact
        }
    except Exception as e:
        print(f"HTTP Chat error: {e}")
        return {
            "reply": "Are you still there? Please respond immediately or legal action will be taken.",
            "suggestions": ["I am calling the police.", "I will not share any details."],
            "status": "ongoing",
            "evaluation": None,
            "audio_b64": None,
            "artifact": None
        }

async def safe_send_json(websocket: WebSocket, data: dict) -> bool:
    try:
        if websocket.client_state == WebSocketState.CONNECTED:
            await websocket.send_text(json.dumps(data))
            return True
    except (WebSocketDisconnect, RuntimeError):
        pass
    except Exception as e:
        print(f"safe_send_json error: {e}")
    return False

async def run_chat_session(
    websocket: WebSocket,
    persona: str,
    initial_message: str,
    lang: str = "en",
    scenario_id: Optional[str] = None
):
    await websocket.accept()
    
    system_prompt = build_scammer_system_prompt(persona, lang, scenario_id)
    
    initial_audio_b64 = None
    try:
        audio_bytes = await generate_speech_audio(initial_message)
        initial_audio_b64 = base64.b64encode(audio_bytes).decode('utf-8')
    except Exception as e:
        print(f"Initial Edge-TTS generation error: {e}")

    # Localized initial fallback suggestions
    if lang == "hi":
        initial_suggestions = ["आप कौन हैं?", "मुझे पहले इसकी पुष्टि करनी होगी।", "ठीक है, भुगतान कैसे करूँ?"]
    elif lang == "mr":
        initial_suggestions = ["तुम्ही कोण आहात?", "मला आधी हे तपासावे लागेल.", "ठीक आहे, पैसे कसे भरायचे?"]
    else:
        initial_suggestions = ["Who is this?", "I need to verify this first.", "Okay, how do I pay?"]

    llm_initial_payload = {
        "reply": initial_message,
        "suggestions": initial_suggestions,
        "status": "ongoing",
        "evaluation": None,
        "artifact": None
    }
    
    conversation = [
        {"role": "system", "content": system_prompt},
        {"role": "assistant", "content": json.dumps(llm_initial_payload)}
    ]
    
    # Send greeting to Flutter WITH audio_b64 for playback and explicit artifact: None (Turn 0 invariant)
    client_initial_payload = dict(llm_initial_payload)
    client_initial_payload["audio_b64"] = initial_audio_b64
    client_initial_payload["artifact"] = None
    if not await safe_send_json(websocket, client_initial_payload):
        return

    max_tokens = 500
    
    try:
        while True:
            try:
                user_text = await websocket.receive_text()
            except (WebSocketDisconnect, RuntimeError):
                print("Client disconnected from chat simulation")
                break
                
            conversation.append({"role": "user", "content": user_text})
            
            # Use sliding window of last 4 messages to conserve token quota
            recent_turns = conversation[1:][-4:]
            request_messages = [conversation[0]] + recent_turns
            
            try:
                response = await client.chat.completions.create(
                    model=GROQ_MODEL,
                    messages=request_messages,
                    max_tokens=max_tokens,
                    temperature=0.7,
                    response_format={"type": "json_object"}
                )
                
                ai_json_reply = response.choices[0].message.content or ""
                cleaned = ai_json_reply.strip()
                if cleaned.startswith("```"):
                    lines = cleaned.split("\n")
                    if lines[0].startswith("```"):
                        lines = lines[1:]
                    if lines and lines[-1].startswith("```"):
                        lines = lines[:-1]
                    cleaned = "\n".join(lines).strip()
                
                # Verify JSON structure
                parsed = json.loads(cleaned)
                reply_text = parsed.get("reply", "Please respond immediately, this is urgent.")
                suggestions = parsed.get("suggestions", ["I am hanging up.", "I will call the official helpline."])
                status = parsed.get("status", "ongoing")
                evaluation = parsed.get("evaluation")
                raw_artifact = parsed.get("artifact")
                cleaned_artifact = validate_and_clean_artifact(raw_artifact, scenario_id=scenario_id)
                final_artifact = detect_and_enrich_conversational_artifact(
                    reply_text=reply_text,
                    current_artifact=cleaned_artifact,
                    scenario_id=scenario_id,
                    persona=persona,
                )
                
                # Append clean text-only turn to LLM history
                llm_reply = {
                    "reply": reply_text,
                    "suggestions": suggestions,
                    "status": status,
                    "evaluation": evaluation,
                    "artifact": final_artifact
                }
                conversation.append({"role": "assistant", "content": json.dumps(llm_reply)})
                
                # Generate audio for the client using Edge-TTS
                reply_audio_b64 = None
                try:
                    if reply_text:
                        reply_bytes = await generate_speech_audio(reply_text)
                        reply_audio_b64 = base64.b64encode(reply_bytes).decode('utf-8')
                except Exception as e:
                    print(f"Reply Edge-TTS generation error: {e}")
                
                # Send to Flutter client with audio and dynamic artifact
                client_reply = dict(llm_reply)
                client_reply["audio_b64"] = reply_audio_b64
                if not await safe_send_json(websocket, client_reply):
                    break
                
            except (WebSocketDisconnect, RuntimeError):
                print("Client disconnected during message processing")
                break
            except Exception as e:
                print(f"Groq Chat Completion Error: {type(e).__name__}: {e}")
                traceback.print_exc()
                error_payload = {
                    "reply": "Connection issue. Please retry your reply.",
                    "suggestions": ["Retry / पुनः प्रयास"],
                    "status": "ongoing",
                    "evaluation": None,
                    "audio_b64": None,
                    "artifact": None
                }
                if not await safe_send_json(websocket, error_payload):
                    break
                
    except (WebSocketDisconnect, RuntimeError):
        print("Chat simulation ended cleanly")

@app.websocket("/ws/chat")
async def websocket_chat_query_endpoint(
    websocket: WebSocket,
    persona: str = "a scammer attempting fraud",
    initial_message: str = "Hello. Please respond urgently.",
    lang: str = "en",
    scenario_id: Optional[str] = None
):
    await run_chat_session(websocket, persona, initial_message, lang, scenario_id=scenario_id)

@app.websocket("/ws/os_session")
async def websocket_os_session_endpoint(
    websocket: WebSocket,
    session_id: str = "default_session",
    scenario_id: str = "call_digital_arrest",
):
    await websocket.accept()
    session = await orchestrator.create_session(session_id=session_id, scenario_id=scenario_id)
    await orchestrator.register_websocket(session_id, websocket)
    try:
        while True:
            raw_text = await websocket.receive_text()
            try:
                data = json.loads(raw_text)
                source_app = data.get("source_app", "Phone")
                await orchestrator.route_client_action(session_id, source_app, data)
            except Exception as e:
                print(f"[OS Session] Error processing client action: {e}")
    except (WebSocketDisconnect, RuntimeError):
        print(f"[OS Session] WebSocket disconnected for session {session_id}")
    finally:
        await orchestrator.unregister_websocket(session_id, websocket)

@app.websocket("/ws/chat/{scenario_id}")
async def websocket_chat_path_endpoint(
    websocket: WebSocket,
    scenario_id: str,
    persona: str | None = None,
    initial_message: str | None = None,
    lang: str = "en"
):
    # If not supplied as query params, create dynamic defaults based on scenario_id
    if not persona:
        cleaned_name = scenario_id.replace("_", " ").title()
        persona = f"a scammer in a '{cleaned_name}' fraud attempt"
    if not initial_message:
        initial_message = f"Urgent notice regarding your {scenario_id.replace('_', ' ')}. Action required immediately."
    await run_chat_session(websocket, persona, initial_message, lang, scenario_id=scenario_id)

@app.post("/api/debrief", response_model=DebriefResponse)
async def debrief_endpoint(request: DebriefRequest):
    catalog = get_scenarios_catalog()
    scenario_info = catalog.get(request.scenario_id, {})
    is_success = request.outcome.startswith("success")
    lang_name = "Hindi (हिंदी)" if request.language == "hi" else ("Marathi (मराठी)" if request.language == "mr" else "English")

    system_prompt = (
        f"You are the Cybersecurity Debriefing AI for Sumati, protecting senior citizens in India. Active language: {lang_name}.\n"
        "Your task: Provide a warm, clear, educational debrief for an elderly person after a simulated scam call.\n"
        "Guidelines:\n"
        "1. Cheering / Congratulatory Tone: If the outcome was a success (deflected, survived, hung up), begin with enthusiastic praise ('Well done! / शाबाश!'). If compromised, be gentle, comforting, and cautionary.\n"
        "2. Emotional Manipulation Breakdown: Explain in plain terms how real fraudsters manipulate psychology (fear, urgency, false authority, isolation) in this specific scam.\n"
        "3. Concrete Do's and Don'ts: Provide 2-3 specific, actionable Do's and 2-3 Don'ts.\n"
        "4. Audio Script: Provide a 2-3 sentence conversational spoken script (35-50 words) suitable for an elderly listener.\n\n"
        "Respond STRICTLY in valid JSON matching this schema:\n"
        "{\n"
        '  "headline": "Short impactful title (e.g. Well done! ...)",\n'
        '  "tactics_explanation": "2-3 sentences explaining real-world scammer manipulation tricks",\n'
        '  "dos": ["Do step 1", "Do step 2", "Do step 3"],\n'
        '  "donts": ["Don\'t step 1", "Don\'t step 2"],\n'
        '  "audio_script": "Spoken debrief guidance for senior audio player"\n'
        "}"
    )

    user_payload = {
        "scenario_id": request.scenario_id,
        "scenario_title": scenario_info.get("title", request.scenario_id),
        "scenario_goal": scenario_info.get("goal", ""),
        "known_tactics": scenario_info.get("tactics_explanation") or scenario_info.get("psychological_tricks", []),
        "outcome": request.outcome,
        "transcript": request.transcript
    }

    debrief_data = None
    if client and GROQ_API_KEY:
        try:
            response = await asyncio.wait_for(
                client.chat.completions.create(
                    model=GROQ_MODEL,
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": json.dumps(user_payload)}
                    ],
                    temperature=0.2,
                    max_tokens=450,
                    response_format={"type": "json_object"}
                ),
                timeout=6.0
            )
            raw_content = response.choices[0].message.content or "{}"
            cleaned = raw_content.strip()
            if cleaned.startswith("```"):
                lines = cleaned.split("\n")
                if lines[0].startswith("```"):
                    lines = lines[1:]
                if lines and lines[-1].startswith("```"):
                    lines = lines[:-1]
                cleaned = "\n".join(lines).strip()
            debrief_data = json.loads(cleaned)
        except Exception as e:
            print(f"Debrief LLM Error/Timeout: {e}")

    # Fallback if LLM failed or missing fields
    if not debrief_data or not isinstance(debrief_data, dict) or "headline" not in debrief_data:
        debrief_data = generate_debrief_fallback(
            scenario_id=request.scenario_id,
            outcome=request.outcome,
            language=request.language,
            scenario_data=scenario_info
        )

    # Defensively normalize fields before model instantiation
    headline = str(debrief_data.get("headline") or ("Well done!" if is_success else "Be careful!")).strip()
    tactics_explanation = str(debrief_data.get("tactics_explanation") or "Scammers use fear and urgency to manipulate victims.").strip()
    dos = _to_clean_str_list(debrief_data.get("dos"), ["Verify caller independently.", "Report scams to 1930."])
    donts = _to_clean_str_list(debrief_data.get("donts"), ["Never share OTPs.", "Never transfer money to callers."])
    audio_script = str(debrief_data.get("audio_script") or f"{headline} {tactics_explanation}").strip()

    # Edge-TTS Neural Voice Synthesis (rate="+0%" for elderly clarity)
    audio_b64 = None
    try:
        if audio_script:
            selected_voice = "en-IN-PrabhatNeural"
            if request.language == "hi":
                selected_voice = "hi-IN-MadhurNeural"
            elif request.language == "mr":
                selected_voice = "mr-IN-AarohiNeural"
            elif any('\u0900' <= char <= '\u097F' for char in audio_script):
                selected_voice = "hi-IN-MadhurNeural"

            audio_bytes = await generate_speech_audio(audio_script, voice=selected_voice, rate="+0%")
            if audio_bytes:
                audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")
    except Exception as tts_err:
        print(f"Debrief Edge-TTS error: {tts_err}")

    # Guaranteed model creation: Tier 1 sanitized inputs; Tier 2 fallback guard
    try:
        return DebriefResponse(
            headline=headline,
            tactics_explanation=tactics_explanation,
            dos=dos,
            donts=donts,
            audio_script=audio_script,
            audio_b64=audio_b64
        )
    except Exception as model_err:
        print(f"Debrief response model validation error, falling back: {model_err}")
        fb = generate_debrief_fallback(
            scenario_id=request.scenario_id,
            outcome=request.outcome,
            language=request.language,
            scenario_data=scenario_info
        )
        return DebriefResponse(**fb, audio_b64=audio_b64)
