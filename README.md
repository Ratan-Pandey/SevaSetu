# Grievance Intelligence System 🚀

An AI-Powered Complaint Management System designed to streamline grievance redressal through intelligent classification, urgency prediction, and risk assessment.

## 📌 Overview

The **Grievance Intelligence System** is a full-stack solution that leverages modern AI to transform the way public and private grievances are handled. By using Natural Language Processing (NLP), the system automatically categorizes incoming complaints, determines their urgency level, and flags potential delays before they happen, ensuring faster and more transparent resolutions.

## ✨ Key Features

-   **🤖 AI-Powered Classification**: Automatically routes complaints to the correct department (Power, Water, Health, etc.) using trained ML models.
-   **⚠️ Urgency & Risk Assessment**: Uses NLP to identify critical issues and predict the risk of resolution delay.
-   **🛡️ Secure Authentication**: Integrated with Firebase Authentication for seamless Google Sign-In.
-   **📱 Cross-Platform Experience**: A sleek Flutter-based mobile and web application.
-   **📊 Real-time Tracking**: Users can monitor the status of their complaints and receive instant notifications.
-   **🔍 Analytics & AI Insights**: Transparent metrics for administrative transparency.

## 🛠️ Technology Stack

### Frontend (Mobile & Web)
-   **Framework**: [Flutter](https://flutter.dev/)
-   **State Management**: [Provider](https://pub.dev/packages/provider)
-   **Authentication**: Firebase Auth (Google Sign-In)
-   **Networking**: HTTP/REST API

### Backend
-   **Framework**: [FastAPI](https://fastapi.tixtile.com/) (Python)
-   **Database**: SQLAlchemy / PostgreSQL (or Local SQLite)
-   **Authentication**: Firebase Admin SDK
-   **Execution**: Uvicorn

### AI / ML Engine
-   **Libraries**: Scikit-Learn, Pandas, NumPy, NLTK
-   **Models**: 
    -   Category Classification (TF-IDF + Support Vector Machine/Random Forest)
    -   Urgency Analysis
    -   Delay Risk Prediction
-   **Persistence**: Pickle (`.pkl`) models

## 📂 Project Structure

```text
Grievance Intelligence System/
├── backend/            # Python FastAPI Server & Firebase Config
│   ├── ai/            # Pre-trained ML models and analysis logic
│   ├── main.py        # API Entry point
│   └── requirements.txt
├── ml_engine/         # Scripts for model training & data augmentation
├── mobile_app/         # Flutter application codebase
│   ├── lib/
│   │   ├── screens/   # UI Screens (Dashboard, Complaint Form, etc.)
│   │   ├── services/  # API & Auth services
│   │   └── main.dart  # App entry point
│   └── pubspec.yaml
├── data/              # Training datasets (CSV)
└── structure.md       # Detailed file mapping
```

## 🚀 Getting Started

### Prerequisites
-   [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.0.0)
-   [Python 3.10+](https://www.python.org/downloads/)
-   Firebase Project (with Authentication & Firestore enabled)

### 1. Backend Setup
1.  Navigate to the backend directory:
    ```bash
    cd backend
    ```
2.  Create and activate a virtual environment:
    ```bash
    python -m venv venv
    source venv/bin/activate  # On Windows: venv\Scripts\activate
    ```
3.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
4.  Place your `firebase-service-account.json` in the `backend/` root.
5.  Run the server:
    ```bash
    uvicorn main:app --reload
    ```

### 2. Frontend Setup
1.  Navigate to the mobile app directory:
    ```bash
    cd mobile_app
    ```
2.  Install Flutter dependencies:
    ```bash
    flutter pub get
    ```
3.  Add your `google-services.json` (Android) to `android/app/` and configure Firebase for Web.
4.  Run the app:
    ```bash
    flutter run
    ```

## 🧑‍💻 Contributing

We welcome contributions! Whether it's a bug fix, a new feature, or improved documentation, please feel free to open a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---
*Built with ❤️ for the future of intelligent governance.*
