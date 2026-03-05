# Project Structure

This file documents the detailed structure of the Grievance Intelligence System project.

`	ext
Grievance Intelligence System
├── README.md
├── admin_dashboard
│   ├── README.md
│   ├── analysis_options.yaml
│   ├── lib
│   │   ├── main.dart
│   │   ├── screens
│   │   │   ├── admin_dashboard.dart
│   │   │   ├── all_complaints_screen.dart
│   │   │   ├── analytics_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── officers_screen.dart
│   │   │   ├── profile_screen.dart
│   │   │   ├── splash_screen.dart
│   │   │   └── users_screen.dart
│   │   ├── services
│   │   │   ├── api_service.dart
│   │   │   └── auth_service.dart
│   │   └── widgets
│   │       ├── chart_card.dart
│   │       ├── data_table_widget.dart
│   │       └── stat_card.dart
│   ├── pubspec.lock
│   ├── pubspec.yaml
│   └── test
│       └── widget_test.dart
├── backend
│   ├── ai
│   │   ├── analyze_complaint.py
│   │   ├── category_encoder.pkl
│   │   ├── category_model.pkl
│   │   ├── category_vectorizer.pkl
│   │   ├── delay_risk_model.pkl
│   │   ├── department_encoder.pkl
│   │   ├── urgency_encoder.pkl
│   │   ├── urgency_model.pkl
│   │   ├── urgency_rules.py
│   │   └── urgency_vectorizer.pkl
│   ├── crud.py
│   ├── database.py
│   ├── firebase-service-account.json
│   ├── firebase_config.py
│   ├── main.py
│   ├── models.py
│   ├── requirements.txt
│   ├── schemas.py
│   ├── static
│   │   ├── audio_complaints
│   │   └── complaint_images
│   └── websocket_server.py
├── data
│   └── complaints_dataset.csv
├── docs
│   └── data_model.md
├── ml_engine
│   ├── analyze_complaint.py
│   ├── augment_data.py
│   ├── predict_category.py
│   ├── train_all_model.py
│   ├── train_classifier.py
│   ├── train_delay_risk_model.py
│   ├── train_urgency_model.py
│   ├── training_output.txt
│   └── urgency_rules.py
├── mobile_app
│   ├── README.md
│   ├── analysis_options.yaml
│   ├── firebase.json
│   ├── lib
│   │   ├── firebase_options.dart
│   │   ├── main.dart
│   │   ├── screens
│   │   │   ├── auth
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── profile_setup_screen.dart
│   │   │   ├── splash_screen.dart
│   │   │   └── user
│   │   │       ├── chat_screen.dart
│   │   │       ├── complaint_detail_screen.dart
│   │   │       ├── complaint_form_screen.dart
│   │   │       ├── complaint_success_screen.dart
│   │   │       ├── department_selection_screen.dart
│   │   │       ├── my_complaints_screen.dart
│   │   │       ├── notifications_screen.dart
│   │   │       ├── profile_screen.dart
│   │   │       ├── rating_dialog.dart
│   │   │       └── user_dashboard.dart
│   │   └── services
│   │       ├── api_service.dart
│   │       ├── audio_service.dart
│   │       ├── auth_service.dart
│   │       ├── chat_service.dart
│   │       ├── location_service.dart
│   │       └── notification_service.dart
│   ├── pubspec.lock
│   ├── pubspec.yaml
│   └── test
│       └── widget_test.dart
├── officer_dashboard
│   ├── README.md
│   ├── analysis_options.yaml
│   ├── lib
│   │   ├── main.dart
│   │   ├── screens
│   │   │   ├── analytics_screen.dart
│   │   │   ├── chat_screen.dart
│   │   │   ├── complaint_detail_screen.dart
│   │   │   ├── complaints_list_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── officer_dashboard.dart
│   │   │   ├── profile_screen.dart
│   │   │   └── splash_screen.dart
│   │   └── services
│   │       ├── api_service.dart
│   │       ├── auth_service.dart
│   │       └── chat_service.dart
│   ├── pubspec.lock
│   ├── pubspec.yaml
│   └── test
│       └── widget_test.dart
└── structure.md
`
