import sys
import os
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

"""
analyze_complaint.py  ─  Seva Setu: Grievance Intelligence System
══════════════════════════════════════════════════════════════════
Fully ISOLATED, per-department analysis engine.

Each department owns:
  • Its own priority score function        (0 – 100)
  • Its own High / Medium / Low thresholds (no shared scale)
  • Its own urgency detection              (via urgency_rules.py)
  • Its own human-readable explanation

Departments never compare scores with each other.
A score of 70 in Police ≠ a score of 70 in Municipal Services.
"""

import os
import joblib
from ai.urgency_rules import get_department_urgency

# ══════════════════════════════════════════════════════════════
# SECTION 1 ─ CATEGORY → DEPARTMENT MAPPING
# ══════════════════════════════════════════════════════════════

CATEGORY_TO_DEPARTMENT = {
    "Electricity":    "Power Department",
    "Water Supply":   "Water Department",
    "Sanitation":     "Municipal Services",
    "Roads":          "Municipal Services",
    "Health":         "Health Department",
    "Corruption":     "Vigilance Department",
    "Street Lighting":"Municipal Services",
    "Drainage":       "Municipal Services",
    "Crime":          "Police Department",
}

# ══════════════════════════════════════════════════════════════
# SECTION 2 ─ KEYWORD OVERRIDE  (Crime detection)
# ══════════════════════════════════════════════════════════════

_CRIME_KEYWORDS = [
    "kidnap", "kidnapped", "missing", "murder", "theft",
    "stolen", "robbery", "attack", "assault", "rape",
    "crime", "police", "fight", "violence", "abduct",
    "terror", "shooting", "stabbing", "loot", "dacoity"
]

def _detect_crime_category(text: str):
    t = text.lower()
    for kw in _CRIME_KEYWORDS:
        if kw in t:
            return "Crime"
    return None

# ══════════════════════════════════════════════════════════════
# SECTION 3 ─ ML MODEL LOADER
# ══════════════════════════════════════════════════════════════

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

_ml_loaded = False
category_model = category_vectorizer = None
urgency_model  = urgency_vectorizer  = None
delay_model    = None
category_encoder = department_encoder = urgency_encoder = None

try:
    category_model      = joblib.load(os.path.join(BASE_DIR, "category_model.pkl"))
    category_vectorizer = joblib.load(os.path.join(BASE_DIR, "category_vectorizer.pkl"))
    urgency_model       = joblib.load(os.path.join(BASE_DIR, "urgency_model.pkl"))
    urgency_vectorizer  = joblib.load(os.path.join(BASE_DIR, "urgency_vectorizer.pkl"))
    delay_model         = joblib.load(os.path.join(BASE_DIR, "delay_risk_model.pkl"))
    category_encoder    = joblib.load(os.path.join(BASE_DIR, "category_encoder.pkl"))
    department_encoder  = joblib.load(os.path.join(BASE_DIR, "department_encoder.pkl"))
    urgency_encoder     = joblib.load(os.path.join(BASE_DIR, "urgency_encoder.pkl"))
    _ml_loaded = True
    print("✅ ML Models loaded successfully")
except Exception as e:
    print(f"⚠️  ML Models not loaded: {e}")


# ══════════════════════════════════════════════════════════════
# SECTION 4 ─ HELPER
# ══════════════════════════════════════════════════════════════

def _contains(text_lower: str, keywords: list) -> bool:
    return any(kw in text_lower for kw in keywords)


# ══════════════════════════════════════════════════════════════
# SECTION 5 ─ POLICE DEPARTMENT ENGINE
# ══════════════════════════════════════════════════════════════
#
# Scale meaning  (Police-internal only):
#   90–100 → physical harm / death / kidnapping ─ MUST act within minutes
#   70–89  → active threat / dangerous crime     ─ respond within 1 hour
#   50–69  → property crime / harassment         ─ respond within 4 hours
#   0–49   → minor / historical complaint        ─ standard queue
#
# Thresholds: High ≥ 80 | Medium ≥ 55 | Low < 55

_POLICE_SCORE_TIERS = [
    (100, ["rape", "murder", "kidnap", "abduct", "missing child",
           "terror", "bomb", "hostage", "shooting", "stabbing",
           "death threat", "kill", "killing", "murder threat"]),
    (92,  ["attack", "assault", "bleeding", "unconscious",
           "life threat", "life threatening", "acid attack"]),
    (80,  ["violence", "riot", "mob attack", "gang", "armed"]),
    (70,  ["robbery", "loot", "burglary", "dacoity"]),
    (58,  ["theft", "stolen", "pickpocket", "snatching",
           "eve teasing", "molestation", "stalking"]),
    (45,  ["harassment", "nuisance", "disturbance", "noise",
           "illegal", "unauthorised"]),
]

def _police_score(text: str) -> int:
    t = text.lower()
    for score, keywords in _POLICE_SCORE_TIERS:
        if _contains(t, keywords):
            return score
    return 30   # default: general complaint with no match

def _police_label(score: int) -> str:
    if score >= 95: return "Critical"
    if score >= 80: return "High"
    if score >= 55: return "Medium"
    return "Low"

def _police_explanation(score: int, text: str, urgency: str) -> str:
    t = text.lower()
    if score == 100:
        return ("Absolute priority: this complaint involves a severe crime against a person "
                "(murder/rape/kidnapping/terror) requiring immediate police intervention.")
    if score >= 90:
        return ("Critical threat detected: an active attack or life-threatening situation is reported. "
                "Immediate dispatch required.")
    if score >= 80:
        return ("High priority: violent crime or mob activity reported. Officer response needed within 1 hour.")
    if score >= 70:
        return ("High priority: property crime with potential for escalation (robbery/burglary). "
                "Respond within 2 hours.")
    if score >= 55:
        return ("Medium priority: theft, snatching, or harassment reported. "
                "Assign officer and follow up within 4 hours.")
    return ("Low priority: general complaint or disturbance. Schedule as per standard queue.")


# ══════════════════════════════════════════════════════════════
# SECTION 6 ─ POWER / ELECTRICITY DEPARTMENT ENGINE
# ══════════════════════════════════════════════════════════════
#
# Scale meaning  (Power-internal only):
#   90–100 → electrical hazard (fire/shock) or 3+ day outage ─ emergency
#   70–89  → 1-2 day outage or transformer failure           ─ same day
#   50–69  → hours-long outage affecting locality            ─ within 12 hrs
#   0–49   → voltage fluctuation / single house / minor      ─ standard
#
# Thresholds: High ≥ 85 | Medium ≥ 55 | Low < 55

import re as _re

_HINDI_DAY_NUMS = {
    "ek": 1, "do": 2, "teen": 3, "char": 4, "paanch": 5,
    "chhe": 6, "saat": 7, "aath": 8, "nau": 9, "das": 10
}

def _extract_days_inline(text):
    t = text.lower()
    m = _re.search(r'(\d+)\s*(day|days)', t)
    if m:
        return int(m.group(1))
    # Hinglish number words
    for word, num in _HINDI_DAY_NUMS.items():
        if _re.search(rf'\b{word}\s*(din|day)\b', t):
            return num
    return None

def _extract_hours_inline(text):
    m = _re.search(r'(\d+)\s*(hour|hours|hr|hrs)', text.lower())
    return int(m.group(1)) if m else None

_POWER_HAZARD = [
    "fire", "sparking", "spark", "short circuit", "exposed wire",
    "live wire", "electric shock", "pole fallen", "transformer blast",
    "burning smell", "smoke from wire", "aag", "spark aa raha",
    "taar toot gaya", "current aa raha", "bijli se jal gaya"
]

_POWER_OUTAGE = [
    "no electricity", "no power", "power cut", "blackout",
    "bijli nahi", "bijli band", "koi bijli nahi", "andhera"
]

_POWER_TRANSFORMER = [
    "burnt transformer", "transformer failed", "transformer down",
    "transformer kharab", "transformer jal gaya"
]

_POWER_FLUCTUATION = [
    "low voltage", "fluctuation", "voltage problem",
    "frequent cut", "voltage kam", "halki bijli", "baar baar cut"
]

def _power_score(text: str) -> int:
    t = text.lower()

    if _contains(t, _POWER_HAZARD):
        return 100   # Physical danger always tops

    days  = _extract_days_inline(t)
    hours = _extract_hours_inline(t)

    if _contains(t, _POWER_OUTAGE):
        if days is not None:
            if days >= 3:  return 98
            if days >= 1:  return 80
        if hours is not None:
            if hours >= 12: return 75
            if hours >= 4:  return 60
            return 55
        return 70   # "no electricity" without duration

    if _contains(t, _POWER_TRANSFORMER):
        return 85

    # Duration signals without explicit outage word
    if days is not None:
        if days >= 3:  return 92
        if days >= 1:  return 75
    if hours is not None:
        if hours >= 12: return 65
        if hours >= 4:  return 52

    if "week" in t or "weeks" in t:
        return 97

    if _contains(t, _POWER_FLUCTUATION):
        return 45

    return 35

def _power_label(score: int) -> str:
    if score >= 95: return "Critical"
    if score >= 85: return "High"
    if score >= 55: return "Medium"
    return "Low"

def _power_explanation(score: int, text: str, urgency: str) -> str:
    t = text.lower()
    if _contains(t, _POWER_HAZARD):
        return ("DANGER: An electrical hazard (fire/sparking/exposed wire/shock) is reported. "
                "This is a public safety emergency requiring immediate field response.")
    days = _extract_days_inline(t)
    if days and days >= 3:
        return (f"High priority: Complete power outage for {days} day(s). "
                "Extended outage impacts health, safety, and livelihoods. Urgent restoration needed.")
    if days:
        return (f"High priority: Power outage reported for {days} day(s). Assign field team today.")
    hours = _extract_hours_inline(t)
    if hours and hours >= 12:
        return (f"Medium-High priority: {hours}-hour outage. Locality or area affected.")
    if score >= 85:
        return "High priority: Significant power issue (transformer failure or prolonged outage) reported."
    if score >= 55:
        return "Medium priority: Power fluctuation or hours-long outage. Schedule restoration within the day."
    return "Low priority: Minor power issue (single house, brief fluctuation). Address in standard queue."


# ══════════════════════════════════════════════════════════════
# SECTION 7 ─ WATER DEPARTMENT ENGINE
# ══════════════════════════════════════════════════════════════
#
# Scale meaning  (Water-internal only):
#   90–100 → contamination / disease risk / 5+ days no water ─ crisis
#   70–89  → 2-4 days no water / pipe burst                  ─ urgent
#   50–69  → leakage / pressure issue / 1-day shortage        ─ same day
#   0–49   → billing / odour / minor                          ─ standard
#
# Thresholds: High ≥ 80 | Medium ≥ 50 | Low < 50

_WATER_CONTAMINATION = [
    "contaminated", "contamination", "poisoned", "poisoning", "dirty water", "black water", "sewage in water",
    "worms", "disease", "cholera", "typhoid", "diarrhea",
    "vomiting", "poisoned water", "gandha paani", "kala paani",
    "keede paani mein", "bimari", "ulti"
]

_WATER_NO_SUPPLY = [
    "no water", "water shortage", "water supply stopped",
    "water cut", "no water since", "water not coming",
    "paani nahi", "paani band", "aapur nahi"
]

_WATER_PIPE = [
    "pipeline burst", "pipe burst", "flood from pipe",
    "pipeline phati", "paani beh raha"
]

_WATER_LEAKAGE = [
    "leakage", "pipe leak", "dripping", "water leaking",
    "irregular supply", "low pressure", "leak ho raha",
    "pressure kam", "kabhi kabhi aata"
]

def _water_score(text: str) -> int:
    t = text.lower()

    if _contains(t, _WATER_CONTAMINATION):
        return 100   # disease risk = top priority

    if _contains(t, _WATER_PIPE):
        return 90

    days = _extract_days_inline(t)
    hours = _extract_hours_inline(t)

    if _contains(t, _WATER_NO_SUPPLY):
        if days is not None:
            if days >= 5:  return 95
            if days >= 2:  return 82
            return 70      # 1 day or fewer
        if hours is not None and hours >= 24:
            return 75
        return 70

    # Duration-only signals
    if days is not None:
        if days >= 5:  return 93
        if days >= 2:  return 78

    if "week" in t or "weeks" in t:
        return 95

    if _contains(t, _WATER_LEAKAGE):
        return 52

    return 30

def _water_label(score: int) -> str:
    if score >= 95: return "Critical"
    if score >= 80: return "High"
    if score >= 50: return "Medium"
    return "Low"

def _water_explanation(score: int, text: str, urgency: str) -> str:
    t = text.lower()
    if _contains(t, _WATER_CONTAMINATION):
        return ("CRITICAL: Contaminated water supply reported, posing a serious public health risk. "
                "Immediate testing, isolation, and alternative supply required.")
    if _contains(t, _WATER_PIPE):
        return ("High priority: Pipeline burst causing flooding or total supply failure. "
                "Emergency repair team needed immediately.")
    days = _extract_days_inline(t)
    if days and days >= 5:
        return (f"Critical shortage: No water supply for {days} days — a humanitarian concern. "
                "Emergency tanker deployment and pipe repair required today.")
    if days and days >= 2:
        return (f"High priority: Water supply disruption for {days} days. Residents are severely affected.")
    if score >= 80:
        return "High priority: Significant water supply failure reported. Urgent restoration needed."
    if score >= 50:
        return "Medium priority: Water leakage or pressure issue. Schedule repair within 24 hours."
    return "Low priority: Minor water complaint. Address during routine maintenance."


# ══════════════════════════════════════════════════════════════
# SECTION 8 ─ HEALTH DEPARTMENT ENGINE
# ══════════════════════════════════════════════════════════════
#
# Scale meaning  (Health-internal only):
#   90–100 → life at immediate risk (cardiac, no oxygen, no ICU)
#   70–89  → acute illness, no doctor/medicine in emergency
#   50–69  → service delay, hygiene, non-critical medicine gap
#   0–49   → billing, registration, general feedback
#
# Thresholds: High ≥ 80 | Medium ≥ 50 | Low < 50

_HEALTH_LIFE_CRITICAL = [
    "heart attack", "cardiac arrest", "stroke", "unconscious",
    "not breathing", "no oxygen", "oxygen finished", "icu full",
    "coma", "critical condition", "no blood", "blood shortage",
    "ambulance not coming", "emergency ward closed",
    "massive bleeding", "seizure", "fit", "convulsion",
    "heart attack aaya", "sans nahi", "oxygen nahi",
    "behosha", "khoon nahi", "ambulance nahi"
]

_HEALTH_ACUTE = [
    "doctor not available", "no doctor", "no nurse",
    "medicine not available", "no medicine", "injection missing",
    "high fever", "dengue", "malaria", "typhoid",
    "child sick", "baby sick", "infant", "newborn", "delivery",
    "pregnant", "labour pain", "fracture", "broken bone",
    "doctor nahi", "dawai nahi", "bukhar teen din",
    "bachcha beemar", "prasav", "haddi tooti",
    # added: absenteeism / unavailability patterns
    "doctor absent", "doctor on leave", "no staff", "ward empty",
    "nobody in emergency", "no doctor on duty", "duty doctor missing",
    "doctor nahi aaya", "doctor gayab"
]

_HEALTH_SERVICE = [
    "long wait", "waiting time", "queue", "delay in treatment",
    "medicine delay", "test pending", "report not given",
    "dirty hospital", "toilet not clean", "lamba intezaar",
    "dawai der se", "report nahi", "hospital ganda"
]

def _health_score(text: str) -> int:
    t = text.lower()

    if _contains(t, _HEALTH_LIFE_CRITICAL):
        return 100
    if _contains(t, _HEALTH_ACUTE):
        return 82
    if _contains(t, _HEALTH_SERVICE):
        return 55

    return 30

def _health_label(score: int) -> str:
    if score >= 90: return "Critical"
    if score >= 80: return "High"
    if score >= 50: return "Medium"
    return "Low"

def _health_explanation(score: int, text: str, urgency: str) -> str:
    if score == 100:
        return ("MEDICAL EMERGENCY: A life-threatening condition is reported. "
                "This requires immediate emergency response — dispatch ambulance / alert hospital.")
    if score >= 80:
        return ("High priority: Acute illness or unavailability of critical medical staff/medicine. "
                "Escalate to hospital authority and duty doctor immediately.")
    if score >= 50:
        return ("Medium priority: Service delay or hygiene issue at a healthcare facility. "
                "Follow up within the day and escalate to facility head.")
    return "Low priority: General health service feedback. Address within 3 working days."


# ══════════════════════════════════════════════════════════════
# SECTION 9 ─ MUNICIPAL SERVICES ENGINE
#   (Roads, Drainage, Sanitation, Street Lighting, Garbage)
# ══════════════════════════════════════════════════════════════
#
# Scale meaning  (Municipal-internal only):
#   85–100 → structural collapse / sewer overflow / major flood
#   65–84  → accident-risk hazard / severe garbage / waterlogging
#   45–64  → pothole / broken light / blocked drain (reported once)
#   0–44   → aesthetic / cosmetic / minor
#
# Thresholds: High ≥ 75 | Medium ≥ 48 | Low < 48

_MUNI_COLLAPSE = [
    "collapsed", "road collapse", "bridge broken", "sinkhole",
    "sewer overflow", "sewage overflow", "drain burst",
    "flooding street", "landslide", "sadak dhaansi",
    "nala phata", "nali phati", "baarh"
]

_MUNI_HAZARD = [
    "open manhole", "deep pothole", "accident", "dead animal",
    "no garbage for weeks", "garbage piling", "waterlogging",
    "stray animals biting", "bada gadha", "kachra bahut zyada",
    "paani bhar gaya", "dhaka khula", "manhole open"
]

_MUNI_ROUTINE = [
    "pothole", "broken road", "streetlight not working",
    "no street light", "street light not working", "street light broken",
    "streetlight broken", "light not working", "light broken",
    "batti nahi jal rahi", "batti band",
    "garbage", "drainage blocked",
    "dirty area", "overgrown", "gadha", "tooti sadak",
    "batti nahi", "kachra", "nali jam", "nali band"
]

def _municipal_score(text: str) -> int:
    t = text.lower()

    if _contains(t, _MUNI_COLLAPSE):
        return 95

    days = _extract_days_inline(t)

    if _contains(t, _MUNI_HAZARD):
        if days and days >= 7:
            return 85
        return 75

    if _contains(t, _MUNI_ROUTINE):
        if days and days >= 14:   return 72   # chronic = escalate
        if days and days >= 7:    return 62
        return 50   # single report → always at least Medium

    if days and days >= 14:
        return 65   # Any 2-week complaint in municipal = Medium-High

    return 35

def _municipal_label(score: int) -> str:
    if score >= 90: return "Critical"
    if score >= 75: return "High"
    if score >= 48: return "Medium"
    return "Low"

def _municipal_explanation(score: int, text: str, urgency: str) -> str:
    t = text.lower()
    if _contains(t, _MUNI_COLLAPSE):
        return ("URGENT: Structural collapse, sewer overflow, or major flooding reported. "
                "Public safety at risk — deploy emergency response team immediately.")
    if _contains(t, _MUNI_HAZARD):
        return ("High priority: Open manhole, large pothole, severe waterlogging, or garbage hazard. "
                "Poses accident/disease risk — address within 24 hours.")
    if score >= 48:
        return ("Medium priority: Routine infrastructure issue (pothole/streetlight/blocked drain). "
                "Schedule repair within 3 working days.")
    return "Low priority: Minor cosmetic or one-time civic issue. Address in standard maintenance cycle."


# ══════════════════════════════════════════════════════════════
# SECTION 10 ─ VIGILANCE DEPARTMENT ENGINE
#   (Corruption, Fraud, Bribery, Misuse of power)
# ══════════════════════════════════════════════════════════════
#
# Scale meaning  (Vigilance-internal only):
#   90–100 → bribe for essential services / extortion / active scam
#   70–89  → corruption, fraud, embezzlement
#   50–69  → favoritism, misuse of authority
#   0–49   → general grievance / suggestion
#
# Thresholds: High ≥ 80 | Medium ≥ 50 | Low < 50

_VIG_EXTORTION = [
    "bribe for hospital", "bribe for medicine", "bribe for ration",
    "bribe for job", "extortion", "threatening for money",
    "demanded money under threat", "scam", "ponzi scheme",
    "rishwat maang rahe", "paisa dene par hi",
    "paisa nahi toh nahi milega", "dhamki de raha paisa"
]

_VIG_CORRUPTION = [
    "bribe", "corruption", "fraud", "fake document", "forged",
    "illegal money", "black money", "misuse of funds",
    "government money stolen", "embezzlement", "rishwat",
    "bhrashtachar", "paisa khaya", "nakli kagaz", "farzi"
]

_VIG_MISCONDUCT = [
    "favoritism", "nepotism", "unfair", "bias", "discrimination",
    "not following rules", "misuse of power", "abuse of authority",
    "relatives", "own people", "family member appointed",
    "bhed bhaav", "apna aadmi", "niyam nahi mana",
    "taakat ka galat use", "rishtedar", "apne log"
]

def _vigilance_score(text: str) -> int:
    t = text.lower()

    if _contains(t, _VIG_EXTORTION):
        return 97
    if _contains(t, _VIG_CORRUPTION):
        return 82
    if _contains(t, _VIG_MISCONDUCT):
        return 58

    return 35

def _vigilance_label(score: int) -> str:
    if score >= 95: return "Critical"
    if score >= 80: return "High"
    if score >= 50: return "Medium"
    return "Low"

def _vigilance_explanation(score: int, text: str, urgency: str) -> str:
    t = text.lower()
    if _contains(t, _VIG_EXTORTION):
        return ("HIGH ALERT: Bribery/extortion is being actively demanded for essential services. "
                "Immediate covert action and evidence collection required.")
    if _contains(t, _VIG_CORRUPTION):
        return ("High priority: Corruption, fraud, or misuse of public funds reported. "
                "Open an inquiry and secure related documents within 24 hours.")
    if score >= 50:
        return ("Medium priority: Favoritism or misuse of authority reported. "
                "Investigate and respond within 3 working days.")
    return "Low priority: General administrative grievance. Process through standard channels."


# ══════════════════════════════════════════════════════════════
# SECTION 11 ─ DEPARTMENT REGISTRY
# ══════════════════════════════════════════════════════════════

_DEPT_ENGINES = {
    "Police Department": {
        "score_fn":    _police_score,
        "label_fn":    _police_label,
        "explain_fn":  _police_explanation,
    },
    "Power Department": {
        "score_fn":    _power_score,
        "label_fn":    _power_label,
        "explain_fn":  _power_explanation,
    },
    "Water Department": {
        "score_fn":    _water_score,
        "label_fn":    _water_label,
        "explain_fn":  _water_explanation,
    },
    "Health Department": {
        "score_fn":    _health_score,
        "label_fn":    _health_label,
        "explain_fn":  _health_explanation,
    },
    "Municipal Services": {
        "score_fn":    _municipal_score,
        "label_fn":    _municipal_label,
        "explain_fn":  _municipal_explanation,
    },
    "Vigilance Department": {
        "score_fn":    _vigilance_score,
        "label_fn":    _vigilance_label,
        "explain_fn":  _vigilance_explanation,
    },
}

# Generic fallback engine (unknown departments)
def _generic_score(text: str) -> int:
    t = text.lower()
    if any(kw in t for kw in ["emergency", "critical", "danger"]): return 80
    if any(kw in t for kw in ["urgent", "immediately", "asap"]):   return 65
    if any(kw in t for kw in ["problem", "issue", "not working"]): return 50
    return 35

def _generic_label(score: int) -> str:
    if score >= 70: return "High"
    if score >= 45: return "Medium"
    return "Low"

def _generic_explanation(score: int, text: str, urgency: str) -> str:
    return f"Complaint analysed with general scoring. Priority: {_generic_label(score)}."

_GENERIC_ENGINE = {
    "score_fn":   _generic_score,
    "label_fn":   _generic_label,
    "explain_fn": _generic_explanation,
}


# ══════════════════════════════════════════════════════════════
# SECTION 12 ─ DELAY RISK CALCULATOR
# ══════════════════════════════════════════════════════════════

def _compute_delay_risk(category: str, department: str, urgency: str) -> tuple:
    """
    Compute delay risk using ML model if available, else rule-based fallback.
    Returns (label: str, score: float)
    """
    if _ml_loaded and category_encoder and department_encoder and urgency_encoder:
        try:
            if (category   in category_encoder.classes_ and
                department  in department_encoder.classes_ and
                urgency     in urgency_encoder.classes_):

                features = [[
                    category_encoder.transform([category])[0],
                    department_encoder.transform([department])[0],
                    urgency_encoder.transform([urgency])[0],
                ]]
                label = delay_model.predict(features)[0]
                proba = delay_model.predict_proba(features)[0]
                score = float(proba[1]) if len(proba) > 1 else 0.5
                return label, round(score, 2)
        except Exception:
            pass

    # Rule-based fallback when ML unavailable or category not in encoder
    if urgency in ("Critical", "High"):
        return "High", 0.75
    if urgency == "Medium":
        return "Medium", 0.50
    return "Low", 0.25


# ══════════════════════════════════════════════════════════════
# SECTION 13 ─ MAIN PUBLIC FUNCTION
# ══════════════════════════════════════════════════════════════

def analyze_complaint(text: str, selected_department: str = None) -> dict:
    """
    Analyse a citizen complaint end-to-end using fully isolated
    department-specific engines.

    Args:
        text               : Raw complaint text (English / Hinglish)
        selected_department: Department chosen by the citizen in the app
                             (overrides ML category → department mapping)

    Returns a dict with:
        category, department, urgency, priority_score, priority_label,
        delay_risk_label, delay_risk_score, explanation
    """

    # ── Step 1: Category detection ────────────────────────────
    override_cat = _detect_crime_category(text)
    if override_cat:
        category = override_cat
    else:
        if _ml_loaded:
            try:
                vec = category_vectorizer.transform([text])
                category = category_model.predict(vec)[0]
            except Exception:
                category = "General"
        else:
            category = "General"

    # ── Step 2: Department resolution ────────────────────────
    mapped_dept = CATEGORY_TO_DEPARTMENT.get(category, "Municipal Services")
    department  = selected_department if selected_department else mapped_dept

    # ── Step 3: Department engine ─────────────────────────────
    engine = _DEPT_ENGINES.get(department, _GENERIC_ENGINE)

    # ── Step 4: Priority score & label (dept-isolated) ────────
    priority_score = engine["score_fn"](text)
    priority_label = engine["label_fn"](priority_score)

    # ── Step 5: Urgency (dept-isolated via urgency_rules.py) ──
    urgency = get_department_urgency(text, department)

    # ── Step 6: Cross-check — urgency must align with label ───
    # If urgency is Critical, the priority label MUST also be Critical.
    if urgency == "Critical":
        priority_label = "Critical"
        priority_score = max(priority_score, 97) # Ensure score is in Critical range
    elif urgency == "High" and priority_label in ("Medium", "Low"):
        priority_label = "High"
        priority_score = max(priority_score, 80)

    # ── Step 7: Human-readable explanation ────────────────────
    explanation = engine["explain_fn"](priority_score, text, urgency)

    # ── Step 8: Delay risk ────────────────────────────────────
    delay_label, delay_score = _compute_delay_risk(category, department, urgency)

    return {
        "category":         category,
        "department":       department,
        "urgency":          urgency,
        "priority_score":   int(priority_score),
        "priority_label":   priority_label,
        "delay_risk_label": delay_label,
        "delay_risk_score": delay_score,
        "explanation":      explanation,
    }


# ══════════════════════════════════════════════════════════════
# SECTION 14 ─ SELF-TEST
# ══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    tests = [
        # (text, dept, expected_label, expected_urgency)
        ("Rape case near the park",                    "Police Department",    "Critical", "Critical"),
        ("Mobile snatching on main road",              "Police Department",    "Medium",  "Medium"),
        ("Someone is giving me death threats",         "Police Department",    "Critical", "Critical"),
        ("He is threatening to kill my family",        "Police Department",    "Critical", "Critical"),
        ("No electricity for 4 days",                  "Power Department",     "Critical", "Critical"),
        ("Bijli nahi teen din se",                     "Power Department",     "Critical", "Critical"),
        ("Voltage fluctuation in evening",             "Power Department",     "Low",    "Medium"),
        ("Sparking transformer near school",           "Power Department",     "Critical", "Critical"),
        ("No water for 6 days",                        "Water Department",     "Critical", "Critical"),
        ("Contaminated water causing illness",         "Water Department",     "Critical", "Critical"),
        ("Water contamination in the colony",          "Water Department",     "Critical", "Critical"),
        ("Minor pipe dripping near tap",               "Water Department",     "Medium", "Medium"),
        ("Cardiac arrest, ICU full",                   "Health Department",    "Critical", "Critical"),
        ("Doctor absent on duty",                      "Health Department",    "High",   "High"),
        ("Long queue for OPD registration",            "Health Department",    "Medium", "Medium"),
        ("Road collapsed near colony",                 "Municipal Services",   "Critical", "Critical"),
        ("Open manhole at intersection",               "Municipal Services",   "High",   "High"),
        ("Streetlight broken for 2 days",              "Municipal Services",   "Medium", "Medium"),
        ("Bribe demanded for ration card issue",       "Vigilance Department", "Critical", "Critical"),
        ("Officer favoring his own relatives",         "Vigilance Department", "Medium", "Medium"),
    ]

    print("=" * 72)
    print("SEVA SETU ─ Isolated Department Engine Self-Test")
    print("=" * 72)
    passed = failed = 0
    for text, dept, exp_label, exp_urgency in tests:
        r = analyze_complaint(text, selected_department=dept)
        ok_label   = r["priority_label"] == exp_label
        ok_urgency = r["urgency"]        == exp_urgency
        ok = ok_label and ok_urgency
        status = "✅ PASS" if ok else "❌ FAIL"
        if ok: passed += 1
        else:  failed += 1
        print(f"\n{status}  [{dept}]")
        print(f"  Text    : {text}")
        print(f"  Score   : {r['priority_score']}  "
              f"Label: {r['priority_label']} (exp: {exp_label})  "
              f"Urgency: {r['urgency']} (exp: {exp_urgency})")
        if not ok:
            print(f"  ⚠️  Mismatch! label_ok={ok_label}, urgency_ok={ok_urgency}")

    print(f"\n{'=' * 72}")
    print(f"Results: {passed} passed, {failed} failed out of {len(tests)} tests")