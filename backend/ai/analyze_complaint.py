import os
import joblib
from ai.urgency_rules import apply_urgency_rules, detect_urgency_from_time



# ===== CRITICAL CATEGORY OVERRIDE (NEW) =====
def detect_critical_category(text: str):
    text_lower = text.lower()

    crime_keywords = [
        "kidnap", "kidnapped", "missing", "murder", "theft",
        "stolen", "robbery", "attack", "assault", "rape",
        "crime", "police", "fight", "violence"
    ]

    for word in crime_keywords:
        if word in text_lower:
            return "Crime"

    return None

# ===== CATEGORY TO DEPARTMENT MAPPING =====
# 8 Categories → 5 Departments
CATEGORY_TO_DEPARTMENT = {
    "Electricity": "Power Department",
    "Water Supply": "Water Department",
    "Sanitation": "Municipal Services",
    "Roads": "Municipal Services",
    "Health": "Health Department",
    "Corruption": "Vigilance Department",
    "Street Lighting": "Municipal Services",
    "Drainage": "Municipal Services",
    "Crime": "Police Department",
}

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# ===== Load ML Models =====
category_model = joblib.load(os.path.join(BASE_DIR, "category_model.pkl"))
category_vectorizer = joblib.load(os.path.join(BASE_DIR, "category_vectorizer.pkl"))

urgency_model = joblib.load(os.path.join(BASE_DIR, "urgency_model.pkl"))
urgency_vectorizer = joblib.load(os.path.join(BASE_DIR, "urgency_vectorizer.pkl"))

delay_model = joblib.load(os.path.join(BASE_DIR, "delay_risk_model.pkl"))

category_encoder = joblib.load(os.path.join(BASE_DIR, "category_encoder.pkl"))
department_encoder = joblib.load(os.path.join(BASE_DIR, "department_encoder.pkl"))
urgency_encoder = joblib.load(os.path.join(BASE_DIR, "urgency_encoder.pkl"))

def police_priority_logic(text):
    text = text.lower()

    # 🔴 Critical crimes
    if any(word in text for word in [
        "kidnap", "kidnapped", "missing child", "abduction",
        "murder", "killing", "homicide",
        "rape", "sexual assault"
    ]):
        return 100

    # 🔴 Very serious
    if any(word in text for word in [
        "attack", "assault", "violence", "gun", "shooting",
        "knife", "stab", "threat", "danger"
    ]):
        return 90

    # 🟡 Medium crimes
    if any(word in text for word in [
        "robbery", "loot", "snatching", "burglary"
    ]):
        return 75

    if any(word in text for word in [
        "theft", "stolen", "pickpocket"
    ]):
        return 65

    # 🟢 Minor
    if any(word in text for word in [
        "complaint", "argument", "fight", "disturbance"
    ]):
        return 50

    return 45


def electricity_priority_logic(text):
    text = text.lower()

    # 🔴 Long outages
    if any(word in text for word in [
        "no electricity for 3 days", "no electricity for 4 days",
        "no electricity for 5 days", "power cut for days"
    ]):
        return 95

    if "day" in text:
        return 90

    # 🟡 Medium outages
    if any(word in text for word in [
        "no electricity", "power cut", "blackout"
    ]):
        if any(word in text for word in ["hours", "hour", "5 hours", "6 hours"]):
            return 70
        return 60

    # 🟡 Equipment failure
    if any(word in text for word in [
        "transformer", "burnt transformer", "electric pole broken",
        "wire cut", "short circuit"
    ]):
        return 75

    # 🟢 Minor issues
    if any(word in text for word in [
        "voltage fluctuation", "low voltage", "high voltage",
        "power fluctuation"
    ]):
        return 50

    return 40


def health_priority_logic(text):
    text = text.lower()

    # 🔴 Critical emergency
    if any(word in text for word in [
        "heart attack", "stroke", "unconscious",
        "emergency", "critical condition",
        "ambulance not available", "bleeding", "serious injury"
    ]):
        return 100

    # 🔴 Severe hospital issues
    if any(word in text for word in [
        "doctor not available", "operation failure",
        "surgery failed", "no icu bed", "no oxygen",
        "patient dying"
    ]):
        return 90

    # 🟡 Medium issues
    if any(word in text for word in [
        "medicine not available", "hospital delay",
        "treatment delay", "long waiting"
    ]):
        return 70

    # 🟢 Minor
    if any(word in text for word in [
        "checkup", "appointment issue"
    ]):
        return 50

    return 45


def municipal_priority_logic(text):
    text = text.lower()

    # 🔴 Dangerous situations
    if any(word in text for word in [
        "open drain", "accident due to road",
        "road collapsed", "sewer overflow",
        "flooded street"
    ]):
        return 95

    # 🔴 High severity
    if any(word in text for word in [
        "garbage overflow", "blocked drainage",
        "waterlogging", "sewage leakage"
    ]):
        return 80

    # 🟡 Medium
    if any(word in text for word in [
        "pothole", "road damage", "broken road"
    ]):
        return 70

    if any(word in text for word in [
        "street light not working"
    ]):
        return 60

    # 🟢 Minor
    if any(word in text for word in [
        "cleaning issue", "dust", "waste collection delay"
    ]):
        return 50

    return 45


def water_priority_logic(text):
    text = text.lower()

    # 🔴 Critical
    if any(word in text for word in [
        "no water for days", "no water supply",
        "water shortage", "drinking water not available"
    ]):
        return 95

    # 🔴 Contamination
    if any(word in text for word in [
        "dirty water", "contaminated water",
        "smelly water", "unsafe water"
    ]):
        return 85

    # 🟡 Medium
    if any(word in text for word in [
        "leakage", "pipe burst", "water leakage"
    ]):
        return 70

    # 🟢 Minor
    if any(word in text for word in [
        "low pressure", "slow supply"
    ]):
        return 50

    return 45


def corruption_priority_logic(text):
    text = text.lower()

    # 🔴 Serious corruption
    if any(word in text for word in [
        "bribe", "corruption", "fraud", "scam",
        "illegal payment"
    ]):
        return 95

    # 🟡 Medium
    if any(word in text for word in [
        "misuse of power", "favoritism", "unfair"
    ]):
        return 75

    # 🟢 Minor
    if any(word in text for word in [
        "delay", "inefficiency"
    ]):
        return 60

    return 50


def default_priority_logic(urgency, delay_score):
    if urgency == "High":
        return 70
    elif urgency == "Medium":
        return 55
    return 40


def calculate_priority_score(category, urgency, delay_score, text, department):
    if department == "Police":
        return police_priority_logic(text)

    elif department == "Electricity":
        return electricity_priority_logic(text)

    elif department == "Health":
        return health_priority_logic(text)

    elif department == "Municipal Services":
        return municipal_priority_logic(text)

    elif department == "Water Supply":
        return water_priority_logic(text)

    elif department == "Corruption":
        return corruption_priority_logic(text)

    else:
        return default_priority_logic(urgency, delay_score)


def get_priority_label(score):
    if score >= 80:
        return "High"
    elif score >= 40:
        return "Medium"
    else:
        return "Low"


def generate_priority_explanation(category, urgency, text, department, priority_label):
    """Generate a human-readable explanation for why a complaint was assigned its priority"""
    text_lower = text.lower()
    reasons = []

    # 🚨 Police / Crime
    if department == "Police Department" or category == "Crime":
        if any(word in text_lower for word in ["kidnap", "murder", "rape", "attack", "missing", "violence", "threat"]):
            reasons.append("it indicates a serious crime and immediate danger")
        elif any(word in text_lower for word in ["theft", "stolen", "robbery", "scam"]):
            reasons.append("it involves a criminal activity")

    # ⚡ Electricity
    elif department == "Power Department" or category == "Electricity":
        if any(word in text_lower for word in ["days", "3 day", "4 day", "5 day", "week"]):
            reasons.append("the outage has lasted for multiple days")
        elif any(word in text_lower for word in ["voltage", "fluctuation", "short circuit", "sparking"]):
            reasons.append("it indicates a hazardous electrical situation")
        elif "no" in text_lower and ("electricity" in text_lower or "power" in text_lower or "light" in text_lower):
            reasons.append("it involves a complete loss of power")

    # 💧 Water
    elif department == "Water Department" or category == "Water Supply":
        if any(word in text_lower for word in ["no water", "not coming", "shortage", "stopped"]):
            reasons.append("there is a critical disruption of water supply")
        elif any(word in text_lower for word in ["dirty", "contaminated", "smelly", "unsafe"]):
            reasons.append("it involves potential water contamination")

    # 🏥 Health
    elif department == "Health Department" or category == "Health":
        if any(word in text_lower for word in ["emergency", "accident", "critical", "heart attack", "dying", "unconscious"]):
            reasons.append("it is a life-threatening medical emergency")
        elif any(word in text_lower for word in ["doctor", "ambulance", "hospital"]):
            reasons.append("it involves critical healthcare resource availability")

    # 🏢 Municipal Services
    elif department == "Municipal Services":
        if any(word in text_lower for word in ["open drain", "collapsed", "sewer overflow", "flood"]):
            reasons.append("it poses a significant public safety hazard")

    # 🕵️ Vigilance / Corruption
    elif department == "Vigilance Department" or category == "Corruption":
        if any(word in text_lower for word in ["bribe", "corruption", "fraud"]):
            reasons.append("it involves serious institutional misconduct")

    # 🏛️ Default or fallback reasons based on urgency
    if not reasons:
        if urgency == "High":
            reasons.append("the context suggests high urgency and immediate need for intervention")
        else:
            reasons.append("it requires systematic resolution based on the reported context")

    return f"This complaint is {priority_label.lower()} priority because " + ", ".join(reasons) + "."


def analyze_complaint(text: str, selected_department: str = None) -> dict:
    """
    Analyzes a complaint text and predicts:
    - Category (8 categories)
    - Department (5 departments)
    - Urgency (High/Medium/Low with rule-based override)
    - Delay Risk (High/Medium/Low with confidence score)
    
    Supports English text only.
    
    Args:
        text: Complaint description
        
    Returns:
        Dictionary with predictions and confidence scores
    """
    
    # Step 1: Check critical override
    override_category = detect_critical_category(text)

    if override_category:
        category = override_category
    else:
        text_vector_cat = category_vectorizer.transform([text])
        category = category_model.predict(text_vector_cat)[0]

    # ---------- STEP 2: AUTO DEPARTMENT ASSIGNMENT ----------
    mapped_department = CATEGORY_TO_DEPARTMENT.get(
        category, "Municipal Services"  # Default fallback
    )
    
    # ---------- STEP 3: URGENCY PREDICTION (ML + Rules) ----------
    # Urgency prediction with time-based enhancement
    urgency_from_time = detect_urgency_from_time(text)
    if urgency_from_time:
        final_urgency = urgency_from_time
    else:
        # Fallback to ML model and other rules
        text_vector_urg = urgency_vectorizer.transform([text])
        ml_urgency = urgency_model.predict(text_vector_urg)[0]
        final_urgency = apply_urgency_rules(text, ml_urgency)

    # ---------- STEP 4: DELAY RISK PREDICTION ----------

    # Handle unseen categories (like Crime)
    if category not in category_encoder.classes_:
        delay_label = "High" if final_urgency == "High" else "Medium"
        delay_score = 0.9 if delay_label == "High" else 0.6
    else:
        encoded_features = [[
            category_encoder.transform([category])[0],
            department_encoder.transform([mapped_department])[0],
            urgency_encoder.transform([final_urgency])[0]
        ]]

        delay_label = delay_model.predict(encoded_features)[0]
        delay_proba = delay_model.predict_proba(encoded_features)[0]
        priority_score = calculate_priority_score(
        category, final_urgency, delay_score, text, selected_department or mapped_department
    )
    
    priority_label = get_priority_label(priority_score)
    
    explanation = generate_priority_explanation(
        category, final_urgency, text, mapped_department, priority_label
    )

    return {
        "category": category,
        "department": mapped_department,
        "urgency": final_urgency,
        "delay_risk_label": delay_label,
        "delay_risk_score": round(float(delay_score), 2),
        "priority_score": int(priority_score),
        "priority_label": priority_label,
        "explanation": explanation
    }

if __name__ == "__main__":
    # Test cases
    test_cases = [
        "There has been no electricity in my area for five days",
        "Bijli nahi aa rahi teen din se emergency hai",
        "Paani supply band hai subah se problem",
        "Water supply stopped without notice",
        "Road full of potholes accidents happening",
        "Sadak tooti hui repair karo urgent",
        "Bribe demanded for certificate issuance",
        "Rishwat maang rahe paisa chahiye"
    ]
    
    print("=" * 70)
    print("TESTING COMPLAINT ANALYSIS (English + Hinglish)")
    print("=" * 70)
    
    for text in test_cases:
        result = analyze_complaint(text)
        print(f"\n📝 Complaint: {text}")
        print(f"   Category: {result['category']}")
        print(f"   Department: {result['department']}")
        print(f"   Urgency: {result['urgency']}")
        print(f"   Delay Risk: {result['delay_risk_label']} ({result['delay_risk_score']:.0%})")
