"""
urgency_rules.py  ─  Seva Setu: Grievance Intelligence System
═══════════════════════════════════════════════════════════════
Fully ISOLATED, per-department urgency detection.

Each department defines:
  • Its own keyword tiers  (critical / high / medium / low)
  • Its own time-based rules
  • Its own Hinglish / English keyword sets

No global urgency function is used as the final answer;
every department runs its own pipeline.
"""

import re

# ══════════════════════════════════════════════════════════════
# SECTION 1 ─ SHARED UTILITY  (time-number extraction only)
# ══════════════════════════════════════════════════════════════

def _extract_hours(text: str):
    """Return hours mentioned in text, or None."""
    m = re.search(r'(\d+)\s*(hour|hours|hr|hrs)', text.lower())
    return int(m.group(1)) if m else None

def _extract_days(text: str):
    """Return days mentioned in text, or None."""
    m = re.search(r'(\d+)\s*(day|days)', text.lower())
    return int(m.group(1)) if m else None

def _extract_minutes(text: str):
    """Return minutes mentioned in text, or None."""
    m = re.search(r'(\d+)\s*(minute|minutes|min|mins)', text.lower())
    return int(m.group(1)) if m else None

import re as _re_urg

def _contains(text_lower: str, keywords: list) -> bool:
    return any(kw in text_lower for kw in keywords)

def _contains_safe(text_lower: str, keywords: list) -> bool:
    """Word-boundary-aware check for keywords that could be substrings of other words."""
    for kw in keywords:
        # For short words (≤4 chars) or words that could be substrings, use word boundaries
        if len(kw) <= 4 or kw in ("mob", "gang", "riot", "loot", "darav"):
            if _re_urg.search(rf'\b{_re_urg.escape(kw)}\b', text_lower):
                return True
        else:
            if kw in text_lower:
                return True
    return False


# ══════════════════════════════════════════════════════════════
# SECTION 2 ─ POLICE DEPARTMENT URGENCY
# ══════════════════════════════════════════════════════════════
#
# Philosophy:
#   CRITICAL → life/body directly threatened RIGHT NOW
#   HIGH     → crime in progress or very recent (< 1 hr)
#   MEDIUM   → crime reported but not active threat
#   LOW      → general community concern / vandalism / noise

_POLICE_CRITICAL = [
    # English
    "rape", "murder", "kidnap", "kidnapped", "abduct", "abducted",
    "missing child", "child missing", "terror", "terrorist", "bomb",
    "hostage", "armed robbery", "gunshot", "shooting", "stabbing",
    "bleeding", "unconscious", "life threat", "death threat", "life threatening",
    "kill", "killing", "murder threat",
    # Hinglish
    "balatkaar", "hatya", "apaharan", "bomb blast", "aatankwadi",
    "goli maari", "chaku mara", "khoon", "jaan ka khatra", "zinda nahi",
    "jaan se maar", "jaan ki dhamki"
]

_POLICE_HIGH = [
    # English — active violence, in-progress crime (NOT snatching — that's Medium)
    "attack", "assault", "fight", "beating", "acid", "molest",
    "robbery", "loot", "burglary", "dacoity", "gang", "threat",
    "dangerous", "danger", "violence", "riot", "mob",
    # Hinglish
    "maar peet", "danga", "dakait", "hamla", "darav", "loot kiya"
]

_POLICE_MEDIUM = [
    # English — property crime / harassment (already occurred, not ongoing)
    "theft", "stolen", "pickpocket", "snatching", "eve teasing",
    "harassment", "stalking", "bribery", "illegal activity",
    "chain snatching", "mobile stolen", "purse stolen",
    # Hinglish
    "chori", "jhapatta", "chhera chhari", "pareshan kar raha",
    "peecha kar raha", "rishwat", "mobile chori", "jhapatta mara"
]

def police_urgency(text: str) -> str:
    t = text.lower()
    # Critical first (these are long specific phrases, no substring risk)
    if _contains(t, _POLICE_CRITICAL):
        return "Critical"
    # Medium checked before High to catch snatching/theft before "mob"/"gang" substring collisions
    if _contains(t, _POLICE_MEDIUM) and not _contains_safe(t, _POLICE_HIGH):
        return "Medium"
    # High — use word-boundary safe check for short risky words
    if _contains_safe(t, _POLICE_HIGH):
        return "High"
    if _contains(t, _POLICE_MEDIUM):
        return "Medium"
    return "Low"


# ══════════════════════════════════════════════════════════════
# SECTION 3 ─ POWER / ELECTRICITY DEPARTMENT URGENCY
# ══════════════════════════════════════════════════════════════
#
# Philosophy:
#   CRITICAL → electrical hazard (fire, sparking, exposed wire)
#   HIGH     → prolonged outage (≥ 3 days) OR transformer failure
#   MEDIUM   → outage 1-2 days OR whole area affected
#   LOW      → brief/single-house disruption or fluctuation

_POWER_CRITICAL = [
    # English
    "fire", "sparking", "spark", "short circuit", "exposed wire",
    "live wire", "electric shock", "pole fallen", "transformer blast",
    "electric fire", "burning smell", "smoke from wire",
    # Hinglish
    "aag lag gayi", "spark aa raha", "taar toot gaya", "bijli se aag",
    "pole gir gaya", "transformer phata", "current aa raha"
]

_POWER_HIGH_KEYWORDS = [
    # English
    "no electricity", "no power", "power cut", "blackout", "load shedding",
    "burnt transformer", "transformer failed", "transformer down",
    # Hinglish
    "bijli nahi", "bijli band", "koi bijli nahi", "andhera hai",
    "transformer kharab", "transformer jal gaya",
    "bijli nahi hai", "bijli nahi aayi"
]

# Hinglish number-words for days (used in power_urgency below)
_HINDI_DAY_NUMBERS = {
    "ek": 1, "do": 2, "teen": 3, "char": 4, "paanch": 5,
    "chhe": 6, "saat": 7, "aath": 8, "nau": 9, "das": 10
}

def _extract_hindi_days(text: str):
    """Extract day count from Hinglish e.g. 'teen din' → 3"""
    import re as _r
    t = text.lower()
    for word, num in _HINDI_DAY_NUMBERS.items():
        pattern = rf'\b{word}\s*(din|days?)\b'
        if _r.search(pattern, t):
            return num
    # Also catch "X din" where X is a digit written in Hindi context
    m = _r.search(r'(\d+)\s*din\b', t)
    if m:
        return int(m.group(1))
    return None

_POWER_MEDIUM_KEYWORDS = [
    # English
    "low voltage", "fluctuation", "voltage problem", "frequent cut",
    "intermittent power", "unstable supply",
    # Hinglish
    "voltage kam hai", "halki bijli", "baar baar cut", "aksar band"
]

def power_urgency(text: str) -> str:
    t = text.lower()

    # Hazard → always Critical regardless of duration
    if _contains(t, _POWER_CRITICAL):
        return "Critical"

    # Time-based: days without power (English + Hinglish)
    days  = _extract_days(t) or _extract_hindi_days(t)
    hours = _extract_hours(t)

    if _contains(t, _POWER_HIGH_KEYWORDS):
        if days is not None and days >= 3:
            return "Critical"   # 3+ days = humanitarian emergency
        if days is not None and days >= 1:
            return "High"
        if hours is not None and hours >= 12:
            return "High"
        return "High"           # keyword alone = High (no power reported)

    # Duration without explicit outage keyword
    if days is not None:
        if days >= 3:
            return "Critical"
        if days >= 1:
            return "High"

    if hours is not None:
        if hours >= 12:
            return "High"
        if hours >= 4:
            return "Medium"
        return "Low"

    if _contains(t, _POWER_MEDIUM_KEYWORDS):
        return "Medium"

    # Week / weeks mentioned → chronic issue
    if "week" in t or "weeks" in t or "hafte" in t:
        return "Critical"

    return "Low"


# ══════════════════════════════════════════════════════════════
# SECTION 4 ─ WATER DEPARTMENT URGENCY
# ══════════════════════════════════════════════════════════════
#
# Philosophy:
#   CRITICAL → contamination (disease risk) OR total drought 5+ days
#   HIGH     → no water 2-4 days OR pipe burst flooding area
#   MEDIUM   → leakage, low pressure, 1-day shortage
#   LOW      → billing complaint, minor drip, odour only

_WATER_CRITICAL = [
    # English
    "contaminated", "contamination", "poisoned", "poisoning", "dirty water", "black water", "sewage in water",
    "worms in water", "disease", "cholera", "typhoid", "diarrhea",
    "vomiting after water", "poisoned water", "foul smell",
    "pipeline burst", "flood from pipe",
    # Hinglish
    "gandha paani", "kala paani", "keede paani mein", "bimari",
    "ulti ho rahi", "paani se bimaar", "pipeline phati", "zeher paani"
]

_WATER_HIGH_KEYWORDS = [
    # English
    "no water", "water shortage", "water supply stopped", "no supply",
    "water cut", "no water since", "water not coming",
    # Hinglish
    "paani nahi", "paani band", "aapur nahi aa raha", "pani nahi aata"
]

_WATER_MEDIUM_KEYWORDS = [
    # English
    "leakage", "pipe leak", "low pressure", "water leaking",
    "dripping", "irregular supply",
    # Hinglish
    "leak ho raha", "rishav", "pressure kam", "kabhi kabhi aata"
]

def water_urgency(text: str) -> str:
    t = text.lower()

    if _contains(t, _WATER_CRITICAL):
        return "Critical"

    days = _extract_days(t)
    hours = _extract_hours(t)

    if _contains(t, _WATER_HIGH_KEYWORDS):
        if days is not None and days >= 5:
            return "Critical"
        if days is not None and days >= 2:
            return "High"
        if hours is not None and hours >= 24:
            return "High"
        return "High"           # shortage reported = High by default

    if days is not None and days >= 5:
        return "Critical"
    if days is not None and days >= 2:
        return "High"

    if _contains(t, _WATER_MEDIUM_KEYWORDS):
        return "Medium"

    if "week" in t or "weeks" in t:
        return "Critical"

    return "Low"


# ══════════════════════════════════════════════════════════════
# SECTION 5 ─ HEALTH DEPARTMENT URGENCY
# ══════════════════════════════════════════════════════════════
#
# Philosophy:
#   CRITICAL → immediate life risk (heart attack, no oxygen, coma)
#   HIGH     → acute illness, missing doctor/medicine in emergency
#   MEDIUM   → service delay, hygiene issues, non-urgent medicine
#   LOW      → billing, registration, general inquiry

_HEALTH_CRITICAL = [
    # English
    "heart attack", "cardiac arrest", "stroke", "unconscious",
    "not breathing", "no oxygen", "oxygen finished", "icu full",
    "coma", "critical condition", "no blood", "blood shortage",
    "ambulance not coming", "emergency ward closed",
    "massive bleeding", "seizure", "fit", "convulsion",
    # Hinglish
    "heart attack aaya", "sans nahi aa rahi", "oxygen nahi",
    "behosha", "hosh nahi", "khoon nahi", "ambulance nahi aayi",
    "icu nahi mila", "emergency band hai"
]

_HEALTH_HIGH = [
    # English
    "doctor not available", "no doctor", "no nurse",
    "medicine not available", "no medicine", "injection missing",
    "fever for days", "high fever", "dengue", "malaria",
    "child sick", "baby sick", "infant", "newborn", "delivery",
    "pregnant", "labour pain", "fracture",
    # Absenteeism patterns
    "doctor absent", "doctor on leave", "no staff", "ward empty",
    "nobody in emergency", "no doctor on duty", "duty doctor missing",
    "doctor nahi aaya", "doctor gayab",
    # Hinglish
    "doctor nahi hai", "dawai nahi", "bukhar teen din se",
    "bachcha beemar", "prasav", "prasuti", "toot gayi haddi"
]

_HEALTH_MEDIUM = [
    # English
    "long waiting", "waiting time", "queue", "delay in treatment",
    "medicine delay", "test pending", "report not given",
    "cleanliness", "dirty hospital", "toilet not clean",
    # Hinglish
    "lamba intezaar", "dawai der se", "report nahi mili",
    "hospital ganda", "toilet saaf nahi"
]

def health_urgency(text: str) -> str:
    t = text.lower()

    if _contains(t, _HEALTH_CRITICAL):
        return "Critical"
    if _contains(t, _HEALTH_HIGH):
        return "High"
    if _contains(t, _HEALTH_MEDIUM):
        return "Medium"
    return "Low"


# ══════════════════════════════════════════════════════════════
# SECTION 6 ─ MUNICIPAL SERVICES URGENCY
#   (Roads, Sanitation, Street Lighting, Drainage, Garbage)
# ══════════════════════════════════════════════════════════════
#
# Philosophy:
#   CRITICAL → structural collapse, sewer overflow, severe flooding
#   HIGH     → large pothole causing accidents, no garbage pickup 7+ days
#   MEDIUM   → broken streetlight, moderate pothole, waterlogging
#   LOW      → aesthetic issue, minor complaint, suggestion

_MUNI_CRITICAL = [
    # English
    "collapsed", "road collapse", "bridge broken", "sinkhole",
    "sewer overflow", "sewage overflow", "flooding street",
    "open manhole accident", "drain burst", "landslide",
    # Hinglish
    "sadak dhaansi", "nali phati", "baarh", "nala bhar gaya",
    "dhaka khula", "gutter uda"
]

_MUNI_HIGH = [
    # English
    "open manhole", "deep pothole", "accident due to",
    "no garbage for weeks", "garbage piling", "stray animals",
    "dead animal", "waterlogging", "no drainage",
    # Hinglish
    "bada gadha", "kachra nahi utha", "paani bhar gaya",
    "sadak pe kachra", "mara hua janwar", "nali jam gayi"
]

_MUNI_MEDIUM = [
    # English
    "pothole", "broken road", "streetlight not working",
    "no street light", "street light broken", "street light not working",
    "light not working", "light broken", "batti band",
    "garbage", "drainage blocked",
    "dirty area", "open sewage", "overgrown",
    # Hinglish
    "gadha", "tooti sadak", "batti nahi", "kachra", "nali jam",
    "nali band", "ganda area"
]

def municipal_urgency(text: str) -> str:
    t = text.lower()

    if _contains(t, _MUNI_CRITICAL):
        return "Critical"
    if _contains(t, _MUNI_HIGH):
        return "High"
    if _contains(t, _MUNI_MEDIUM):
        return "Medium"

    days = _extract_days(t)
    if days is not None and days >= 7:
        return "High"   # Any long-standing issue in municipal = High

    return "Low"


# ══════════════════════════════════════════════════════════════
# SECTION 7 ─ VIGILANCE DEPARTMENT URGENCY
#   (Corruption, Fraud, Misuse of power, Government misconduct)
# ══════════════════════════════════════════════════════════════
#
# Philosophy:
#   CRITICAL → bribe demanded to access essential service / safety
#   HIGH     → active fraud, scam, misuse of public funds
#   MEDIUM   → favoritism, nepotism, unfair treatment
#   LOW      → general dissatisfaction / suggestion

_VIG_CRITICAL = [
    # English
    "bribe for hospital", "bribe for medicine", "bribe for ration",
    "bribe for ration card", "bribe demanded", "bribe for job", "extortion",
    "threatening for money", "demanded money under threat",
    "scam", "ponzi",
    # Hinglish
    "rishwat maang rahe", "paisa dene par hi milega",
    "paisa nahi diya toh nahi milega", "dhamki de raha paisa ke liye",
    "ration ke liye paisa", "card ke liye rishwat"
]

_VIG_HIGH = [
    # English
    "bribe", "corruption", "fraud", "fake document", "forged",
    "illegal money", "black money", "misuse of funds",
    "government money stolen", "embezzlement",
    # Hinglish
    "rishwat", "bhrashtachar", "paisa khaya", "sarkari paisa gaya",
    "nakli kagaz", "farzi"
]

_VIG_MEDIUM = [
    # English
    "favoritism", "nepotism", "unfair", "bias", "discrimination",
    "not following rules", "misuse of power", "abuse of authority",
    "relatives", "own people", "family member appointed",
    # Hinglish
    "bhed bhaav", "apna aadmi", "niyam nahi mana",
    "taakat ka galat use", "rishtedar ko diya", "apne log"
]

def vigilance_urgency(text: str) -> str:
    t = text.lower()

    if _contains(t, _VIG_CRITICAL):
        return "Critical"
    if _contains(t, _VIG_HIGH):
        return "High"
    if _contains(t, _VIG_MEDIUM):
        return "Medium"
    return "Low"


# ══════════════════════════════════════════════════════════════
# SECTION 8 ─ PUBLIC DISPATCHER
# ══════════════════════════════════════════════════════════════

DEPT_URGENCY_MAP = {
    "Police Department":    police_urgency,
    "Power Department":     power_urgency,
    "Water Department":     water_urgency,
    "Health Department":    health_urgency,
    "Municipal Services":   municipal_urgency,
    "Vigilance Department": vigilance_urgency,
}

def get_department_urgency(text: str, department: str) -> str:
    """
    Dispatch to the correct department urgency function.
    Falls back to a generic keyword scan if department is unknown.
    Returns: 'Critical' | 'High' | 'Medium' | 'Low'
    """
    fn = DEPT_URGENCY_MAP.get(department)
    if fn:
        return fn(text)

    # Generic fallback
    t = text.lower()
    if _contains(t, ["emergency", "danger", "critical", "immediately", "urgent"]):
        return "High"
    if _contains(t, ["problem", "issue", "not working", "broken"]):
        return "Medium"
    return "Low"


# Legacy alias kept for backward compatibility (main.py / analyze_complaint.py
# may call detect_urgency_from_time; we keep it but it is no longer the
# final decision-maker — only used internally by department functions).
def detect_urgency_from_time(text: str):
    """
    DEPRECATED — kept only for backward compatibility.
    Use get_department_urgency() instead.
    """
    t = text.lower()
    days = _extract_days(t)
    hours = _extract_hours(t)
    if days is not None and days >= 3:
        return "High"
    if days is not None and days >= 1:
        return "Medium"
    if hours is not None and hours <= 24:
        return "High"
    if "week" in t or "weeks" in t:
        return "High"
    return None


# ══════════════════════════════════════════════════════════════
# SECTION 9 ─ SELF-TEST
# ══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    test_cases = [
        # (text, department, expected)
        ("Rape case reported near park",              "Police Department",    "Critical"),
        ("Theft of mobile phone",                     "Police Department",    "Medium"),
        ("No electricity for 3 days",                 "Power Department",     "Critical"),
        ("Bijli nahi teen din se",                    "Power Department",     "Critical"),
        ("Low voltage fluctuation",                   "Power Department",     "Medium"),
        ("Sparking wire near school",                 "Power Department",     "Critical"),
        ("No water for 5 days",                       "Water Department",     "Critical"),
        ("Contaminated water causing vomiting",       "Water Department",     "Critical"),
        ("Pipe leaking near road",                    "Water Department",     "Medium"),
        ("Heart attack patient in hospital no ICU",   "Health Department",    "Critical"),
        ("Doctor not available in emergency",         "Health Department",    "High"),
        ("Long waiting queue for medicine",           "Health Department",    "Medium"),
        ("Road collapsed near school",                "Municipal Services",   "Critical"),
        ("Open manhole on main road",                 "Municipal Services",   "High"),
        ("Pothole on colony road",                    "Municipal Services",   "Medium"),
        ("Bribe demanded for ration card",            "Vigilance Department", "Critical"),
        ("Corruption in officer selection",           "Vigilance Department", "High"),
        ("Favoritism in work allocation",             "Vigilance Department", "Medium"),
    ]

    print("=" * 70)
    print("SEVA SETU ─ Department-Isolated Urgency Rules Self-Test")
    print("=" * 70)
    passed = failed = 0
    for text, dept, expected in test_cases:
        result = get_department_urgency(text, dept)
        status = "✅ PASS" if result == expected else "❌ FAIL"
        if result == expected:
            passed += 1
        else:
            failed += 1
        print(f"\n{status}  [{dept}]")
        print(f"  Text    : {text}")
        print(f"  Result  : {result}  (Expected: {expected})")

    print(f"\n{'=' * 70}")
    print(f"Results: {passed} passed, {failed} failed out of {len(test_cases)} tests")