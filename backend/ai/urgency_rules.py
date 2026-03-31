import re

EMERGENCY_KEYWORDS = [
    'emergency', 'urgent', 'critical', 'danger', 'fire',
    'death', 'injury', 'immediately', 'asap', 'help'
]

# Time-based urgency keywords
TIME_URGENCY_KEYWORDS = {
    'high': ['hours', 'hour', 'minutes', 'minute', 'days ago', 'weeks', 'week'],
    'medium': ['today', 'yesterday', 'days', 'day'],
    'low': ['month', 'months']
}

def detect_urgency_from_time(text: str) -> str:
    """Detect urgency based on time mentions"""
    text_lower = text.lower()
    
    # Check for emergency keywords first
    if any(keyword in text_lower for keyword in EMERGENCY_KEYWORDS):
        return 'High'
    
    # Check for time-based urgency
    if 'hour' in text_lower or 'minute' in text_lower:
        # Extract number before 'hour' or 'minute'
        hours_match = re.search(r'(\d+)\s*(hour|hours|minute|minutes)', text_lower)
        if hours_match:
            number = int(hours_match.group(1))
            if number <= 24:  # Within 24 hours
                return 'High'
            elif number <= 72:  # Within 3 days
                return 'Medium'
    
    if 'week' in text_lower or 'weeks' in text_lower:
        return 'High'  # Long-standing issue
    
    if 'day' in text_lower or 'days' in text_lower:
        days_match = re.search(r'(\d+)\s*(day|days)', text_lower)
        if days_match:
            number = int(days_match.group(1))
            if number >= 5:  # 5+ days
                return 'High'
            elif number >= 2:  # 2-4 days
                return 'Medium'
            else:  # 1 day
                return 'Medium'
    
    return None  # Let ML model decide

def apply_urgency_rules(text: str, predicted_urgency: str) -> str:
    """
    Apply rule-based urgency detection with English and Hinglish keyword support.
    Overrides ML prediction when critical patterns are detected.
    
    Args:
        text: Complaint description
        predicted_urgency: ML model's prediction (High/Medium/Low)
        
    Returns:
        Final urgency level after rule application
    """
    text_lower = text.lower()

    # Rule 0: New Time-based Urgency Logic
    time_urgency = detect_urgency_from_time(text)
    if time_urgency:
        return time_urgency

    # ===== HIGH URGENCY KEYWORDS =====
    high_keywords = [
        # Emergency & Danger (English)
        "emergency", "urgent", "immediately", "asap", "critical",
        "danger", "dangerous", "life threatening", "severe", "serious",
        "fire", "explosion", "collapse", "dead", "death",
        "injury", "injured", "accident", "bleeding",
        
        # Time indicators (English)
        "since days", "for days", "for weeks", "for months",
        "since yesterday", "since morning", "three days", "five days",
        "one week", "two weeks", "no water", "no electricity", "no power",
        
        # Corruption (English)
        "bribe", "corruption", "extortion", "illegal payment",
        "demanding money", "asking money",
        
        # Structural hazards (English)
        "overflowing", "burst", "broken pole", "hanging wire",
        "exposed wire", "sparking", "leaking gas", "flooding",
        
        # Emergency (Hinglish/Hindi)
        "emergency hai", "urgent hai", "bahut urgent", "turant",
        "khatarnak", "khatre mein", "jaan ka khatra",
        
        # Time indicators (Hinglish)
        "teen din", "paanch din", "char din", "do din",
        "ek hafte", "do hafte", "mahine se", "months se",
        "din se", "hafta se", "kal se", "subah se",
        "nahi aa raha", "nahi aa rahi", "band hai", "nahi hai",
        
        # Corruption (Hinglish)
        "rishwat", "bribe maang", "paisa maang", "payment demand",
        "paisa liya", "paisa le rahe", "paisa chahiye",
        
        # Structural hazards (Hinglish)
        "girne wala", "toot gaya", "phat gaya", "leak ho raha",
        "overflow ho raha", "spark aa raha", "aag lag sakti"
    ]

    # ===== MEDIUM URGENCY KEYWORDS =====
    medium_keywords = [
        # Service issues (English)
        "delay", "delayed", "not working", "problem", "issue",
        "broken", "damaged", "leakage", "irregular", "pending",
        "malfunction", "fault", "complaint ignored",
        
        # Service issues (Hinglish)
        "kharab", "tuta hua", "toota", "leak", "problem hai",
        "issue hai", "delay ho raha", "pending hai",
        "kaam nahi kar raha", "theek nahi", "galat", "sahi nahi"
    ]

    # ===== RULE APPLICATION =====
    
    # Rule 1: Force HIGH urgency if critical keywords detected
    for keyword in high_keywords:
        if keyword in text_lower:
            return "High"

    # Rule 2: Force MEDIUM urgency if currently Low but medium keywords detected
    if predicted_urgency == "Low":
        for keyword in medium_keywords:
            if keyword in text_lower:
                return "Medium"

    # Rule 3: Return ML prediction if no rules triggered
    return predicted_urgency


# Test function
if __name__ == "__main__":
    test_cases = [
        ("Bijli nahi aa rahi teen din se", "Low", "High"),
        ("Power not working since yesterday", "Low", "High"),
        ("Rishwat maang rahe certificate ke liye", "Low", "High"),
        ("Water leakage issue pending", "Low", "Medium"),
        ("Street light not working", "Low", "Low"),
        ("No water for 5 hours", "Low", "High"),
        ("Electricity off for 5 days", "Low", "High"),
        ("Water gone for 2 days", "Low", "Medium"),
        ("Resolved since 2 weeks", "Low", "High"),
        ("Emergency hai paani band hai", "Low", "High"),
        ("Kharab meter reading galat", "Low", "Medium"),
        ("Pole girne wala hai danger", "Medium", "High"),
    ]
    
    print("=" * 70)
    print("TESTING URGENCY RULES (Enhanced with Time Mentions)")
    print("=" * 70)
    
    for text, ml_pred, expected in test_cases:
        result = apply_urgency_rules(text, ml_pred)
        status = "PASS" if result == expected else "FAIL"
        print(f"\n[{status}] Text: {text}")
        print(f"   ML: {ml_pred} → Rule: {result} (Expected: {expected})")