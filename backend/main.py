"""
Grievance Intelligence System v3.0 - Main API
Authentication: Firebase (Google Sign-in) for users, Email/Password for officers
Language: English only
"""

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import Optional
import models
from database import engine, get_db
from models import Base
import schemas
import crud
from firebase_config import initialize_firebase, verify_token
from ai.analyze_complaint import analyze_complaint
from fastapi import File, UploadFile
from fastapi.staticfiles import StaticFiles
import shutil
import time
from models import Complaint, User
import firebase_admin
from firebase_admin import credentials, messaging
import aiosmtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Initialize Firebase
try:
    initialize_firebase()
except Exception as e:
    print(f"⚠️  Firebase initialization skipped: {e}")
    print("📝 Using mock authentication for testing")

# Create FastAPI app
app = FastAPI(
    title="Grievance Intelligence API v3.0",
    description="AI-powered complaint system with Firebase auth",
    version="3.0.0"
)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Initialize Firebase Admin
try:
    cred = credentials.Certificate("firebase-service-account.json")
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin initialized")
except Exception as e:
    print(f"⚠️ Firebase Admin init failed: {e}")

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

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production: specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create database tables
Base.metadata.create_all(bind=engine)


# ===== HEALTH CHECK =====

@app.get("/")
def root():
    """API health check"""
    return {
        "message": "Grievance Intelligence API v3.0",
        "status": "running",
        "auth": "Firebase",
        "language": "English"
    }


# ===== AUTHENTICATION ROUTES =====

@app.post("/auth/firebase", response_model=schemas.AuthResponse)
def firebase_login(request: schemas.FirebaseAuthRequest, db: Session = Depends(get_db)):
    """
    User login with Firebase (Google Sign-in)
    Mobile app sends Firebase ID token
    """
    # Verify Firebase token
    firebase_user = verify_token(request.id_token)
    
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


@app.post("/auth/officer/login", response_model=schemas.AuthResponse)
def officer_login(request: schemas.OfficerLoginRequest, db: Session = Depends(get_db)):
    """
    Officer login with email/password
    """
    officer = crud.get_officer_by_email(db, request.email)
    
    if not officer or not crud.verify_officer_password(request.password, officer.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )
    
    return schemas.AuthResponse(
        user_id=officer.id,
        email=officer.email,
        name=officer.name,
        role='officer',
        department=officer.department
    )


# ===== USER PROFILE ROUTES =====

@app.get("/user/profile/{user_id}", response_model=schemas.UserProfileResponse)
def get_user_profile(user_id: int, db: Session = Depends(get_db)):
    """Get user profile"""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return user


@app.put("/user/profile/{user_id}", response_model=schemas.UserProfileResponse)
def update_profile(user_id: int, profile: schemas.UserProfileUpdate, db: Session = Depends(get_db)):
    """Update user profile"""
    user = crud.update_user_profile(
        db=db,
        user_id=user_id,
        name=profile.name,
        phone_number=profile.phone_number,
        address=profile.address,
        pincode=profile.pincode,
        city=profile.city,
        state=profile.state
    )
    
    return user


# ===== COMPLAINT ROUTES =====

@app.post("/complaints/submit", response_model=schemas.ComplaintResponse)
async def submit_complaint(
    complaint: schemas.ComplaintSubmit,
    user_id: int,
    db: Session = Depends(get_db)
):
    """Submit new complaint with AI analysis"""
    
    # Run AI analysis
    ai_result = analyze_complaint(complaint.text)
    
    # Create complaint in database
    new_complaint = crud.create_complaint(
        db=db,
        user_id=user_id,
        text=complaint.text,
        selected_department=complaint.selected_department,
        ai_result=ai_result,
        latitude=complaint.latitude,
        longitude=complaint.longitude,
        location_address=complaint.location_address
    )
    
    # Create notification for user
    from models import Notification
    notification = Notification(
        user_id=user_id,
        complaint_id=new_complaint.id,
        title="Complaint Submitted Successfully",
        message=f"Your complaint {new_complaint.tracking_id} has been submitted and is under review.",
        notification_type='status_update'
    )
    db.add(notification)
    db.commit()
    
    # Send Push Notification
    if new_complaint.user_id:
        user = db.query(models.User).filter(models.User.id == new_complaint.user_id).first()
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
    
    return new_complaint


@app.post("/complaints/{complaint_id}/upload-image")
async def upload_complaint_image(
    complaint_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """Upload image for a complaint"""
    try:
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
            "image_url": f"/{file_path}"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/complaints/my/{user_id}")
def get_my_complaints(user_id: int, db: Session = Depends(get_db)):
    """Get all complaints for a user"""
    complaints = crud.get_user_complaints(db, user_id)
    return complaints


@app.get("/complaints/{complaint_id}")
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
        "assigned_officer": complaint.assigned_officer.name if complaint.assigned_officer else None
    }


# ===== OFFICER ROUTES =====

@app.get("/officer/dashboard/{officer_id}")
def officer_dashboard(officer_id: int, db: Session = Depends(get_db)):
    """Get officer dashboard statistics"""
    from models import Officer
    officer = db.query(Officer).filter(Officer.id == officer_id).first()
    
    if not officer:
        raise HTTPException(status_code=404, detail="Officer not found")
    
    from models import Complaint
    
    # Get stats for officer's department
    total = db.query(Complaint).filter(Complaint.final_department == officer.department).count()
    assigned = db.query(Complaint).filter(Complaint.assigned_officer_id == officer_id).count()
    pending = db.query(Complaint).filter(
        Complaint.final_department == officer.department,
        Complaint.status == 'submitted'
    ).count()
    in_progress = db.query(Complaint).filter(
        Complaint.assigned_officer_id == officer_id,
        Complaint.status == 'in_progress'
    ).count()
    resolved = db.query(Complaint).filter(
        Complaint.assigned_officer_id == officer_id,
        Complaint.status == 'resolved'
    ).count()
    
    return {
        "total_complaints": total,
        "assigned_to_me": assigned,
        "pending": pending,
        "in_progress": in_progress,
        "resolved": resolved
    }


@app.get("/officer/complaints/{officer_id}")
def get_officer_complaints(
    officer_id: int,
    assigned_only: bool = False,
    status: Optional[str] = None,
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
        officer_id=officer_id if assigned_only else None,
        status=status
    )
    
    return complaints


@app.post("/officer/complaints/{complaint_id}/assign/{officer_id}")
def assign_to_me(complaint_id: int, officer_id: int, db: Session = Depends(get_db)):
    """Assign complaint to officer"""
    complaint = crud.assign_complaint_to_officer(db, complaint_id, officer_id)
    return {"message": "Complaint assigned successfully", "complaint": complaint}


@app.put("/officer/complaints/{complaint_id}/update")
async def update_status(
    complaint_id: int,
    officer_id: int,
    update: schemas.ComplaintUpdateRequest,
    db: Session = Depends(get_db)
):
    """Update complaint status and add comment"""
    new_status = update.new_status or 'in_progress'
    
    update_record = crud.update_complaint_status(
        db=db,
        complaint_id=complaint_id,
        officer_id=officer_id,
        new_status=new_status,
        update_text=update.update_text
    )
    
    # Send Email Notification
    complaint = db.query(models.Complaint).filter(models.Complaint.id == complaint_id).first()
    if complaint and complaint.user_id:
        user = db.query(models.User).filter(models.User.id == complaint.user_id).first()
        if user and user.email:
            await send_email(
                user.email,
                f"Complaint {complaint.tracking_id} Updated",
                f"""
                <h2>Dear {user.name},</h2>
                <p>Your complaint has been updated.</p>
                <p><strong>Tracking ID:</strong> {complaint.tracking_id}</p>
                <p><strong>New Status:</strong> {new_status}</p>
                <p><strong>Update:</strong> {update.update_text}</p>
                <br>
                <p>Thank you for your patience.</p>
                """
            )
    
    return {"message": "Complaint updated successfully", "update": update_record}


# ===== NOTIFICATION ROUTES =====

@app.get("/notifications/{user_id}")
def get_notifications(user_id: int, unread_only: bool = False, db: Session = Depends(get_db)):
    """Get user notifications"""
    notifications = crud.get_user_notifications(db, user_id, unread_only)
    return notifications


@app.put("/notifications/{notification_id}/read")
def mark_read(notification_id: int, db: Session = Depends(get_db)):
    """Mark notification as read"""
    notification = crud.mark_notification_read(db, notification_id)
    return {"message": "Notification marked as read", "notification": notification}


@app.get("/notifications/{user_id}/unread-count")
def unread_count(user_id: int, db: Session = Depends(get_db)):
    """Get unread notification count"""
    count = crud.get_unread_count(db, user_id)
    return {"unread_count": count}


# ===== ANALYTICS ROUTES (from old system) =====

@app.get("/analytics/summary")
def analytics_summary(db: Session = Depends(get_db)):
    """General analytics"""
    from sqlalchemy import func
    from models import Complaint
    
    total = db.query(Complaint).count()
    high_urgency = db.query(Complaint).filter(Complaint.ai_urgency == "High").count()
    
    category_counts = (
        db.query(Complaint.ai_category, func.count(Complaint.ai_category))
        .group_by(Complaint.ai_category)
        .all()
    )
    
    return {
        "total_complaints": total,
        "high_urgency": high_urgency,
        "by_category": {cat: count for cat, count in category_counts if cat}
    }


# ===== ADMIN ROUTES =====

@app.post("/auth/admin/login", response_model=schemas.AuthResponse)
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


@app.get("/admin/analytics/system", response_model=schemas.SystemAnalyticsResponse)
def get_system_analytics(db: Session = Depends(get_db)):
    """Return system-wide stats"""
    return crud.get_system_analytics(db)


@app.get("/admin/users")
def get_all_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Return all users"""
    return crud.get_all_users(db, skip, limit)


@app.get("/admin/officers")
def get_all_officers(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Return all officers"""
    return crud.get_all_officers(db, skip, limit)


@app.get("/admin/complaints/all")
def get_all_complaints(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Return all complaints (not filtered by officer)"""
    return crud.get_all_complaints(db, skip, limit)


# ===== FCM ENDPOINTS =====

@app.post("/user/{user_id}/fcm-token")
async def save_fcm_token(user_id: int, token: dict, db: Session = Depends(get_db)):
    """Save user's FCM token for push notifications"""
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.fcm_token = token.get('token')
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


# Run with: python -m uvicorn main:app --reload
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)