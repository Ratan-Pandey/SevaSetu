import sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

import json as _json
from fastapi import FastAPI, Depends, HTTPException, status, Header, Request, WebSocket, WebSocketDisconnect, File, UploadFile
from fastapi.responses import JSONResponse, StreamingResponse
import shutil
import os
import csv
import io
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import case
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime, timedelta, timezone
from pydantic import BaseModel
import models
import schemas
import crud
import re
from database import engine, get_db
import firebase_admin
from firebase_admin import credentials, messaging
from firebase_config import verify_firebase_token, initialize_firebase
from ai.analyze_complaint import analyze_complaint
from security import verify_password, create_access_token, decode_token, get_password_hash
from models import Base, User, Complaint, ChatMessage, Notification, Officer, ComplaintUpdate, ComplaintRating

def format_iso(dt):
    if dt is None: return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc).isoformat()
    return dt.isoformat()



def get_current_user(authorization: str = Header(...), db: Session = Depends(get_db)):
    """Dependency to verify Firebase token and return DB user"""
    try:
        token = authorization.split(" ")[1]
        firebase_user = verify_firebase_token(token)

        if not firebase_user:
            raise HTTPException(status_code=401, detail="Invalid Firebase token")

        # Sync with database to get the internal Integer ID
        user = crud.get_user_by_firebase_uid(db, firebase_user['uid'])
        
        if not user:
            # Auto-register if valid token but not in DB
            user = crud.create_user(
                db=db,
                firebase_uid=firebase_user['uid'],
                email=firebase_user.get('email', 'unknown@gmail.com'),
                name=firebase_user.get('name', 'Citizen')
            )
        
        return user

    except Exception:
        raise HTTPException(
            status_code=401, 
            detail="Authorization header missing or invalid"
        )
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/officer/login")


from jose import ExpiredSignatureError, JWTError

def get_current_officer(token: str = Depends(oauth2_scheme)):
    """Dependency to verify JWT and return officer details"""
    try:
        payload = decode_token(token)
        return payload
    except ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired. Please login again.")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication error: {str(e)}")


from ai.analyze_complaint import analyze_complaint
from fastapi.staticfiles import StaticFiles
import shutil
import time
import aiosmtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import socketio
from websocket_server import sio, send_notification, broadcast_dashboard_update
import asyncio

async def notify_user(db: Session, user_id: int, title: str, message: str, notification_type: str, complaint_id: int = None):
    """Save notification to DB and emit real-time event via Socket.IO"""
    print(f"🔔 [NOTIFY] Initializing notification for User ID: {user_id} (Type: {type(user_id)})")
    try:
        # Create DB record
        notif = Notification(
            user_id=user_id,
            complaint_id=complaint_id,
            title=title,
            message=message,
            notification_type=notification_type,
            is_read=False
        )
        db.add(notif)
        db.commit()
        db.refresh(notif)
        print(f"✅ [NOTIFY] Record created in DB: ID {notif.id} for User {user_id}")
        
        # Emit real-time
        payload = {
            "id": notif.id,
            "title": title,
            "message": message,
            "notification_type": notification_type,
            "complaint_id": complaint_id,
            "created_at": str(notif.created_at),
            "is_read": False
        }
        print(f"📡 [NOTIFY] Attempting Socket emission for User {user_id}...")
        await send_notification(user_id, payload)
        print(f"🚀 [NOTIFY] send_notification call completed for User {user_id}")
        return notif
    except Exception as e:
        print(f"❌ [NOTIFY] ERROR: {e}")
        import traceback
        traceback.print_exc()
        return None


# Request Schemas for Validation
class ComplaintStatusUpdate(BaseModel):
    status: str
    update_text: str
    officer_id: int


# Initialize Firebase
try:
    initialize_firebase()
except Exception as e:
    print(f"⚠️  Firebase initialization skipped: {e}")
    print("📝 Using mock authentication for testing")

fastapi_app = FastAPI(
    title="Grievance Intelligence API v3.0",
    description="AI-powered complaint system with Firebase auth",
    version="3.0.0"
)

# 🔥 STEP 2: SOCKET.IO WRAPPER (Applied at the end of this file)
# app.mount("/socket.io", socket_app)  <-- REMOVED as per critical fix instructions

# ✅ CORS — covers all FastAPI HTTP routes.
# Socket.IO polling CORS is handled separately by the sio AsyncServer
# via cors_allowed_origins="*" in websocket_server.py.
fastapi_app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ MOUNT STATIC FILES (Essential for serving uploaded images/audio)
fastapi_app.mount("/static", StaticFiles(directory="static"), name="static")

# ✅ GLOBAL ERROR LOGGER (Very important for catching 500s)
@fastapi_app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"🔥 [GLOBAL_ERROR] {request.method} {request.url}")
    print(f"🚨 Traceback: {exc}")
    import traceback
    traceback.print_exc()
    
    # Create error response with CORS headers
    error_response = JSONResponse(
        status_code=500,
        content={"detail": str(exc)}
    )
    # Add CORS headers to error response
    error_response.headers["Access-Control-Allow-Origin"] = "*"
    error_response.headers["Access-Control-Allow-Credentials"] = "false"
    error_response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS, PATCH"
    error_response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
    return error_response

# ✅ REQUEST LOGGER WITH CORS HEADERS (For debugging & ensuring CORS on all responses)
@fastapi_app.middleware("http")
async def log_requests(request: Request, call_next):
    print(f"🚀 [REQUEST] {request.method} {request.url}")
    try:
        response = await call_next(request)
        # Ensure CORS headers are set on all responses (fix for socketio.ASGIApp wrapper)
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Credentials"] = "false"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS, PATCH"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
        print(f"✅ [RESPONSE] {response.status_code}")
        return response
    except Exception as e:
        print(f"❌ [ERROR] {e}")
        raise

# Mount static files
fastapi_app.mount("/static", StaticFiles(directory="static"), name="static")

# Socket.IO ASGI app will be created at the end of the file

# Firebase is initialized via initialize_firebase() at the top of the file

# Email settings (use Gmail for testing)
EMAIL_HOST = "smtp.gmail.com"
EMAIL_PORT = 587
EMAIL_USER = "ratanpandey822@gmail.com"  # Using provided email from previous context if available, otherwise placeholder
EMAIL_PASSWORD = "your-app-password"  # USER will need to update this

async def send_email(to_email: str, subject: str, body: str):
    """Send async email via SMTP"""
    try:
        message = MIMEMultipart()
        message["From"] = EMAIL_USER
        message["To"] = to_email
        message["Subject"] = subject
        message.attach(MIMEText(body, "html"))

        await aiosmtplib.send(
            message,
            hostname=EMAIL_HOST,
            port=EMAIL_PORT,
            username=EMAIL_USER,
            password=EMAIL_PASSWORD,
            start_tls=True,
        )
        print(f"✅ Email sent to {to_email}")
    except Exception as e:
        print(f"❌ Email error: {e}")



STOPWORDS = {"the", "is", "for", "my", "in", "on", "a", "an", "and", "to", "of", "please", "help"}


def preprocess(text: str) -> set:
    """Normalize text and remove stopwords"""
    # Remove punctuation and normalize
    clean_text = re.sub(r'[^\w\s\d]', '', text.lower())
    return {
        word for word in clean_text.split()
        if word not in STOPWORDS
    }


def quick_signature(text: str) -> frozenset:
    """Generate a light hash of the top keywords for fast pre-filtering"""
    words = sorted(list(preprocess(text)))
    return frozenset(words[:5])  # Take first 5 sorted keywords as signature


def is_similar(text1: str, text2: str) -> bool:
    """Check semantic similarity between two texts using Jaccard Similarity (excluding stopwords)"""
    # 1️⃣ Check for numerical differences (2 days != 5 days)
    nums1 = set(re.findall(r'\d+', text1))
    nums2 = set(re.findall(r'\d+', text2))
    
    if nums1 != nums2:
        return False

    # 2️⃣ Jaccard Similarity on keywords
    words1 = preprocess(text1)
    words2 = preprocess(text2)
    
    if not words1 or not words2:
        return False
        
    similarity = len(words1 & words2) / len(words1 | words2)
    return similarity > 0.6  # 60% keyword overlap threshold

# Create database tables
Base.metadata.create_all(bind=engine)


# ===== HEALTH CHECK =====

@fastapi_app.get("/")
def root():
    """API health check"""
    return {
        "message": "Grievance Intelligence API v3.0",
        "status": "running",
        "auth": "Firebase",
        "language": "English"
    }


# ===== AUTHENTICATION ROUTES =====

@fastapi_app.post("/auth/firebase", response_model=schemas.AuthResponse)
def firebase_login(request: schemas.FirebaseAuthRequest, db: Session = Depends(get_db)):
    """
    User login with Firebase (Google Sign-in)
    Mobile app sends Firebase ID token
    """
    # Verify Firebase token
    firebase_user = verify_firebase_token(request.id_token)
    
    if not firebase_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token"
        )
    
    # Check if user exists
    user = crud.get_user_by_firebase_uid(db, firebase_user['uid'])
    
    if not user:
        # Create new user
        user = crud.create_user(
            db=db,
            firebase_uid=firebase_user['uid'],
            email=firebase_user['email'],
            name=firebase_user['name'] or firebase_user['email'].split('@')[0]
        )
    
    return schemas.AuthResponse(
        user_id=user.id,
        email=user.email,
        name=user.name,
        role='user',
        profile_completed=user.profile_completed
    )


@fastapi_app.post("/auth/officer/login")
def officer_login(
    form_data: OAuth2PasswordRequestForm = Depends(), 
    db: Session = Depends(get_db)
):
    """
    Officer/Admin login with Form Data compatibility (Swagger UI support)
    """
    email = form_data.username.strip().lower()
    password = form_data.password

    officer = db.query(models.Officer).filter(models.Officer.email == email).first()

    if not officer:
        raise HTTPException(status_code=401, detail="Invalid email")

    # Verify password using security helper
    if not verify_password(password, officer.password_hash):
        raise HTTPException(status_code=401, detail="Invalid password")

    # Determine dynamic role
    role = "admin" if officer.department == "Admin" else "officer"

    # Generate Secure JWT
    token = create_access_token({
        "id": officer.id,
        "role": role,
        "department": officer.department
    })

    return {
        "access_token": token,
        "token_type": "bearer",
        "role": role,
        "officer_id": officer.id,
        "email": officer.email,
        "name": officer.name,
        "department": officer.department
    }


# ===== USER PROFILE ROUTES =====

@fastapi_app.get("/user/profile/{user_id}")
def get_user_profile(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "name": user.name,
        "email": user.email,
        "phone_number": user.phone_number,
        "address": user.address,
        "city": user.city,
        "state": user.state,
        "pincode": user.pincode,
        "dob": str(user.dob) if user.dob else None,
        "aadhaar_number": user.aadhaar_number,
        "profile_completed": user.profile_completed
    }


@fastapi_app.get("/auth/officer/verify")
def verify_officer_token(request: Request, db: Session = Depends(get_db)):
    """
    Verify JWT token validity. Called by Flutter app on startup.
    Returns 200 + officer info if token is valid, 401 if expired/invalid.
    """
    from jose import JWTError, ExpiredSignatureError

    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="No token provided")

    token = auth_header.split(" ", 1)[1]
    try:
        payload = decode_token(token)
        officer_id = payload.get("id")
        if officer_id is None:
            raise HTTPException(status_code=401, detail="Invalid token payload")

        officer = db.query(models.Officer).filter(models.Officer.id == officer_id).first()
        if not officer:
            raise HTTPException(status_code=401, detail="Officer not found")

        return {
            "valid": True,
            "officer_id": officer.id,
            "email": officer.email,
            "name": officer.name,
            "department": officer.department,
        }
    except ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")


# ===== USER PROFILE ROUTES =====

@fastapi_app.get("/user/profile/{user_id}", response_model=schemas.UserProfileResponse)
def get_user_profile(user_id: int, db: Session = Depends(get_db)):
    """Get user profile"""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return user


@fastapi_app.put("/user/profile/{user_id}", response_model=schemas.UserProfileResponse)
def update_profile(user_id: int, profile: schemas.UserProfileUpdate, db: Session = Depends(get_db)):
    """Update user profile"""
    try:
        user = crud.update_user_profile(
            db=db,
            user_id=user_id,
            **profile.dict(exclude_unset=True)
        )
        return user
    except Exception as e:
        if "UniqueViolation" in str(e) or "UNIQUE constraint failed" in str(e):
            raise HTTPException(
                status_code=400,
                detail="Aadhaar number is already registered with another account."
            )
        raise HTTPException(status_code=500, detail=str(e))


# ===== COMPLAINT ROUTES =====

@fastapi_app.post("/complaints/submit", response_model=schemas.ComplaintResponse)
async def submit_complaint(
    complaint: schemas.ComplaintSubmit,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Submit new complaint with AI analysis"""
    user_id = current_user.id
    
    # 🚫 CHECK FOR SUSPENSION
    if current_user.is_suspended:
        raise HTTPException(
            status_code=403,
            detail="Your account has been suspended due to multiple officer reports. You cannot file new complaints."
        )
    
    # ✅ CHECK FOR DUPLICATE UNRESOLVED COMPLAINTS (Last 7 days)
    department = complaint.selected_department
    recent_time = datetime.utcnow() - timedelta(days=7)
    
    # 🚨 RULE: Only one active complaint per department
    existing_active = db.query(Complaint).filter(
        Complaint.user_id == user_id,
        Complaint.selected_department == department,
        Complaint.status.in_(["submitted", "under_review", "in_progress"])
    ).first()

    if existing_active:
        raise HTTPException(
            status_code=409,
            detail=f"You already have an active complaint in {department} "
                   f"(Tracking ID: {existing_active.tracking_id}). "
                   f"Please wait until it is resolved."
        )
    
    # Check for existing unresolved complaint in same department
    existing = db.query(Complaint).filter(
        Complaint.user_id == user_id,
        Complaint.selected_department == department,
        Complaint.status.in_(['submitted', 'under_review', 'in_progress']),
        Complaint.created_at >= recent_time
    ).all()

    new_sig = quick_signature(complaint.text)
    
    for c in existing:
        # Pre-filter: if top keywords are totally different, skip expensive similarity check
        if quick_signature(c.text) != new_sig:
            continue

        if is_similar(c.text, complaint.text):
            raise HTTPException(
                status_code=409,
                detail=f"Similar complaint already exists in {department} (Tracking ID: {c.tracking_id}). "
                       f"Please wait for resolution or check 'My Complaints'."
            )
    
    # Run AI analysis
    ai_result = analyze_complaint(complaint.text, complaint.selected_department)
    
    # Create complaint in database
    new_complaint = crud.create_complaint(
        db=db,
        user_id=user_id,
        text=complaint.text,
        selected_department=complaint.selected_department,
        ai_result=ai_result,
        latitude=complaint.latitude,
        longitude=complaint.longitude,
        location_address=complaint.location_address,
        incident_location=complaint.incident_location
    )
    
    db.commit()
    
    # Send Notifications
    if new_complaint.user_id:
        user = db.query(models.User).filter(models.User.id == new_complaint.user_id).first()
        
        # Real-time WebSocket notification
        await notify_user(
            db=db,
            user_id=new_complaint.user_id,
            complaint_id=new_complaint.id,
            title="Complaint Submitted",
            message=f"Your complaint {new_complaint.tracking_id} has been registered successfully.",
            notification_type="submission"
        )
        
        # Push notification
        if user and user.fcm_token:
            send_push_notification(
                user.fcm_token,
                "Complaint Submitted",
                f"Your complaint {new_complaint.tracking_id} has been registered"
            )
    
    # Send Email Notification
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user and user.email:
        await send_email(
            user.email,
            "Complaint Submitted Successfully",
            f"""
            <h2>Dear {user.name},</h2>
            <p>Your complaint has been successfully submitted.</p>
            <p><strong>Tracking ID:</strong> {new_complaint.tracking_id}</p>
            <p><strong>Department:</strong> {new_complaint.selected_department}</p>
            <p><strong>Category:</strong> {new_complaint.ai_category}</p>
            <p><strong>Urgency:</strong> {new_complaint.ai_urgency}</p>
            <p>You will receive updates via email.</p>
            <br>
            <p>Thank you for using Grievance Intelligence System.</p>
            """
        )
    
    # Trigger Admin Dashboard Update (Real-time)
    await broadcast_dashboard_update()
    
    return new_complaint




@fastapi_app.get("/complaints/user/{user_id}")
async def get_user_complaints(user_id: int, db: Session = Depends(get_db)):
    """Get all complaints for a specific user"""
    
    complaints = db.query(Complaint).filter(
        Complaint.user_id == user_id
    ).order_by(Complaint.created_at.desc()).all()
    
    if not complaints:
        return []
    
    result = []
    for complaint in complaints:
        # Get officer info
        officer = None
        if complaint.assigned_officer_id:
            officer_data = db.query(Officer).filter(
                Officer.id == complaint.assigned_officer_id
            ).first()
            if officer_data:
                officer = {
                    "id": officer_data.id,
                    "name": officer_data.name,
                    "email": officer_data.email,
                    "department": officer_data.department
                }
        
        # Get latest update
        latest_update = db.query(ComplaintUpdate).filter(
            ComplaintUpdate.complaint_id == complaint.id
        ).order_by(ComplaintUpdate.created_at.desc()).first()
        
        result.append({
            "id": complaint.id,
            "tracking_id": complaint.tracking_id,
            "text": complaint.text,
            "selected_department": complaint.selected_department,
            "ai_category": complaint.ai_category,
            "ai_department": complaint.ai_department,
            "ai_urgency": complaint.ai_urgency,
            "status": complaint.status,
            "image_path": complaint.image_path,
            "audio_path": complaint.audio_path,
            "latitude": complaint.latitude,
            "longitude": complaint.longitude,
            "location_address": complaint.location_address,  # ✅ FIXED
            "delay_risk_label": complaint.delay_risk_label,
            "priority_label": complaint.priority_label,
            "priority_score": complaint.priority_score,
            "created_at": format_iso(complaint.created_at),
            "assigned_officer_id": complaint.assigned_officer_id,
            "officer": officer,
            "latest_update": {
                "update_text": latest_update.update_text if latest_update else None,
                "created_at": format_iso(latest_update.created_at) if latest_update else None
            } if latest_update else None
        })
    
    return result


@fastapi_app.post("/complaints/{complaint_id}/upload-image")
async def upload_complaint_image(
    complaint_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Authenticated image upload for valid complaints"""
    try:
        # Check for directory existence
        UPLOAD_DIR = "static/complaint_images"
        os.makedirs(UPLOAD_DIR, exist_ok=True)

        complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
        if not complaint:
            raise HTTPException(status_code=404, detail="Complaint not found")
        
        # Create filename
        file_extension = file.filename.split('.')[-1]
        file_name = f"complaint_{complaint_id}_{int(time.time())}.{file_extension}"
        file_path = f"static/complaint_images/{file_name}"
        
        # Save file
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # Update database
        complaint.image_path = file_path
        db.commit()
        
        return {
            "message": "Image uploaded successfully",
            "image_path": file_path,
            "url": f"/{file_path}"
        }
    except Exception as e:
        print(f"❌ Image Upload Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@fastapi_app.post("/complaints/{complaint_id}/upload-audio")
async def upload_complaint_audio(
    complaint_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Authenticated audio upload for valid complaints"""
    try:
        # Check for directory existence
        UPLOAD_DIR = "static/complaint_audio"
        os.makedirs(UPLOAD_DIR, exist_ok=True)

        complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
        if not complaint:
            raise HTTPException(status_code=404, detail="Complaint not found")
        
        # Create filename
        file_extension = file.filename.split('.')[-1]
        file_name = f"audio_{complaint_id}_{int(time.time())}.{file_extension}"
        file_path = f"static/complaint_audio/{file_name}"
        
        # Save file
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # Update database
        complaint.audio_path = file_path
        db.commit()
        
        return {
            "message": "Audio uploaded successfully",
            "audio_path": file_path,
            "url": f"/{file_path}"
        }
    except Exception as e:
        print(f"❌ Audio Upload Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@fastapi_app.get("/complaints/my/{user_id}")
def get_my_complaints(user_id: int, db: Session = Depends(get_db)):
    """Get all complaints for a user"""
    complaints = crud.get_user_complaints(db, user_id)
    return complaints


@fastapi_app.get("/user/stats/{user_id}")
def get_user_stats(user_id: int, db: Session = Depends(get_db)):
    """Get complaint statistics for a specific user"""
    return crud.get_user_stats(db, user_id)


@fastapi_app.post("/complaints/{complaint_id}/cancel")
def cancel_complaint(complaint_id: int, user_id: int, db: Session = Depends(get_db)):
    """Soft-delete a complaint by setting status to 'cancelled'"""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found")
    if complaint.user_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    if complaint.status != "submitted":
        raise HTTPException(status_code=400, detail="Cannot cancel assigned complaint")

    complaint.status = "cancelled"
    db.commit()
    return {"message": "Complaint cancelled successfully"}


@fastapi_app.post("/complaints/{complaint_id}/finish")
def finish_complaint(complaint_id: int, user_id: int, db: Session = Depends(get_db)):
    """Mark a complaint as resolved by the user"""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found")
    if complaint.user_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    complaint.status = "closed_by_user"
    db.commit()
    return {"message": "Complaint marked as finished"}


@fastapi_app.get("/user/notifications/{user_id}")
@fastapi_app.get("/notifications/{user_id}")
def get_user_notifications(user_id: int, db: Session = Depends(get_db)):
    notifications = db.query(Notification).filter(
        Notification.user_id == user_id
    ).order_by(Notification.created_at.desc()).all()

    return [
        {
            "id": n.id,
            "title": n.title,
            "message": n.message,
            "is_read": n.is_read,
            "created_at": format_iso(n.created_at),
            "complaint_id": n.complaint_id,
            "notification_type": n.notification_type
        }
        for n in notifications
    ]

@fastapi_app.get("/notifications/{user_id}/unread")
def get_unread_notifications(user_id: int, db: Session = Depends(get_db)):
    notifications = db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.is_read == False
    ).order_by(Notification.created_at.desc()).all()

    return [
        {
            "id": n.id,
            "title": n.title,
            "message": n.message,
            "is_read": n.is_read,
            "created_at": format_iso(n.created_at),
            "complaint_id": n.complaint_id,
            "notification_type": n.notification_type
        }
        for n in notifications
    ]

@fastapi_app.get("/notifications/{user_id}/unread-count")
def get_unread_notification_count(user_id: int, db: Session = Depends(get_db)):
    count = db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.is_read == False
    ).count()
    return {"unread_count": count}


@fastapi_app.put("/notifications/mark-chat-read/{user_id}/{complaint_id}")
def mark_chat_notifications_read(user_id: int, complaint_id: int, db: Session = Depends(get_db)):
    """Mark all chat-related notifications for a specific complaint as read"""
    db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.complaint_id == complaint_id,
        Notification.notification_type == "chat"
    ).update({Notification.is_read: True})
    db.commit()
    return {"message": "Chat notifications marked as read"}


@fastapi_app.put("/notifications/{notification_id}/read")
def mark_notification_read(notification_id: int, db: Session = Depends(get_db)):
    notification = db.query(Notification).filter(Notification.id == notification_id).first()

    if notification:
        notification.is_read = True
        db.commit()
        return {"message": "Marked as read"}

    raise HTTPException(status_code=404, detail="Notification not found")
 
 
@fastapi_app.get("/officer/stats/{officer_id}")
@fastapi_app.get("/officer/dashboard/{officer_id}")
def get_officer_dashboard_stats(officer_id: int, db: Session = Depends(get_db)):
    """Fetch dashboard statistics and recent complaints for a specific officer"""
    # Group 1: Active, Group 2: Resolved, Group 3: Closed by User
    status_order = case(
        (Complaint.status.in_(['in_progress', 'under_review', 'submitted']), 0),
        (Complaint.status == 'resolved', 1),
        (Complaint.status == 'closed_by_user', 2),
        else_=3
    )

    # Priority Label Sequence
    priority_order = case(
        (Complaint.priority_label == 'Critical', 0),
        (Complaint.priority_label == 'High', 1),
        (Complaint.priority_label == 'Medium', 2),
        (Complaint.priority_label == 'Low', 3),
        else_=4
    )

    # Fetch complaints assigned to this officer with UNIFIED sorting
    complaints = db.query(Complaint).filter(
        Complaint.assigned_officer_id == officer_id
    ).order_by(status_order.asc(), priority_order.asc(), Complaint.created_at.desc()).all()

    # Calculate counts
    total = len(complaints)
    pending = len([c for c in complaints if c.status in ["submitted", "under_review"]])
    in_progress = len([c for c in complaints if c.status == "in_progress"])
    resolved = len([c for c in complaints if c.status == "resolved"])

    # Format recent complaints for the dashboard
    recent = []
    for c in complaints[:10]: # Increased to 10 for better visibility
        recent.append({
            "id": c.id,
            "tracking_id": c.tracking_id,
            "text": c.text,
            "status": c.status,
            "department": c.selected_department,
            "priority_label": c.priority_label,
            "created_at": format_iso(c.created_at) if c.created_at else None
        })

    # Fetch latest activity (last status update)
    latest_update = db.query(models.ComplaintUpdate).filter(
        models.ComplaintUpdate.officer_id == officer_id
    ).order_by(models.ComplaintUpdate.created_at.desc()).first()
    
    last_activity_at = format_iso(latest_update.created_at) if latest_update else None

    return {
        "total_complaints": total,
        "pending_complaints": pending,
        "in_progress_complaints": in_progress,
        "resolved_complaints": resolved,
        "total": total,
        "pending": pending,
        "in_progress": in_progress,
        "resolved": resolved,
        "recent_complaints": recent,
        "last_activity_at": last_activity_at
    }


@fastapi_app.get("/officer/stats")
def get_officer_stats_legacy(user=Depends(get_current_officer), db: Session = Depends(get_db)):
    """Get personal performance stats based on department (Officers Only)"""
    if user["role"] not in ["officer", "admin"]:
        raise HTTPException(status_code=403, detail="Operational access required")
        
    return crud.get_complaint_stats(db, user["department"])


@fastapi_app.get("/admin/stats")
def get_admin_stats(user=Depends(get_current_officer), db: Session = Depends(get_db)):
    """Get global system statistics (Admins Only)"""
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Administrative access required")
    return crud.get_admin_stats(db)


@fastapi_app.get("/admin/department-stats")
def get_department_stats(user=Depends(get_current_officer), db: Session = Depends(get_db)):
    """Get complaint metrics broken down by department (Admins Only)"""
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Administrative access required")
    return crud.get_department_stats(db)


@fastapi_app.get("/admin/top-problems")
def get_top_problems(user=Depends(get_current_officer), db: Session = Depends(get_db)):
    """Identify bottleneck departments (Admins Only)"""
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Administrative access required")
    return crud.get_top_problem_departments(db)


@fastapi_app.get("/admin/officers")
def get_all_officers(user=Depends(get_current_officer), db: Session = Depends(get_db)):
    """Get all registered government officers (Admins Only)"""
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Administrative access required")
    return crud.get_all_officers(db)


@fastapi_app.delete("/admin/delete-officer/{officer_id}")
def delete_officer(officer_id: int, user=Depends(get_current_officer), db: Session = Depends(get_db)):
    """Admin removes an officer account (Admins Only)"""
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Administrative access required")
        
    officer = db.query(models.Officer).filter(models.Officer.id == officer_id).first()

    if not officer:
        raise HTTPException(status_code=404, detail="Officer not found")

    db.delete(officer)
    db.commit()

    return {"message": "Officer deleted successfully"}


@fastapi_app.post("/admin/create-officer")
def create_officer(
    request: schemas.OfficerCreate, 
    user=Depends(get_current_officer), 
    db: Session = Depends(get_db)
):
    """Admin creates a new officer account (Admins Only)"""
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Administrative access required")

    # Check if email exists
    existing = db.query(models.Officer).filter(models.Officer.email == request.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    # Hash the password
    hashed_password = get_password_hash(request.password)

    new_officer = models.Officer(
        name=request.name,
        email=request.email,
        employee_id=request.employee_id,
        department=request.department,
        password_hash=hashed_password
    )

    db.add(new_officer)
    db.commit()
    db.refresh(new_officer)

    return {
        "id": new_officer.id,
        "name": new_officer.name,
        "department": new_officer.department,
        "message": "Officer account created successfully"
    }


@fastapi_app.get("/complaints/{complaint_id}")
def get_complaint_detail(complaint_id: int, db: Session = Depends(get_db)):
    """Get complaint details with updates"""
    complaint = crud.get_complaint_by_id(db, complaint_id)
    
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found")
    
    # Get updates
    updates = db.query(models.ComplaintUpdate).filter(
        models.ComplaintUpdate.complaint_id == complaint_id
    ).order_by(models.ComplaintUpdate.created_at.desc()).all()
    
    return {
        "complaint": complaint,
        "updates": updates,
        "assigned_officer": complaint.assigned_officer.name if complaint.assigned_officer else None,
        "user": {
            "name": complaint.user.name,
            "email": complaint.user.email,
            "phone_number": complaint.user.phone_number,
            "aadhaar_number": complaint.user.aadhaar_number,
            "aadhaar_image_path": complaint.user.aadhaar_image_path
        }
    }


# ===== OFFICER ROUTES =====

# Removed duplicate route


@fastapi_app.get("/officer/complaints/{officer_id}")
def get_officer_complaints(
    officer_id: int,
    assigned_only: bool = False,
    status: Optional[str] = None,
    search: Optional[str] = None,
    priority: Optional[str] = None,
    sort_by: str = "priority",
    db: Session = Depends(get_db)
):
    """Get complaints for officer"""
    from models import Officer
    officer = db.query(Officer).filter(Officer.id == officer_id).first()
    
    if not officer:
        raise HTTPException(status_code=404, detail="Officer not found")
    
    complaints = crud.get_complaints_for_officer(
        db=db,
        department=officer.department,
        officer_id=officer_id,   # Always pass → ensures assigned complaints always show
        status=status,
        search=search,
        priority=priority,
        sort_by=sort_by
    )
    
    return complaints





@fastapi_app.put("/officer/complaints/{id}/update")
async def update_complaint_status(
    id: int,
    update_data: ComplaintStatusUpdate,  # ✅ Use Pydantic model
    db: Session = Depends(get_db)
):
    """Update complaint status by officer"""
    # Get complaint
    complaint = db.query(Complaint).filter(Complaint.id == id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found")
    
    # Track status change
    old_status = complaint.status
    
    # Update status
    complaint.status = update_data.status
    
    # Set resolved_at if status is resolved
    if update_data.status == 'resolved':
        from datetime import datetime
        complaint.resolved_at = datetime.utcnow()
    
    # Save update record
    complaint_update = ComplaintUpdate(
        complaint_id=id,
        officer_id=update_data.officer_id,
        status_changed_from=old_status,
        status_changed_to=update_data.status,
        update_text=update_data.update_text
    )
    db.add(complaint_update)
    
    # Assign officer if not assigned
    if not complaint.assigned_officer_id:
        complaint.assigned_officer_id = update_data.officer_id
    
    db.commit()
    db.refresh(complaint)
    
    # Send real-time notification to user
    await notify_user(
        db=db,
        user_id=complaint.user_id,
        complaint_id=id,
        title=f"Complaint {complaint.tracking_id} Updated",
        message=f"Status: {update_data.status}. {update_data.update_text}",
        notification_type="status_update"
    )
    
    # Send email notification asynchronously
    try:
        user = db.query(User).filter(User.id == complaint.user_id).first()
        if user and user.email:
            # Format status for email
            display_status = update_data.status.replace("_", " ").title()
            await send_email(
                user.email,
                f"Complaint {complaint.tracking_id} Updated",
                f"<h2>Dear {user.name},</h2><p>Your complaint status has been updated to: <b>{display_status}</b>.</p><p>Update: {update_data.update_text}</p>"
            )
    except Exception as e:
        print(f"Email error: {e}")
    
    # Trigger Admin Dashboard Update (Real-time)
    await broadcast_dashboard_update()
    
    return {"success": True, "message": "Status updated successfully"}


# ===== USER REPORTING & SUSPENSION ROUTES =====

@fastapi_app.post("/officer/user/{user_id}/report")
async def report_user_endpoint(
    user_id: int, 
    officer_id: int, 
    reason: Optional[str] = None, 
    db: Session = Depends(get_db)
):
    """Officer reporting a problematic user"""
    result = crud.report_user(db, user_id, officer_id, reason)
    if not result.get("success"):
        raise HTTPException(status_code=400, detail=result.get("message"))
    return result

@fastapi_app.post("/officer/user/{user_id}/lift-suspension")
async def lift_suspension_endpoint(user_id: int, db: Session = Depends(get_db)):
    """Officer lifting user suspension"""
    success = crud.lift_suspension(db, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="User not found")
    return {"success": True, "message": "Suspension lifted successfully"}


# ===== NOTIFICATION ROUTES =====

@fastapi_app.get("/notifications/{user_id}")
def get_notifications(user_id: int, unread_only: bool = False, db: Session = Depends(get_db)):
    """Get user notifications"""
    notifications = crud.get_user_notifications(db, user_id, unread_only)
    return notifications


@fastapi_app.put("/notifications/{notification_id}/read")
def mark_read(notification_id: int, db: Session = Depends(get_db)):
    """Mark notification as read"""
    notification = crud.mark_notification_read(db, notification_id)
    return {"message": "Notification marked as read", "notification": notification}


@fastapi_app.get("/notifications/{user_id}/unread-count")
def unread_count(user_id: int, db: Session = Depends(get_db)):
    """Get unread notification count"""
    count = crud.get_unread_count(db, user_id)
    return {"unread_count": count}

@fastapi_app.get("/user/{user_id}/profile")
def get_user_profile(user_id: int, db: Session = Depends(get_db)):
    """Fetch profile details for a citizen (Officers/Admins only)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "phone_number": user.phone_number,
        "address": user.address,
        "city": user.city,
        "state": user.state,
        "pincode": user.pincode,
        "dob": user.dob.isoformat() if user.dob else None,
        "aadhaar_number": user.aadhaar_number,
        "aadhaar_image_path": user.aadhaar_image_path,
        "profile_completed": user.profile_completed,
        "created_at": format_iso(user.created_at)
    }

# ===== RATING ROUTES =====

@fastapi_app.post("/complaints/{complaint_id}/rate")
async def rate_complaint(
    complaint_id: int,
    user_id: int,
    rating_data: schemas.RatingSubmit,
    db: Session = Depends(get_db)
):
    """Submit a rating for a resolved complaint"""
    from models import ComplaintRating
    
    complaint = db.query(models.Complaint).filter(models.Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found")
    
    if complaint.status != 'resolved':
        raise HTTPException(status_code=400, detail="Only resolved complaints can be rated")
    
    # Check if already rated
    existing = db.query(ComplaintRating).filter(ComplaintRating.complaint_id == complaint_id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Complaint already rated")
    
    # Create rating
    new_rating = ComplaintRating(
        complaint_id=complaint_id,
        user_id=user_id,
        rating=rating_data.rating,
        feedback=rating_data.feedback
    )
    db.add(new_rating)
    db.commit()
    db.refresh(new_rating)
    
    # Send email to assigned officer about rating received
    if complaint.assigned_officer_id:
        officer = db.query(models.Officer).filter(models.Officer.id == complaint.assigned_officer_id).first()
        if officer and officer.email:
            await send_email(
                officer.email,
                f"Rating Received - {complaint.tracking_id}",
                f"""
                <h2>Hello {officer.name},</h2>
                <p>A user has rated your resolution for complaint <strong>{complaint.tracking_id}</strong>.</p>
                <p><strong>Rating:</strong> {'⭐' * rating_data.rating} ({rating_data.rating}/5)</p>
                <p><strong>Feedback:</strong> {rating_data.feedback or 'No feedback provided'}</p>
                <br>
                <p>Thank you for your service.</p>
                """
            )
    
    return {"message": "Rating submitted successfully", "rating": new_rating}


# ===== ANALYTICS ROUTES (from old system) =====

@fastapi_app.get("/analytics/summary")
async def get_analytics_summary(db: Session = Depends(get_db)):
    """Get system-wide analytics - REAL DATA"""
    from sqlalchemy import func
    
    # REAL counts from database
    total_complaints = db.query(Complaint).count()
    total_users = db.query(User).filter(User.profile_completed == True).count()
    total_officers = db.query(Officer).count()
    
    # Status breakdown (matching database lowercase convention)
    pending = db.query(Complaint).filter(Complaint.status == 'submitted').count()
    in_progress = db.query(Complaint).filter(
        Complaint.status.in_(['under_review', 'in_progress'])
    ).count()
    resolved = db.query(Complaint).filter(Complaint.status == 'resolved').count()
    
    # Department breakdown (dynamic)
    departments = crud.get_department_stats(db)
    
    # Category breakdown (dynamic)
    cat_counts = (
        db.query(Complaint.ai_category, func.count(Complaint.ai_category))
        .group_by(Complaint.ai_category)
        .all()
    )
    categories = {cat: count for cat, count in cat_counts if cat}
    
    # Urgency breakdown (dynamic)
    urg_counts = (
        db.query(Complaint.ai_urgency, func.count(Complaint.ai_urgency))
        .group_by(Complaint.ai_urgency)
        .all()
    )
    urgency = {urg: count for urg, count in urg_counts if urg}
    
    # Coordinates for Map (limited to last 100 for performance)
    # Status filter: only active (submitted, under_review, in_progress) and resolved
    locations = (
        db.query(
            Complaint.latitude, 
            Complaint.longitude, 
            Complaint.tracking_id,
            Complaint.selected_department,
            Complaint.status,
            User.name,
            Complaint.text
        )
        .join(User, Complaint.user_id == User.id)
        .filter(
            Complaint.latitude.isnot(None), 
            Complaint.longitude.isnot(None),
            Complaint.status.in_(['submitted', 'under_review', 'in_progress', 'resolved', 'closed_by_user'])
        )
        .order_by(Complaint.created_at.desc())
        .limit(100)
        .all()
    )
    complaint_locations = [
        {
            "lat": loc[0], 
            "lng": loc[1], 
            "id": loc[2],
            "dept": loc[3],
            "status": loc[4],
            "user": loc[5],
            "desc": loc[6]
        } for loc in locations
    ]
    
    # Average rating from ComplaintRating
    avg_rating_query = db.query(func.avg(ComplaintRating.rating)).scalar()
    avg_rating = float(avg_rating_query) if avg_rating_query else 0
    
    # Temporal Trends (Last 7 days)
    from datetime import datetime, timedelta
    trends = []
    for i in range(6, -1, -1):
        date = (datetime.utcnow() - timedelta(days=i)).date()
        count = db.query(Complaint).filter(
            func.date(Complaint.created_at) == date
        ).count()
        trends.append({
            "date": date.strftime("%b %d"),
            "count": count
        })

    return {
        "total": total_complaints,
        "users": total_users,
        "officers": total_officers,
        "status_breakdown": {
            "pending": pending,
            "in_progress": in_progress,
            "resolved": resolved
        },
        "by_department": departments,
        "by_category": categories,
        "by_urgency": urgency,
        "complaint_locations": complaint_locations,
        "temporal_trends": trends,
        "avg_rating": round(avg_rating, 2),
        "resolution_rate": round((resolved / total_complaints * 100) if total_complaints > 0 else 0, 1)
    }


@fastapi_app.get("/admin/department/{dept_name}/stats")
def get_department_specific_stats(dept_name: str, db: Session = Depends(get_db)):
    """Detailed analytics for a specific department"""
    from sqlalchemy import func
    
    # 1. Status Breakdown for this dept
    status_counts = (
        db.query(Complaint.status, func.count(Complaint.id))
        .filter(Complaint.selected_department == dept_name)
        .group_by(Complaint.status)
        .all()
    )
    status_dict = {s: c for s, c in status_counts}
    
    # 2. Total and Resolved
    total = sum(status_dict.values())
    resolved = status_dict.get('resolved', 0)
    
    # 3. Category Breakdown
    cat_counts = (
        db.query(Complaint.ai_category, func.count(Complaint.id))
        .filter(Complaint.selected_department == dept_name)
        .group_by(Complaint.ai_category)
        .all()
    )
    categories = {cat: count for cat, count in cat_counts if cat}
    
    # 4. Average Rating
    avg_rating = (
        db.query(func.avg(ComplaintRating.rating))
        .join(Complaint, ComplaintRating.complaint_id == Complaint.id)
        .filter(Complaint.selected_department == dept_name)
        .scalar()
    ) or 0
    
    return {
        "department": dept_name,
        "total_complaints": total,
        "status_breakdown": status_dict,
        "categories": categories,
        "average_rating": round(float(avg_rating), 2)
    }


@fastapi_app.get("/admin/department/{dept_name}/top-officers")
def get_top_performing_officers(dept_name: str, db: Session = Depends(get_db)):
    """Return top performing officers for a department"""
    return crud.get_top_officers_by_department(db, dept_name)

@fastapi_app.post("/admin/officers/create")
def admin_create_officer(request: schemas.OfficerCreateMinimal, db: Session = Depends(get_db)):
    """Endpoint for admin to create officer"""
    return crud.create_officer_minimal(db, request.name, request.email, request.employee_id, request.department, request.password)

@fastapi_app.delete("/admin/officers/{officer_id}")
def admin_delete_officer(officer_id: int, db: Session = Depends(get_db)):
    """Endpoint for admin to delete officer"""
    success = crud.delete_officer(db, officer_id)
    if not success:
        raise HTTPException(status_code=404, detail="Officer not found")
    return {"success": True}


@fastapi_app.post("/officer/profile/update")
def officer_update_profile(
    request: schemas.OfficerProfileUpdate, 
    current_officer: dict = Depends(get_current_officer), 
    db: Session = Depends(get_db)
):
    """Officer updates their profile"""
    updated_officer = crud.update_officer_profile(
        db=db,
        officer_id=current_officer['id'],
        name=request.name,
        department=request.department,
        phone_number=request.phone_number,
        designation=request.designation,
        govt_id_path=request.govt_id_path
    )
    if not updated_officer:
        raise HTTPException(status_code=404, detail="Officer not found")
    
    return {"message": "Profile updated successfully", "profile_completed": True}


# ===== ADMIN ROUTES =====

@fastapi_app.post("/auth/admin/login", response_model=schemas.AuthResponse)
def admin_login(request: schemas.AdminLoginRequest, db: Session = Depends(get_db)):
    """
    Admin login (currently using officer table)
    """
    # For now, we use the officer table for admin access
    # In a real system, there would be an 'is_admin' flag or a separate table
    officer = crud.get_officer_by_email(db, request.email)
    
    if not officer or not crud.verify_officer_password(request.password, officer.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin credentials"
        )
    
    return schemas.AuthResponse(
        user_id=officer.id,
        email=officer.email,
        name=officer.name,
        role='admin',  # Hardcoded role for this endpoint
        department=officer.department
    )


@fastapi_app.get("/admin/analytics/system", response_model=schemas.SystemAnalyticsResponse)
def get_system_analytics(db: Session = Depends(get_db)):
    """Return system-wide stats"""
    return crud.get_system_analytics(db)


@fastapi_app.get("/admin/users")
def get_all_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Return all users"""
    return crud.get_all_users(db, skip, limit)


@fastapi_app.get("/admin/officers")
def get_all_officers(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Return all officers"""
    return crud.get_all_officers(db, skip, limit)


@fastapi_app.get("/admin/dashboard-summary")
def get_admin_dashboard_summary(db: Session = Depends(get_db)):
    """
    Consolidated endpoint for Admin Dashboard.
    Returns basic stats, department metrics, top problems, and officer list in ONE call.
    """
    # 1. Basic Stats
    stats = crud.get_admin_stats(db)
    
    # 2. Department Stats
    dept_stats = crud.get_department_stats(db)
    
    # 3. Top Problems
    top_problems = crud.get_top_problem_departments(db)
    
    # 4. Officers List
    officers = crud.get_all_officers(db)
    
    # 5. System Analytics (Users/Officers counts)
    system_analytics = crud.get_system_analytics(db)
    
    return {
        "stats": stats,
        "department_stats": dept_stats,
        "top_problems": top_problems,
        "officers": officers,
        "system_analytics": system_analytics,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


@fastapi_app.get("/admin/complaints/all")
def get_all_complaints(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Return all complaints (not filtered by officer)"""
    return crud.get_all_complaints(db, skip, limit)


@fastapi_app.get("/admin/complaints/{complaint_id}", response_model=schemas.ComplaintDetail)
def get_admin_complaint_detail(complaint_id: int, db: Session = Depends(get_db)):
    """Get full complaint details including timeline and user info"""
    detail = crud.get_complaint_detail(db, complaint_id)
    if not detail:
        raise HTTPException(status_code=404, detail="Complaint not found")
    return detail


@fastapi_app.get("/admin/export/complaints")
def export_complaints_csv(db: Session = Depends(get_db)):
    """Export all complaints to CSV file"""
    complaints = db.query(Complaint).order_by(Complaint.created_at.desc()).all()
    
    output = io.StringIO()
    writer = csv.writer(output)
    
    # Header
    writer.writerow([
        "Tracking ID", "Status", "Department", "Urgency", 
        "Description", "Created At", "Resolved At", 
        "Location", "Citizen Name"
    ])
    
    for c in complaints:
        writer.writerow([
            c.tracking_id,
            c.status,
            c.selected_department,
            c.ai_urgency,
            c.text,
            c.created_at.strftime("%Y-%m-%d %H:%M:%S") if c.created_at else "",
            c.resolved_at.strftime("%Y-%m-%d %H:%M:%S") if c.resolved_at else "",
            c.location_address,
            c.user.name if c.user else "Citizen"
        ])
    
    output.seek(0)
    
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=complaints_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"}
    )


@fastapi_app.put("/admin/settings")
def update_system_settings(settings: dict, db: Session = Depends(get_db)):
    """Update global system settings and log to terminal"""
    print(f"\n⚙️  [SYSTEM_SETTINGS] Update received from Admin:")
    print(f"   - AI Auto-Assignment: {'ENABLED' if settings.get('auto_assignment') else 'DISABLED'}")
    print(f"   - Maintenance Mode: {'ACTIVE' if settings.get('maintenance_mode') else 'INACTIVE'}")
    print(f"   - Admin Email: {settings.get('system_email')}")
    print(f"   - Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    return {"status": "success", "message": "Settings updated and logged"}


# Multimedia
UPLOAD_DIR = "static/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@fastapi_app.post("/upload/image")
async def upload_image(file: UploadFile = File(...)):
    """General image upload for complaints or chat"""
    file_extension = file.filename.split('.')[-1]
    file_name = f"img_{int(time.time())}.{file_extension}"
    file_path = f"{UPLOAD_DIR}/{file_name}"

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Determine the base URL for public links (default to localhost for dev)
    base_url = os.getenv("BASE_URL", "http://127.0.0.1:8000")
    
    return {
        "file_path": file_path,
        "url": f"{base_url}/{file_path}"
    }


# Audio
@fastapi_app.post("/complaints/{complaint_id}/upload-audio")
async def upload_complaint_audio(
    complaint_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    try:
        complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
        if not complaint:
            raise HTTPException(status_code=404, detail="Complaint not found")
        
        # Save file
        file_extension = file.filename.split('.')[-1]
        file_name = f"audio_{complaint_id}_{int(time.time())}.{file_extension}"
        file_path = f"static/audio_complaints/{file_name}"
        
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # Update complaint
        complaint.audio_path = file_path
        db.commit()
        
        # Determine the base URL for public links
        base_url = os.getenv("BASE_URL", "http://127.0.0.1:8000")

        return {
            "message": "Audio uploaded successfully",
            "audio_path": file_path,
            "audio_url": f"{base_url}/{file_path}"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@fastapi_app.get("/complaints/{complaint_id}/audio")
async def get_complaint_audio(complaint_id: int, db: Session = Depends(get_db)):
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint or not complaint.audio_path:
        raise HTTPException(status_code=404, detail="Audio not found")
    
    # Determine the base URL for public links
    base_url = os.getenv("BASE_URL", "http://127.0.0.1:8000")

    return {
        "audio_url": f"{base_url}/{complaint.audio_path}",
        "duration": complaint.audio_duration
    }


# ===== CHAT & REAL-TIME WEBSOCKETS =====

# Store active connections and presence info at module level
connections: dict = {}   # {complaint_id: set[WebSocket]}
presence:    dict = {}   # {complaint_id: {sender_type: {online, last_seen}}}


# ─── Helper ────────────────────────────────────────────────────────────────────

async def _broadcast(complaint_id: int, payload: str, exclude: "WebSocket | None" = None):
    """Send payload to every live socket in the room, pruning dead ones."""
    dead = set()
    for conn in list(connections.get(complaint_id, [])):
        if conn is exclude:
            continue
        try:
            await conn.send_text(payload)
        except Exception:
            dead.add(conn)
    if dead:
        connections[complaint_id] -= dead
        if not connections[complaint_id]:
            connections.pop(complaint_id, None)


# ─── WebSocket endpoint ────────────────────────────────────────────────────────

@fastapi_app.websocket("/ws/chat/{complaint_id}")
async def websocket_chat(
    websocket: WebSocket,
    complaint_id: int,
    db: Session = Depends(get_db),
):
    """
    Real-time room-based chat.

    Incoming message types (JSON):
      • Regular message  : {sender_id, sender_type, message}
      • Typing           : {type: "typing"|"stop_typing", sender_type, is_typing?}
      • Status ack       : {type: "status_update", status: "delivered"|"read",
                            sender_type, message_id?}
      • Presence         : {type: "presence", sender_type, status: "online"|"offline"}

    Outgoing message types broadcast to the room:
      • Regular message  : {id, sender_id, sender_type, message, timestamp, status:"sent"}
      • Typing           : {type:"typing", sender_type, is_typing}
      • Status update    : {type:"status_update", complaint_id, status, reader_type,
                            message_id?}
      • Presence         : {type:"presence", sender_type, online, last_seen}
    """
    await websocket.accept()

    # Register connection
    connections.setdefault(complaint_id, set()).add(websocket)

    # Announce this socket's presence to the room (we don't know sender_type yet;
    # client should immediately send a presence packet after connecting)
    sender_type_hint: str = "unknown"

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = _json.loads(raw)
            except Exception:
                continue

            msg_type    = data.get("type")
            sender_type = data.get("sender_type", sender_type_hint)
            sender_type_hint = sender_type  # remember for cleanup

            # ── PRESENCE ─────────────────────────────────────────────────────
            if msg_type == "presence":
                online    = data.get("status", "online") == "online"
                last_seen = format_iso(datetime.now(timezone.utc))

                presence.setdefault(complaint_id, {})[sender_type] = {
                    "online":    online,
                    "last_seen": last_seen,
                }

                pkt = _json.dumps({
                    "type":        "presence",
                    "sender_type": sender_type,
                    "online":      online,
                    "last_seen":   last_seen,
                })
                await _broadcast(complaint_id, pkt, exclude=websocket)
                continue

            # ── TYPING ───────────────────────────────────────────────────────
            if msg_type in ("typing", "stop_typing"):
                is_typing = data.get("is_typing", msg_type == "typing")
                pkt = _json.dumps({
                    "type":        "typing",
                    "sender_type": sender_type,
                    "is_typing":   is_typing,
                })
                # Relay to others in the room
                await _broadcast(complaint_id, pkt, exclude=websocket)
                continue

            # ── STATUS ACK (delivered / read) ─────────────────────────────────
            if msg_type == "status_update":
                status     = data.get("status", "delivered")   # "delivered" or "read"
                message_id = data.get("message_id")            # optional

                # Persist "read" in DB
                if status == "read" and message_id:
                    try:
                        msg_obj = db.query(ChatMessage).filter(ChatMessage.id == message_id).first()
                        if msg_obj:
                            msg_obj.is_read = True
                            db.commit()
                    except Exception as e:
                        print(f"⚠️ DB read-ack error: {e}")
                        db.rollback()
                elif status == "read":
                    # Bulk-mark all messages from the opposite party as read
                    opposite = "officer" if sender_type == "user" else "user"
                    try:
                        db.query(ChatMessage).filter(
                            ChatMessage.complaint_id == complaint_id,
                            ChatMessage.sender_type  == opposite,
                            ChatMessage.is_read      == False,
                        ).update({"is_read": True})
                        db.commit()
                    except Exception as e:
                        print(f"⚠️ Bulk read-ack error: {e}")
                        db.rollback()

                # Relay to all other sockets so sender sees tick update
                relay = _json.dumps({
                    "type":        "status_update",
                    "complaint_id": complaint_id,
                    "status":      status,
                    "reader_type": sender_type,
                    **({"message_id": message_id} if message_id else {}),
                })
                await _broadcast(complaint_id, relay, exclude=websocket)
                continue

            # ── REGULAR MESSAGE ────────────────────────────────────────────────
            message_text = data.get("message", "").strip()
            sender_id    = data.get("sender_id", 0)

            if not message_text:
                continue

            # Save to DB
            try:
                new_msg = ChatMessage(
                    complaint_id=complaint_id,
                    sender_id=sender_id,
                    sender_type=sender_type,
                    message=message_text,
                )
                db.add(new_msg)
                db.commit()
                db.refresh(new_msg)

                # Notify user when officer sends a message
                if sender_type == "officer":
                    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
                    if complaint:
                        # Check for existing recent identical notification to prevent duplication
                        existing = db.query(Notification).filter(
                            Notification.user_id == complaint.user_id,
                            Notification.complaint_id == complaint.id,
                            Notification.notification_type == "chat",
                            Notification.is_read == False
                        ).order_by(Notification.created_at.desc()).first()
                        
                        # Only create if no unread chat notif exists for this complaint
                        if not existing:
                            await notify_user(
                                db=db,
                                user_id=complaint.user_id,
                                complaint_id=complaint.id,
                                title="New Message from Officer",
                                message=f"New message on complaint {complaint.tracking_id}.",
                                notification_type="chat",
                            )

            except Exception as e:
                print(f"❌ DB save error: {e}")
                db.rollback()
                continue

            broadcast_payload = _json.dumps({
                "id":          new_msg.id,
                "sender_id":   new_msg.sender_id,
                "sender_type": new_msg.sender_type,
                "sender_name": "Officer" if sender_type == "officer" else "User",
                "message":     new_msg.message,
                "id":          new_msg.id,
                "complaint_id": new_msg.complaint_id,
                "sender_id":   new_msg.sender_id,
                "sender_type": new_msg.sender_type,
                "message":     new_msg.message,
                "timestamp":   format_iso(new_msg.created_at),
                "created_at":  format_iso(new_msg.created_at),
                "is_read":     False,
                "status":      "sent",
            })
            await _broadcast(complaint_id, broadcast_payload)   # broadcast to ALL (including sender)

    except WebSocketDisconnect:
        pass
    finally:
        # Clean up this socket
        connections.get(complaint_id, set()).discard(websocket)
        if not connections.get(complaint_id):
            connections.pop(complaint_id, None)

        # Mark sender as offline
        last_seen = format_iso(datetime.now(timezone.utc))
        if sender_type_hint != "unknown":
            presence.setdefault(complaint_id, {})[sender_type_hint] = {
                "online":    False,
                "last_seen": last_seen,
            }
            offline_pkt = _json.dumps({
                "type":        "presence",
                "sender_type": sender_type_hint,
                "online":      False,
                "last_seen":   last_seen,
            })
            # Try to broadcast to remaining sockets
            import asyncio
            try:
                asyncio.create_task(_broadcast(complaint_id, offline_pkt))
            except Exception:
                pass

        db.close()


# ─── REST endpoints ────────────────────────────────────────────────────────────

@fastapi_app.get("/chat/{complaint_id}")
async def get_chat_history(complaint_id: int, db: Session = Depends(get_db)):
    """Fetch chat history for a specific complaint"""
    messages = (
        db.query(ChatMessage)
        .filter(ChatMessage.complaint_id == complaint_id)
        .order_by(ChatMessage.created_at.asc())
        .all()
    )
    return [
        {
            "id":          msg.id,
            "complaint_id": msg.complaint_id,
            "sender_id":   msg.sender_id,
            "sender_type": msg.sender_type,
            "message":     msg.message,
            "id":          msg.id,
            "complaint_id": msg.complaint_id,
            "sender_id":   msg.sender_id,
            "sender_type": msg.sender_type,
            "message":     msg.message,
            "timestamp":   format_iso(msg.created_at),
            "is_read":     msg.is_read,
            "status":      "read" if msg.is_read else "sent",
        }
        for msg in messages
    ]


@fastapi_app.get("/chat/{complaint_id}/messages")
async def get_chat_messages(complaint_id: int, user_type: str, db: Session = Depends(get_db)):
    """Get all messages for a complaint and mark them as read for the receiver"""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found")

    opposite_type = "officer" if user_type == "user" else "user"

    db.query(ChatMessage).filter(
        ChatMessage.complaint_id == complaint_id,
        ChatMessage.sender_type  == opposite_type,
        ChatMessage.is_read      == False,
    ).update({"is_read": True})
    db.commit()

    messages = (
        db.query(ChatMessage)
        .filter(ChatMessage.complaint_id == complaint_id)
        .order_by(ChatMessage.created_at.asc())
        .all()
    )

    # Relay read status via WebSocket
    try:
        read_payload = _json.dumps({
            "type":        "status_update",
            "complaint_id": complaint_id,
            "status":      "read",
            "reader_type": user_type,
        })
        import asyncio
        asyncio.create_task(_broadcast(complaint_id, read_payload))
    except Exception:
        pass

    return [
        {
            "id":          msg.id,
            "sender_id":   msg.sender_id,
            "sender_type": msg.sender_type,
            "message":     msg.message,
            "id":          msg.id,
            "complaint_id": msg.complaint_id,
            "sender_id":   msg.sender_id,
            "sender_type": msg.sender_type,
            "message":     msg.message,
            "timestamp":   format_iso(msg.created_at),
            "is_read":     msg.is_read,
            "status":      "read" if msg.is_read else "sent",
        }
        for msg in messages
    ]


@fastapi_app.get("/chat/{complaint_id}/presence")
async def get_chat_presence(complaint_id: int):
    """Return current online/last-seen status for both parties in a chat room"""
    return presence.get(complaint_id, {})


@fastapi_app.post("/chat/{complaint_id}/send")
async def send_chat_message(
    complaint_id: int,
    message_data: schemas.ChatMessageCreate,
    db: Session = Depends(get_db),
):
    """HTTP fallback: save chat message to database"""
    try:
        new_message = ChatMessage(
            complaint_id=complaint_id,
            sender_id=message_data.sender_id,
            sender_type=message_data.sender_type,
            message=message_data.message,
        )
        db.add(new_message)
        db.commit()
        db.refresh(new_message)

        if message_data.sender_type == "officer":
            complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
            if complaint:
                # Check for existing recent identical notification
                existing = db.query(Notification).filter(
                    Notification.user_id == complaint.user_id,
                    Notification.complaint_id == complaint.id,
                    Notification.notification_type == "chat",
                    Notification.is_read == False
                ).first()

                if not existing:
                    await notify_user(
                        db=db,
                        user_id=complaint.user_id,
                        complaint_id=complaint.id,
                        title="New Message from Officer",
                        message=f"You have a new message regarding complaint {complaint.tracking_id}.",
                        notification_type="chat"
                    )

        return {
            "id":          new_message.id,
            "complaint_id": new_message.complaint_id,
            "sender_id":   new_message.sender_id,
            "sender_type": new_message.sender_type,
            "sender_name": "Officer" if new_message.sender_type == "officer" else "User",
            "message":     new_message.message,
            "id":          new_message.id,
            "complaint_id": new_message.complaint_id,
            "sender_id":   new_message.sender_id,
            "sender_type": new_message.sender_type,
            "message":     new_message.message,
            "timestamp":   format_iso(new_message.created_at),
            "created_at":  format_iso(new_message.created_at),
            "is_read":     new_message.is_read,
            "status":      "sent",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@fastapi_app.put("/chat/messages/{message_id}/read")
async def mark_chat_message_read(message_id: int, db: Session = Depends(get_db)):
    """Mark a single message as read"""
    message = db.query(ChatMessage).filter(ChatMessage.id == message_id).first()
    if message:
        message.is_read = True
        db.commit()
        return {"message": "Marked as read"}
    raise HTTPException(status_code=404, detail="Message not found")


@fastapi_app.get("/chat/{complaint_id}/unread-count")
async def get_chat_unread_count(
    complaint_id: int,
    user_type: str,
    db: Session = Depends(get_db),
):
    """Get count of unread messages from the opposite party"""
    opposite_type = "officer" if user_type == "user" else "user"
    count = db.query(ChatMessage).filter(
        ChatMessage.complaint_id == complaint_id,
        ChatMessage.sender_type  == opposite_type,
        ChatMessage.is_read      == False,
    ).count()
    return {"unread_count": count}


# ===== RATING ROUTES (single definition — remove the duplicate at line ~1420) =====

@fastapi_app.post("/complaints/{complaint_id}/rate")
async def rate_complaint(
    complaint_id: int,
    user_id: int,
    rating_data: schemas.RatingSubmit,
    db: Session = Depends(get_db),
):
    """Submit a rating for a resolved complaint"""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Complaint not found")

    if complaint.status != "resolved":
        raise HTTPException(status_code=400, detail="Only resolved complaints can be rated")

    existing = db.query(ComplaintRating).filter(ComplaintRating.complaint_id == complaint_id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Complaint already rated")

    new_rating = ComplaintRating(
        complaint_id=complaint_id,
        user_id=user_id,
        officer_id=complaint.assigned_officer_id,
        rating=rating_data.rating,
        feedback=rating_data.feedback,
    )
    db.add(new_rating)
    db.commit()
    db.refresh(new_rating)

    if complaint.assigned_officer_id:
        officer = db.query(Officer).filter(Officer.id == complaint.assigned_officer_id).first()
        if officer and officer.email:
            await send_email(
                officer.email,
                f"Rating Received - {complaint.tracking_id}",
                f"""<h2>Hello {officer.name},</h2>
                <p>Rating: {'⭐' * rating_data.rating} ({rating_data.rating}/5)</p>
                <p>Feedback: {rating_data.feedback or 'No feedback'}</p>""",
            )

    return {"message": "Rating submitted successfully", "rating_id": new_rating.id}


@fastapi_app.get("/complaints/{complaint_id}/rating")
async def get_complaint_rating(complaint_id: int, db: Session = Depends(get_db)):
    """Get rating for a complaint"""
    rating = db.query(ComplaintRating).filter(ComplaintRating.complaint_id == complaint_id).first()
    if not rating:
        return {"rated": False}
    return {
        "rated":      True,
        "rating":     rating.rating,
        "feedback":   rating.feedback,
        "created_at": format_iso(rating.created_at),
    }


@fastapi_app.get("/officer/{officer_id}/ratings")
async def get_officer_ratings(officer_id: int, db: Session = Depends(get_db)):
    """Get all ratings received by an officer"""
    ratings = db.query(ComplaintRating).filter(ComplaintRating.officer_id == officer_id).all()
    if not ratings:
        return {"total_ratings": 0, "average_rating": 0, "ratings": []}

    average_rating = sum(r.rating for r in ratings) / len(ratings)
    return {
        "total_ratings":   len(ratings),
        "average_rating":  round(average_rating, 2),
        "ratings": [
            {
                "complaint_id": r.complaint_id,
                "rating":       r.rating,
                "feedback":     r.feedback,
                "created_at":   format_iso(r.created_at),
            }
            for r in ratings
        ],
    }


# ===== FCM ENDPOINTS =====

@fastapi_app.post("/user/{user_id}/fcm-token")
async def save_fcm_token(user_id: int, token: dict, db: Session = Depends(get_db)):
    """Save user's FCM token for push notifications"""
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.fcm_token = token.get("token")
        db.commit()
        return {"message": "FCM token saved"}
    raise HTTPException(status_code=404, detail="User not found")


def send_push_notification(fcm_token: str, title: str, body: str):
    """Send push notification via Firebase Admin SDK"""
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=fcm_token,
        )
        messaging.send(message)
        print(f"🚀 Push notification sent to {fcm_token[:10]}...")
    except Exception as e:
        print(f"❌ Push notification error: {e}")



# 🔥 WRAP FASTAPI INTO SOCKET.IO
# socketio_path must match the 'path' option in the Flutter socket_io_client.
# The standard Engine.IO path is 'socket.io' (no leading slash).
# The ASGIApp intercepts any request whose path starts with /socket.io/
# before passing anything else to fastapi_app.
app = socketio.ASGIApp(
    sio,
    other_asgi_app=fastapi_app,
    static_files={},
    socketio_path='socket.io',
)

# Debug: verify wrapper is loaded correctly
import sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
print(f"[STARTUP] app type = {type(app)}")
print(f"[STARTUP] app.engineio_path = {getattr(app, 'engineio_path', 'N/A')}")
print(f"[STARTUP] app.other_asgi_app = {type(getattr(app, 'other_asgi_app', None))}")

# Run with: uvicorn main:app --reload
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)