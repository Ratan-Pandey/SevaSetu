# Grievance Intelligence System - File Structure

## Root Directory
```
Grievance Intelligence System/
├── .github/
├── .venv/
├── README.md
├── backend/
├── data/
├── docs/
├── grievance_app/
├── ml_engine/
└── mobile_app/
```

## Backend Directory
```
backend/
├── __pycache__/
├── ai/
│   ├── __pycache__/
│   ├── analyze_complaint.py
│   ├── category_encoder.pkl
│   ├── category_model.pkl
│   ├── category_vectorizer.pkl
│   ├── char_vectorizer.pkl
│   ├── delay_risk_model.pkl
│   ├── department_encoder.pkl
│   ├── department_model.pkl
│   ├── department_vectorizer.pkl
│   ├── urgency_encoder.pkl
│   ├── urgency_model.pkl
│   ├── urgency_rules.py
│   ├── urgency_vectorizer.pkl
│   └── word_vectorizer.pkl
├── database.py
├── main.py
├── models.py
├── requirements.txt
└── test_db.py
```

## Data Directory
```
data/
├── complaints_augmented.csv
└── complaints_multilingual_expanded.csv
```

## Docs Directory
```
docs/
└── data_model.md
```

## Grievance App (Flutter Application)
```
grievance_app/
├── android/
├── build/
├── ios/
├── lib/
│   ├── screens/
│   │   └── analytics_screen.dart
│   ├── services/
│   │   └── api_service.dart
│   └── main.dart
├── linux/
├── macos/
├── test/
├── web/
├── windows/
├── analysis_options.yaml
├── grievance_app.iml
├── pubspec.lock
├── pubspec.yaml
└── README.md
```

## ML Engine Directory
```
ml_engine/
├── __pycache__/
├── analyze_complaint.py
├── augment_data.py
├── predict_category.py
├── train_all_model.py
├── train_classifier.py
├── train_delay_risk_model.py
├── train_urgency_model_optimized.py
├── training_output.txt
└── urgency_rules.py
```

## Mobile App Directory
```
mobile_app/
└── (empty directory)
```

---

## Project Overview

### Technology Stack
- **Backend**: Python (FastAPI/Flask based on main.py)
- **Frontend**: Flutter (grievance_app)
- **ML Engine**: Python with scikit-learn (pickle models)
- **Database**: SQLAlchemy-based (database.py)

### Key Components
1. **Backend**: REST API server with AI integration (located in `backend/`)
   - Includes `ai/` submodule for handling complaint analysis.
2. **Grievance App**: Flutter-based cross-platform application (located in `grievance_app/`)
   - `lib/screens`: UI screens (e.g., Analytics).
   - `lib/services`: API integration services.
3. **ML Engine**: Machine learning models and training scripts (located in `ml_engine/`)
   - Complaint category classification
   - Urgency prediction
   - Delay risk assessment
4. **Data**: Training dataset for ML models
5. **Mobile App**: Empty directory (reserved for future use)

### Machine Learning Models
- Category Classification Model
- Urgency Prediction Model
- Delay Risk Assessment Model
- TF-IDF Vectorizers for text processing
- Label Encoders for categorical data

these are suggestion i want you to check which are finished and which are not also you can give me more suggestions , if you want i can also give you specific file codes 
project SCOPE, PHASES & FUTURE ROADMAP

(Consolidated Text from Images + PDFs)

1️⃣ WHAT CAN THIS PROJECT BECOME LATER?
🚀 Extensions

Multilingual NLP

Voice-based complaints

WhatsApp integration

Federated learning

Government API integration

Smart policy recommendation engine

🔹 What this means

You are not submitting just a project.
You are starting a product journey.

2️⃣ STEP 1 — FIX THE EXACT SCOPE (30 MINUTES)

You are building Phase-1
(Hackathon + Final-Year Ready)

✅ Phase-1 WILL include:

Mobile-first application (text complaints only)

Backend + database

NLP-based classification

Delay-risk prediction

Analytics dashboard

Explainable AI

Cloud deployment

❌ Phase-1 will NOT include (yet):

Voice complaints

Multilingual NLP

WhatsApp bot

Real government integrations
