import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime
from typing import Optional, List, Dict, Any

DB_DIR = os.getenv("SUMATI_DB_DIR", os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data"))
DB_PATH = os.path.join(DB_DIR, "sumati.db")

@contextmanager
def get_db():
    os.makedirs(DB_DIR, exist_ok=True)
    # 10s timeout prevents immediate 'database is locked' errors under concurrent load
    conn = sqlite3.connect(DB_PATH, timeout=10.0, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    # Enable WAL mode for high concurrent read/write throughput
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA busy_timeout = 5000;")
    try:
        yield conn
    finally:
        conn.close()

def init_db():
    with get_db() as conn:
        cursor = conn.cursor()
        
        # 1. Users table (senior & family)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            phone_number TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            role TEXT DEFAULT 'senior',
            pin TEXT DEFAULT '1234',
            safety_score INTEGER DEFAULT 100,
            total_drills INTEGER DEFAULT 0,
            avoided_drills INTEGER DEFAULT 0,
            last_active TEXT,
            created_at TEXT
        )
        """)
        
        # 2. Scam Reports table (user-reported scams & scammer intelligence)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS scam_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_phone TEXT,
            scammer_phone TEXT,
            scammer_upi TEXT,
            scammer_link TEXT,
            scam_amount TEXT,
            story TEXT,
            ai_analysis TEXT,
            language TEXT DEFAULT 'en',
            status TEXT DEFAULT 'new',
            created_at TEXT
        )
        """)
        
        # 3. Family Connections table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS family_connections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            senior_phone TEXT NOT NULL,
            family_phone TEXT,
            family_name TEXT,
            created_at TEXT
        )
        """)
        
        # 4. Drill Activity table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS drill_activity (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_phone TEXT NOT NULL,
            scenario_title TEXT,
            channel TEXT,
            status TEXT,
            timestamp TEXT
        )
        """)
        conn.commit()

# ── User Sync & Lookup ──────────────────────────────────────────────
def sync_user(phone: str, name: str, pin: str = "1234", safety_score: int = 100, total_drills: int = 0, avoided_drills: int = 0) -> Dict[str, Any]:
    with get_db() as conn:
        cursor = conn.cursor()
        now = datetime.utcnow().isoformat()
        
        cursor.execute("SELECT * FROM users WHERE phone_number = ?", (phone,))
        existing = cursor.fetchone()
        
        if existing:
            effective_pin = pin if pin and pin.strip() else existing["pin"]
            cursor.execute("""
                UPDATE users 
                SET name = ?, pin = ?, safety_score = ?, total_drills = ?, avoided_drills = ?, last_active = ?
                WHERE phone_number = ?
            """, (name, effective_pin, safety_score, total_drills, avoided_drills, now, phone))
        else:
            cursor.execute("""
                INSERT INTO users (phone_number, name, role, pin, safety_score, total_drills, avoided_drills, last_active, created_at)
                VALUES (?, ?, 'senior', ?, ?, ?, ?, ?, ?)
            """, (phone, name, pin, safety_score, total_drills, avoided_drills, now, now))
            
        conn.commit()
        
        cursor.execute("SELECT * FROM users WHERE phone_number = ?", (phone,))
        row = cursor.fetchone()
        return dict(row) if row else {}

def get_user_by_phone(phone: str) -> Optional[Dict[str, Any]]:
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE phone_number = ?", (phone,))
        row = cursor.fetchone()
        return dict(row) if row else None

# ── Family Authorization & Status ──────────────────────────────────
def authorize_family_connect(senior_phone: str, pin: str, family_phone: Optional[str] = None, family_name: Optional[str] = None) -> (bool, str, Optional[Dict[str, Any]]):
    senior = get_user_by_phone(senior_phone)
    if not senior:
        return False, "Senior with this phone number not found. Make sure the senior has saved their profile in Sumati.", None
    
    if str(senior.get("pin", "")).strip() != str(pin).strip():
        return False, "Incorrect 4-digit PIN. Please verify the PIN shown on your senior's Sumati screen.", None
    
    with get_db() as conn:
        cursor = conn.cursor()
        now = datetime.utcnow().isoformat()
        
        cursor.execute("""
            INSERT INTO family_connections (senior_phone, family_phone, family_name, created_at)
            VALUES (?, ?, ?, ?)
        """, (senior_phone, family_phone or "", family_name or "Family Member", now))
        conn.commit()
    
    return True, "Authorized successfully", senior

def get_senior_dashboard_data(senior_phone: str) -> Optional[Dict[str, Any]]:
    senior = get_user_by_phone(senior_phone)
    if not senior:
        return None
    
    with get_db() as conn:
        cursor = conn.cursor()
        
        # Fetch recent drills
        cursor.execute("""
            SELECT scenario_title, channel, status, timestamp
            FROM drill_activity
            WHERE user_phone = ?
            ORDER BY id DESC LIMIT 20
        """, (senior_phone,))
        drills = [dict(r) for r in cursor.fetchall()]
        
        # Fetch recent scam reports filed by senior
        cursor.execute("""
            SELECT id, scammer_phone, scammer_upi, scammer_link, scam_amount, story, created_at
            FROM scam_reports
            WHERE user_phone = ?
            ORDER BY id DESC LIMIT 10
        """, (senior_phone,))
        reports = [dict(r) for r in cursor.fetchall()]
        
        return {
            "senior": senior,
            "drills": drills,
            "reports": reports
        }

# ── Scam Reports Recording & Feed ───────────────────────────────────
def insert_scam_report(user_phone: Optional[str], scammer_phone: Optional[str], scammer_upi: Optional[str],
                       scammer_link: Optional[str], scam_amount: Optional[str], story: str,
                       ai_analysis: str, language: str = 'en') -> int:
    with get_db() as conn:
        cursor = conn.cursor()
        now = datetime.utcnow().isoformat()
        
        cursor.execute("""
            INSERT INTO scam_reports (user_phone, scammer_phone, scammer_upi, scammer_link, scam_amount, story, ai_analysis, language, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (user_phone or "", scammer_phone or "", scammer_upi or "", scammer_link or "", scam_amount or "", story, ai_analysis, language, now))
        
        report_id = cursor.lastrowid
        conn.commit()
        return report_id

def list_scam_reports(limit: int = 50) -> Dict[str, Any]:
    with get_db() as conn:
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT * FROM scam_reports
            ORDER BY id DESC LIMIT ?
        """, (limit,))
        rows = [dict(r) for r in cursor.fetchall()]
        
        cursor.execute("SELECT COUNT(*) as count FROM scam_reports")
        total_count = cursor.fetchone()["count"]
        
        cursor.execute("SELECT COUNT(DISTINCT scammer_phone) as count FROM scam_reports WHERE scammer_phone != ''")
        distinct_phones = cursor.fetchone()["count"]
        
        cursor.execute("SELECT COUNT(DISTINCT scammer_upi) as count FROM scam_reports WHERE scammer_upi != ''")
        distinct_upis = cursor.fetchone()["count"]
        
        return {
            "total_reports": total_count,
            "distinct_scammer_phones": distinct_phones,
            "distinct_scammer_upis": distinct_upis,
            "reports": rows
        }

# ── Record Drill Activity ───────────────────────────────────────────
def record_drill(user_phone: str, scenario_title: str, channel: str, status: str):
    with get_db() as conn:
        cursor = conn.cursor()
        now = datetime.utcnow().isoformat()
        
        cursor.execute("""
            INSERT INTO drill_activity (user_phone, scenario_title, channel, status, timestamp)
            VALUES (?, ?, ?, ?, ?)
        """, (user_phone, scenario_title, channel, status, now))
        
        cursor.execute("""
            SELECT COUNT(*) as total, 
                   SUM(CASE WHEN status = 'deflected' OR status = 'avoided' THEN 1 ELSE 0 END) as avoided
            FROM drill_activity WHERE user_phone = ?
        """, (user_phone,))
        stat = cursor.fetchone()
        total = stat["total"] or 0
        avoided = stat["avoided"] or 0
        score = int((avoided / total) * 100) if total > 0 else 100
        
        cursor.execute("""
            UPDATE users 
            SET total_drills = ?, avoided_drills = ?, safety_score = ?, last_active = ?
            WHERE phone_number = ?
        """, (total, avoided, score, now, user_phone))
        
        conn.commit()
