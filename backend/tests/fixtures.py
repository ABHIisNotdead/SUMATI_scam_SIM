"""Reusable test fixtures and canned responses for SUMATI backend tests."""

CANNED_DIGITAL_ARREST_TURN1 = {
    "reply": "Officer Sharma speaking. A formal non-bailable arrest warrant has just been issued against you by the Cyber Crime Branch. Check your screen immediately.",
    "suggestions": ["Show me the warrant.", "I am calling my lawyer.", "I have done nothing wrong."],
    "status": "ongoing",
    "evaluation": None,
    "artifact": {
        "type": "court_notice",
        "sender": "DELHI-POLICE",
        "title": "Arrest Warrant Issued",
        "body": "Non-bailable warrant #CBI-2024-9981 issued under Section 120B/420 IPC for money laundering.",
        "action_label": "View Warrant"
    }
}

CANNED_BANK_KYC_TURN1 = {
    "reply": "I have just dispatched a 6-digit verification code to your registered mobile number. Please read it to me now to avoid account blocking.",
    "suggestions": ["I received OTP 482910.", "Why do you need my OTP?", "I will not share OTP over the phone."],
    "status": "ongoing",
    "evaluation": None,
    "artifact": {
        "type": "otp",
        "sender": "AX-SBIBNK",
        "title": "SBI KYC Verification Code",
        "body": "482910 is your secret OTP for KYC verification. Valid for 10 mins. Do not share with anyone.",
        "action_label": "Copy OTP"
    }
}

CANNED_ELECTRICITY_TURN1 = {
    "reply": "Urgent notice: Power cutoff scheduled tonight 9:30 PM for unpaid bill. Pay immediately via this link.",
    "suggestions": ["How much is due?", "I will pay tomorrow.", "Where do I pay?"],
    "status": "ongoing",
    "evaluation": None,
    "artifact": {
        "type": "cutoff_link",
        "sender": "VM-ELEC-PAY",
        "title": "Electricity Cutoff Notice",
        "body": "Urgent: Power cutoff scheduled tonight 9:30 PM for unpaid bill ₹1,450. Pay immediately at http://bijli-pay.xyz/m",
        "action_label": "Pay Now"
    }
}

CANNED_DEBRIEF_SUCCESS_LLM = {
    "headline": "Well done! You successfully identified and defused the scam.",
    "tactics_explanation": "Real scammers exploit fear of legal prosecution and respect for law enforcement. They invent a fake crime and enforce 'digital arrest' over video calls, ordering victims to stay on camera and transfer funds to a fake verification account. In reality, Indian law has no concept of 'digital arrest'.",
    "dos": [
        "Immediately hang up the call — Indian law does not recognize 'digital arrest'.",
        "Call 1930 National Cyber Crime Helpline or visit your local police station.",
        "Inform a trusted family member or neighbor immediately."
    ],
    "donts": [
        "Never transfer money to any 'police verification' or 'escrow' bank account.",
        "Never join Skype or WhatsApp video calls with alleged police officers.",
        "Never disclose your Aadhaar number, banking credentials, or OTPs."
    ],
    "audio_script": "Well done! You defended against this scam. Real scammers use fake police badges and fabricated arrest warrants to create panic. Remember, real law enforcement officers will never place you under digital arrest or demand online fund transfers. Always hang up and verify with 1930."
}

CANNED_DEBRIEF_COMPROMISED_LLM = {
    "headline": "Be careful! In a real call, following these steps could cost you money.",
    "tactics_explanation": "Fraudsters impersonate bank managers and manufacture intense urgency around account blocking. They convince victims that reading out an OTP is a routine verification step.",
    "dos": [
        "Hang up immediately and visit your branch in person.",
        "Call 1930 Cyber Helpline if details were accidentally shared.",
        "Carefully read SMS messages stating 'Do not share OTP'."
    ],
    "donts": [
        "Never share OTPs, PINs, or CVVs over the phone.",
        "Never download remote screen-sharing tools like AnyDesk.",
        "Never trust caller IDs claiming to be bank headquarters."
    ],
    "audio_script": "Be careful! In a real scenario, complying with this bank call would have compromised your funds. Remember, banks never call to ask for OTPs or PINs."
}
