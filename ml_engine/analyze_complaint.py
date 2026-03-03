"""
AI Complaint Analysis Engine
Language: ENGLISH ONLY
Analyzes complaints and predicts category, department, urgency, and delay risk
"""

import os
import joblib
from ai.urgency_rules import apply_urgency_rules

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
    "Drainage": "Municipal Services"
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


def analyze_complaint(text: str) -> dict:
    """
    Analyzes a complaint text (English only) and predicts:
    - Category (8 categories)
    - Department (5 departments)
    - Urgency (High/Medium/Low with rule-based override)
    - Delay Risk (High/Medium/Low with confidence score)
    
    Args:
        text: Complaint description (English)
        
    Returns:
        Dictionary with predictions and confidence scores
    """
    
    # ---------- STEP 1: CATEGORY PREDICTION ----------
    text_vector_cat = category_vectorizer.transform([text])
    category = category_model.predict(text_vector_cat)[0]

    # ---------- STEP 2: AUTO DEPARTMENT ASSIGNMENT ----------
    mapped_department = CATEGORY_TO_DEPARTMENT.get(
        category, "Municipal Services"  # Default fallback
    )
    
    # ---------- STEP 3: URGENCY PREDICTION (ML + Rules) ----------
    text_vector_urg = urgency_vectorizer.transform([text])
    ml_urgency = urgency_model.predict(text_vector_urg)[0]
    
    # Apply rule-based override (catches keywords like "emergency", "bribe", etc.)
    final_urgency = apply_urgency_rules(text, ml_urgency)

    # ---------- STEP 4: DELAY RISK PREDICTION ----------
    encoded_features = [[
        category_encoder.transform([category])[0],
        department_encoder.transform([mapped_department])[0],
        urgency_encoder.transform([final_urgency])[0]
    ]]

    delay_label = delay_model.predict(encoded_features)[0]
    delay_proba = delay_model.predict_proba(encoded_features)[0]
    delay_score = delay_proba[list(delay_model.classes_).index(delay_label)]

    # ---------- RETURN RESULTS ----------
    return {
        "category": category,
        "department": mapped_department,
        "urgency": final_urgency,
        "delay_risk_label": delay_label,
        "delay_risk_score": round(float(delay_score), 2)
    }


if __name__ == "__main__":
    # Test cases (English only)
    test_cases = [
        "No electricity in my area for five days",
        "Water supply stopped without notice",
        "Road full of potholes accidents happening",
        "Bribe demanded for certificate issuance",
        "Garbage not collected for two weeks",
        "Street lights not working at night",
        "Drain blocked overflow on street",
        "Doctor absent in emergency ward"
    ]
    
    print("=" * 70)
    print("TESTING COMPLAINT ANALYSIS (English Only)")
    print("=" * 70)
    
    for text in test_cases:
        result = analyze_complaint(text)
        print(f"\n📝 Complaint: {text}")
        print(f"   Category: {result['category']}")
        print(f"   Department: {result['department']}")
        print(f"   Urgency: {result['urgency']}")
        print(f"   Delay Risk: {result['delay_risk_label']} ({result['delay_risk_score']:.0%})")