# Data Model – AI-Powered Public Grievance Intelligence System

## Purpose
This document defines the database structure used to store complaints,
user information, AI predictions, and complaint lifecycle events.
The data model is designed to support analytics, machine learning,
and decision-making.

## Table 1: users

Stores information about citizens and administrators.

Fields:
- id (primary key)
- name
- email
- role (user / admin)
- created_at

## Table 2: complaints

Stores grievance details submitted by users.

Fields:
- id (primary key)
- user_id (foreign key → users.id)
- description (complaint text)
- category (predicted by NLP model)
- urgency_level (low / medium / high)
- status (submitted / in_progress / resolved)
- department
- created_at
- resolved_at

## Table 3: complaint_predictions

Stores AI-generated delay risk predictions.

Fields:
- id (primary key)
- complaint_id (foreign key → complaints.id)
- delay_risk_score (value between 0 and 1)
- delay_risk_label (low / high)
- explanation (text summary)
- predicted_at

## Table 4: complaint_events

Tracks the lifecycle events of a complaint.

Fields:
- id (primary key)
- complaint_id (foreign key → complaints.id)
- event_type (assigned / updated / resolved)
- event_time
- notes

## How AI Uses This Data

- The complaint description is used by the NLP model to predict
  category and urgency.
- Historical complaint resolution times are used to train the
  delay-risk prediction model.
- Complaint events help identify abnormal delays and repeated issues.
- AI predictions are stored separately to maintain transparency
  and explainability.
