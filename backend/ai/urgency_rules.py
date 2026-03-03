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
        ("Emergency hai paani band hai", "Low", "High"),
        ("Kharab meter reading galat", "Low", "Medium"),
        ("Pole girne wala hai danger", "Medium", "High"),
    ]
    
    print("=" * 70)
    print("TESTING URGENCY RULES (English + Hinglish)")
    print("=" * 70)
    
    for text, ml_pred, expected in test_cases:
        result = apply_urgency_rules(text, ml_pred)
        status = "✅" if result == expected else "❌"
        print(f"\n{status} Text: {text}")
        print(f"   ML: {ml_pred} → Rule: {result} (Expected: {expected})")