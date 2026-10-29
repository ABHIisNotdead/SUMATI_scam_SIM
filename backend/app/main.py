import os
import json
import base64
import asyncio
import traceback
from pathlib import Path
from typing import Optional
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import edge_tts

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

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "message": "Sumati backend is running",
        "model": GROQ_MODEL,
        "api_key_configured": bool(GROQ_API_KEY)
    }

@app.post("/check")
async def check_text(request: TextCheckRequest):
    system_prompt = (
        "You are a cybersecurity expert analyzing messages to protect elderly users in India. "
        "Analyze the user's text and determine if it is a scam, phishing, or safe. "
        "You must respond strictly in valid JSON format with exactly two keys: "
        '1. "verdict": A short, simple 1-2 sentence explanation in English. '
        '2. "color": Use "red" (High Risk/Scam), "amber" (Suspicious/Unverified Links), or "green" (Seems Safe). '
        "Do not include any other text outside the JSON object."
    )
    
    max_tokens = 400 if "gpt-oss" in GROQ_MODEL else 100
    
    try:
        response = await client.chat.completions.create(
            model=GROQ_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": request.text}
            ],
            temperature=0.0,
            max_tokens=max_tokens,
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
        
        if result.get("color") not in ["red", "amber", "green"]:
            result["color"] = "amber"
            
        return result
        
    except Exception as e:
        print(f"Groq Checker Error: {type(e).__name__}: {e}")
        traceback.print_exc()
        return {
            "verdict": "Could not analyze the text at this moment. Please remain cautious.",
            "color": "amber"
        }

def select_voice(text: str, requested_voice: Optional[str] = None) -> str:
    if requested_voice:
        return requested_voice
    # Check for Devanagari script (Hindi/Marathi)
    if any('\u0900' <= char <= '\u097F' for char in text):
        return "hi-IN-MadhurNeural"
    return "en-IN-PrabhatNeural"

async def generate_speech_audio(text: str, voice: Optional[str] = None) -> bytes:
    selected = select_voice(text, voice)
    communicate = edge_tts.Communicate(text, selected)
    audio_data = b""
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            audio_data += chunk["data"]
    return audio_data

@app.get("/tts")
async def tts_audio_endpoint(text: str, voice: Optional[str] = None):
    try:
        audio = await generate_speech_audio(text, voice)
        return Response(content=audio, media_type="audio/mpeg")
    except Exception as e:
        print(f"TTS endpoint error: {e}")
        return Response(status_code=500, content=b"")

async def run_chat_session(websocket: WebSocket, persona: str, initial_message: str):
    await websocket.accept()
    
    system_prompt = (
        "You are an AI managing an interactive scam simulation for elderly users in India. "
        f"Your role: {persona}. "
        "Your goal: Pressure and deceive the user into complying, while staying in character. "
        "Rules: "
        "- Keep replies short (1-2 sentences). "
        "- If the user speaks Hindi or Marathi, reply in that language. "
        "- You MUST respond ONLY in valid JSON format with this exact structure: "
        "{"
        '  "reply": "Your message as the scammer (keep it short, 1-2 sentences)", '
        '  "suggestions": ["4 short suggested replies for the user. Include 2 defensive/suspicious replies and 1 compliant/gullible reply so user can test both paths."], '
        '  "status": "ongoing", "compromised", or "deflected", '
        '  "evaluation": "If compromised or deflected, provide a 1-2 sentence debrief explaining why they failed or succeeded. If ongoing, set to null." '
        "}"
        "\nRules for status: "
        "- 'ongoing': The user is asking questions or chatting normally."
        "- 'compromised': The user agrees to pay, shares OTP/PIN, clicks an unverified link, or complies with the scam. The simulation ends."
        "- 'deflected': The user strongly refuses, hangs up, threatens to call police/official bank, or verifies independently. The simulation ends."
    )
    
    initial_audio_b64 = None
    try:
        audio_bytes = await generate_speech_audio(initial_message)
        initial_audio_b64 = base64.b64encode(audio_bytes).decode('utf-8')
    except Exception as e:
        print(f"Initial Edge-TTS generation error: {e}")

    # Keep conversation history clean for LLM (NO audio_b64, saving tokens!)
    llm_initial_payload = {
        "reply": initial_message,
        "suggestions": ["Who is this?", "I need to verify this first.", "Okay, how do I pay?"],
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
    await websocket.send_text(json.dumps(client_initial_payload))
    max_tokens = 500 if "gpt-oss" in GROQ_MODEL else 350
    
    try:
        while True:
            user_text = await websocket.receive_text()
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
                
                # Append clean text-only turn to LLM history (ZERO wasted audio tokens!)
                llm_reply = {
                    "reply": reply_text,
                    "suggestions": suggestions,
                    "status": status,
                    "evaluation": evaluation
                }
                conversation.append({"role": "assistant", "content": json.dumps(llm_reply)})
                
                # Generate audio for the client
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
                await websocket.send_text(json.dumps(client_reply))
                
            except Exception as e:
                print(f"Groq Chat Completion Error: {type(e).__name__}: {e}")
                traceback.print_exc()
                error_payload = {
                    "reply": "Connection error. Please try again.",
                    "suggestions": ["Retry"],
                    "status": "ongoing",
                    "evaluation": None
                }
                await websocket.send_text(json.dumps(error_payload))
                
    except WebSocketDisconnect:
        print("Client disconnected from chat simulation")

@app.websocket("/ws/chat")
async def websocket_chat_query_endpoint(
    websocket: WebSocket,
    persona: str = "a scammer attempting fraud",
    initial_message: str = "Hello. Please respond urgently."
):
    await run_chat_session(websocket, persona, initial_message)

@app.websocket("/ws/chat/{scenario_id}")
async def websocket_chat_path_endpoint(
    websocket: WebSocket,
    scenario_id: str,
    persona: Optional[str] = None,
    initial_message: Optional[str] = None
):
    # If not supplied as query params, create dynamic defaults based on scenario_id
    if not persona:
        cleaned_name = scenario_id.replace("_", " ").title()
        persona = f"a scammer in a '{cleaned_name}' fraud attempt"
    if not initial_message:
        initial_message = f"Urgent notice regarding your {scenario_id.replace('_', ' ')}. Action required immediately."
    await run_chat_session(websocket, persona, initial_message)
