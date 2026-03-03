"""
Urgency Rules - ENGLISH ONLY
Rule-based urgency detection to override ML predictions
"""

def apply_urgency_rules(text: str, predicted_urgency: str) -> str:
    """
    Apply rule-based urgency detection (English only).
    Overrides ML prediction when critical keywords detected.
    
    Args:
        text: Complaint description (English)
        predicted_urgency: ML model's prediction (High/Medium/Low)
        
    Returns:
        Final urgency level after rule application
    """
    text_lower = text.lower()

    # ===== HIGH URGENCY KEYWORDS (English) =====
    high_keywords = [
        # Emergency & Danger
        "emergency", "urgent", "immediately", "asap", "critical",
        "danger", "dangerous", "life threatening", "severe", "serious",
        "fire", "explosion", "collapse", "collapsed",
        
        # Death & Injury
        "dead", "death", "died", "dying",
        "injury", "injured", "bleeding", "wounded",
        "accident", "crash",
        
        # Time indicators (prolonged issues)
        "since days", "for days", "for weeks", "for months",
        "since yesterday", "since morning",
        "three days", "four days", "five days",
        "one week", "two weeks",
        "no water", "no electricity", "no power",
        
        # Corruption
        "bribe", "corruption", "extortion", "illegal payment",
        "demanding money", "asking money", "pay under table",
        
        # Structural hazards
        "overflowing", "overflow", "burst", "broken pole",
        "hanging wire", "exposed wire", "sparking",
        "leaking gas", "gas leak", "flooding", "flood"
    ]

    # ===== MEDIUM URGENCY KEYWORDS (English) =====
    medium_keywords = [
        # Service issues
        "delay", "delayed", "not working", "problem", "issue",
        "broken", "damaged", "damage", "leakage", "leak",
        "irregular", "pending", "malfunction", "fault",
        "complaint ignored", "not responding", "no response"
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
        ("No electricity for three days", "Low", "High"),
        ("Power not working since yesterday", "Low", "High"),
        ("Bribe demanded for certificate", "Low", "High"),
        ("Water leakage issue pending", "Low", "Medium"),
        ("Street light not working", "Low", "Low"),
        ("Emergency situation danger", "Low", "High"),
        ("Broken meter reading error", "Low", "Medium"),
        ("Pole collapsed immediate action", "Medium", "High"),
    ]
    
    print("=" * 70)
    print("TESTING URGENCY RULES (English Only)")
    print("=" * 70)
    
    for text, ml_pred, expected in test_cases:
        result = apply_urgency_rules(text, ml_pred)
        status = "✅" if result == expected else "❌"
        print(f"\n{status} Text: {text}")
        print(f"   ML: {ml_pred} → Rule: {result} (Expected: {expected})")