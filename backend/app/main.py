import asyncio
import base64
import json
import os
import traceback
from pathlib import Path

import edge_tts
from dotenv import load_dotenv
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel
from starlette.websockets import WebSocketState

from . import db

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
    pin: str | None = "1234"
    safety_score: int | None = 100
    total_drills: int | None = 0
    avoided_drills: int | None = 0

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

@app.get("/tts")
async def tts_audio_endpoint(text: str, voice: str | None = None, rate: str | None = "+18%"):
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
            pin=request.pin or "1234",
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

async def run_chat_session(websocket: WebSocket, persona: str, initial_message: str, lang: str = "en"):
    await websocket.accept()
    
    lang_name = "Hindi (हिंदी)" if lang == "hi" else ("Marathi (मराठी)" if lang == "mr" else "English")

    system_prompt = (
        "You are an elite AI roleplaying a realistic, cunning fraudster/scammer in an interactive scam drill for elderly users in India.\n"
        f"Your specific persona: {persona}.\n"
        "Your objective: Pressure, deceive, and manipulate the senior into complying (transferring money, sharing OTP/PIN, clicking links, or downloading apps).\n\n"
        "LANGUAGE ADAPTABILITY & MULTILINGUAL FLUENCY (CRITICAL):\n"
        f"- Initial conversation language: {lang_name}.\n"
        "- MULTILINGUAL CAPABILITY: You are completely fluent in Hindi (हिंदी), English, Marathi (मराठी), and Hinglish.\n"
        "- INSTANT LANGUAGE SWITCHING: If the user asks you to speak in Hindi ('speak in hindi', 'हिंदी में बात करो', 'हिंदी बोलो', 'mujhe english nahi aati') OR replies in Hindi/Marathi, you MUST IMMEDIATELY SWITCH TO THAT LANGUAGE (in authentic Devanagari script for Hindi/Marathi: 'हाँ जी, सुनिए...', 'हो, नक्की...').\n"
        "- NEVER say 'I cannot speak Hindi' or 'I am an AI'. Real Indian fraudsters seamlessly switch between Hindi and English to trick victims.\n"
        "- Keep replies short (1-2 sentences), conversational, urgent, and emotionally manipulative.\n\n"
        "RESPONSE FORMAT:\n"
        "You MUST respond ONLY in valid JSON format with this exact structure:\n"
        "{\n"
        '  "reply": "Your next scammer dialogue (1-2 sentences in the active language)",\n'
        '  "suggestions": ["3 short suggested user replies in the active language (2 defensive/suspicious and 1 compliant)"],\n'
        '  "status": "ongoing", "compromised", or "deflected",\n'
        '  "evaluation": "If compromised or deflected, 1 sentence in the active language debriefing why. If ongoing, null."\n'
        "}\n\n"
        "STATUS RULES:\n"
        "- 'ongoing': The user is chatting, arguing, or asking questions.\n"
        "- 'compromised': The user agrees to pay, provides OTP/PIN, clicks link, or agrees to install app. Drill ends.\n"
        "- 'deflected': The user firmly refuses, threatens police/1930, says they will visit official bank branch, or hangs up. Drill ends."
    )
    
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
        "evaluation": None
    }
    
    conversation = [
        {"role": "system", "content": system_prompt},
        {"role": "assistant", "content": json.dumps(llm_initial_payload)}
    ]
    
    # Send greeting to Flutter WITH audio_b64 for playback
    client_initial_payload = dict(llm_initial_payload)
    client_initial_payload["audio_b64"] = initial_audio_b64
    if not await safe_send_json(websocket, client_initial_payload):
        return

    max_tokens = 500 if "gpt-oss" in GROQ_MODEL else 350
    
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
                
                # Append clean text-only turn to LLM history
                llm_reply = {
                    "reply": reply_text,
                    "suggestions": suggestions,
                    "status": status,
                    "evaluation": evaluation
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
                
                # Send to Flutter client with audio
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
                    "evaluation": None
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
    lang: str = "en"
):
    await run_chat_session(websocket, persona, initial_message, lang)

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
    await run_chat_session(websocket, persona, initial_message, lang)
