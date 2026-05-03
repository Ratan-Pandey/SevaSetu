# 📂 Grievance Intelligence System - Complete Project Structure

This document provides a comprehensive overview of the full project hierarchy, from the AI-powered backend to the multi-platform frontend dashboards.

---

## 🌳 1. Visual File Tree (Source)

```text
Grievance Intelligence System/
├── admin_dashboard/           # Admin Web Portal (Flutter Web)
│   ├── lib/
│   │   ├── screens/           # Oversight & Management Screens
│   │   ├── services/          # Admin API Layer
│   │   ├── widgets/           # Reusable UI Components
│   │   └── main.dart          # Entry Point
│   └── pubspec.yaml
├── backend/                   # FastAPI Backend (Python)
│   ├── ai/                    # Intelligence Layer (ML Models & Analysis)
│   │   ├── analyze_complaint.py # Core NLP analysis script
│   │   ├── urgency_rules.py     # Rule-based priority engine
│   │   └── *.pkl                # Trained model binaries
│   ├── static/                # Media Evidence Storage
│   │   ├── complaint_audio/     # Voice recordings
│   │   └── complaint_images/    # Photo evidence
│   ├── main.py                # Main Application API & Socket Entry
│   ├── websocket_server.py    # Real-time Socket.IO definitions
│   ├── models.py              # DB Schema (SQLAlchemy Models)
│   ├── schemas.py             # Data Validation (Pydantic)
│   ├── crud.py                # Database queries & logic
│   ├── database.py            # DB Connection
│   ├── firebase_config.py     # Firebase Auth Integration
│   └── security.py            # Password hashing & JWT logic
├── mobile_app/                # Citizen Mobile App (Flutter)
│   ├── lib/
│   │   ├── screens/           # User Interface Modules
│   │   │   ├── auth/          # Login & Reg flows
│   │   │   └── user/          # Core citizen features
│   │   ├── services/          # Business Logic & Infrastructure
│   │   │   ├── api_service.dart     # HTTP client
│   │   │   ├── socket_service.dart  # Real-time events
│   │   │   └── notification_service.dart # Alert management
│   │   └── main.dart          # App bootstrap
│   └── pubspec.yaml
├── officer_dashboard/         # Officer Web Portal (Flutter Web)
│   ├── lib/
│   │   ├── screens/           # Workflow & Desk Management
│   │   ├── services/          # Officer communication logic
│   │   └── main.dart          # App startup
│   └── pubspec.yaml
├── data/                      # Training Datasets & CSVs
├── docs/                      # Technical Documentation & UI Mockups
├── ml_engine/                 # Machine Learning Training codebase
└── structure.md               # [THIS FILE]
```

---

## 🛠️ 2. Detailed Module Breakdown

### 🐍 Backend: The Intelligence Engine (`/backend`)
The backend is a high-performance **FastAPI** service managing authentication, AI processing, and real-time state synchronization.

*   **`main.py`**: The central orchestrator. It handles the FastAPI routing and wraps the application in a **Socket.IO ASGIApp** for bi-directional communication.
*   **`websocket_server.py`**: A specialized module that manages Socket.IO instances, room-based chat logic, and the `send_notification` dispatcher.
*   **`ai/`**: Contains the semantic analysis engine. It classifies complaints into departments and calculates an AI-driven "Urgency Score" based on NLP analysis.
*   **`models.py`**: Defines the relational database structure, including `User`, `Officer`, `Complaint`, `Notification`, and `ChatMessage`.
*   **`firebase_config.py`**: Handles secure token verification, ensuring that only authenticated Firebase users can interact with the system.

### 📱 Mobile App: Citizen Portal (`/mobile_app`)
A multi-modal Flutter application designed for accessibility, allowing citizens to file grievances via text, voice, or image.

*   **`services/socket_service.dart`**: Establishes a persistent connection to the backend for instant updates on complaint status and real-time chat.
*   **`screens/user/complaint_form_screen.dart`**: The core submission interface with built-in location tagging, audio recording, and image attachment capabilities.
*   **`screens/user/notifications_screen.dart`**: A centralized hub for all user alerts, synced real-time via Socket.IO.
*   **`screens/user/chat_screen.dart`**: Implements a dedicated communication channel between the citizen and the assigned officer.

### 👮 Officer Dashboard: Management Portal (`/officer_dashboard`)
A streamlined web interface for government officers to triage and resolve complaints under their jurisdiction.

*   **`screens/complaints_list_screen.dart`**: A prioritized list of complaints, sorted by AI urgency scores.
*   **`screens/complaint_detail_screen.dart`**: Comprehensive view of a grievance, including maps, evidence, and status controls.
*   **`screens/chat_screen.dart`**: Allows officers to request more information or provide updates directly to the citizen.

### 🏛️ Admin Dashboard: Executive Oversight (`/admin_dashboard`)
A master portal for system administrators to monitor inter-departmental performance.

*   **Analytics Hub**: Visualizes heatmaps of grievance clusters and tracks departmental resolution TAT (Turn-Around Time).
*   **User Management**: Controlled registration of new officers and department re-assignment.

---

## 🧠 3. AI & ML Pipeline
*   **Natural Language Classification**: Uses a Random Forest Classifier to map user descriptions to specific government departments.
*   **Prioritization Engine**: Combines rule-based logic (e.g., life safety) with sentiment analysis to rank complaints by severity.
*   **Automated Routing**: Complaints are automatically assigned based on the AI's departmental prediction and the availability of officers.

---

## 📁 4. Persistence & Assets
*   **`/backend/static`**: Stores media evidence. Files are named using a timestamp-based unique ID and linked to the tracking ID of the complaint.
*   **`database.db`**: Source of truth for all system entities, storing complaint history, logs, and user metadata.
