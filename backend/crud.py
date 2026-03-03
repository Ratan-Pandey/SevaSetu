"""
CRUD operations for database
"""
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from models import User, Officer, Complaint, ComplaintUpdate, Notification, AIPrediction, generate_tracking_id
from passlib.context import CryptContext
from typing import Optional

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ===== USER CRUD =====

def get_user_by_firebase_uid(db: Session, firebase_uid: str) -> Optional[User]:
    """Get user by Firebase UID"""
    return db.query(User).filter(User.firebase_uid == firebase_uid).first()


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """Get user by email"""
    return db.query(User).filter(User.email == email).first()


def create_user(db: Session, firebase_uid: str, email: str, name: str) -> User:
    """Create new user"""
    user = User(
        firebase_uid=firebase_uid,
        email=email,
        name=name
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def update_user_profile(db: Session, user_id: int, **kwargs) -> User:
    """Update user profile"""
    user = db.query(User).filter(User.id == user_id).first()
    for key, value in kwargs.items():
        if value is not None and hasattr(user, key):
            setattr(user, key, value)
    
    # Mark profile as completed if all fields filled
    if all([user.phone_number, user.address, user.pincode, user.city, user.state]):
        user.profile_completed = True
    
    db.commit()
    db.refresh(user)
    return user


# ===== OFFICER CRUD =====

def get_officer_by_email(db: Session, email: str) -> Optional[Officer]:
    """Get officer by email"""
    return db.query(Officer).filter(Officer.email == email).first()


def verify_officer_password(plain_password: str, hashed_password: str) -> bool:
    """Verify officer password"""
    return pwd_context.verify(plain_password, hashed_password)


def create_officer(db: Session, email: str, password: str, name: str, 
                  employee_id: str, department: str) -> Officer:
    """Create new officer"""
    hashed_password = pwd_context.hash(password)
    officer = Officer(
        email=email,
        password_hash=hashed_password,
        name=name,
        employee_id=employee_id,
        department=department
    )
    db.add(officer)
    db.commit()
    db.refresh(officer)
    return officer


# ===== COMPLAINT CRUD =====

def create_complaint(db: Session, user_id: int, text: str, selected_department: str,
                    ai_result: dict) -> Complaint:
    """Create new complaint with AI predictions"""
    tracking_id = generate_tracking_id()
    
    complaint = Complaint(
        tracking_id=tracking_id,
        user_id=user_id,
        text=text,
        selected_department=selected_department,
        ai_category=ai_result.get('category'),
        ai_department=ai_result.get('department'),
        ai_urgency=ai_result.get('urgency'),
        delay_risk_label=ai_result.get('delay_risk_label'),
        delay_risk_score=ai_result.get('delay_risk_score'),
        final_department=ai_result.get('department'),
        status='submitted'
    )
    db.add(complaint)
    db.flush()  # Get complaint.id
    
    # Save AI prediction details
    ai_prediction = AIPrediction(
        complaint_id=complaint.id,
        category=ai_result.get('category'),
        department=ai_result.get('department'),
        urgency=ai_result.get('urgency'),
        delay_risk_label=ai_result.get('delay_risk_label'),
        delay_risk_score=ai_result.get('delay_risk_score')
    )
    db.add(ai_prediction)
    
    db.commit()
    db.refresh(complaint)
    return complaint


def get_user_complaints(db: Session, user_id: int, limit: int = 20):
    """Get complaints for a user"""
    return db.query(Complaint).filter(Complaint.user_id == user_id)\
             .order_by(Complaint.created_at.desc()).limit(limit).all()


def get_complaint_by_id(db: Session, complaint_id: int) -> Optional[Complaint]:
    """Get complaint by ID"""
    return db.query(Complaint).filter(Complaint.id == complaint_id).first()


def get_complaints_for_officer(db: Session, department: str, officer_id: Optional[int] = None,
                              status: Optional[str] = None, limit: int = 50):
    """Get complaints for officer dashboard"""
    query = db.query(Complaint).filter(Complaint.final_department == department)
    
    if officer_id:
        query = query.filter(Complaint.assigned_officer_id == officer_id)
    
    if status:
        query = query.filter(Complaint.status == status)
    
    return query.order_by(Complaint.created_at.desc()).limit(limit).all()


def assign_complaint_to_officer(db: Session, complaint_id: int, officer_id: int) -> Complaint:
    """Assign complaint to officer"""
    complaint = get_complaint_by_id(db, complaint_id)
    complaint.assigned_officer_id = officer_id
    complaint.status = 'under_review'
    db.commit()
    db.refresh(complaint)
    return complaint


def update_complaint_status(db: Session, complaint_id: int, officer_id: int,
                           new_status: str, update_text: str) -> ComplaintUpdate:
    """Update complaint status and add officer comment"""
    complaint = get_complaint_by_id(db, complaint_id)
    old_status = complaint.status
    complaint.status = new_status
    
    if new_status == 'resolved':
        from datetime import datetime
        complaint.resolved_at = datetime.utcnow()
    
    # Create update record
    update = ComplaintUpdate(
        complaint_id=complaint_id,
        officer_id=officer_id,
        update_text=update_text,
        status_changed_from=old_status,
        status_changed_to=new_status
    )
    db.add(update)
    
    # Create notification for user
    notification = Notification(
        user_id=complaint.user_id,
        complaint_id=complaint_id,
        title=f"Status Updated: {new_status.replace('_', ' ').title()}",
        message=update_text,
        notification_type='status_update'
    )
    db.add(notification)
    
    db.commit()
    db.refresh(update)
    return update


# ===== NOTIFICATION CRUD =====

def get_user_notifications(db: Session, user_id: int, unread_only: bool = False):
    """Get user notifications"""
    query = db.query(Notification).filter(Notification.user_id == user_id)
    
    if unread_only:
        query = query.filter(Notification.is_read == False)
    
    return query.order_by(Notification.created_at.desc()).all()


def mark_notification_read(db: Session, notification_id: int):
    """Mark notification as read"""
    notification = db.query(Notification).filter(Notification.id == notification_id).first()
    if notification:
        notification.is_read = True
        db.commit()
    return notification


def get_unread_count(db: Session, user_id: int) -> int:
    """Get unread notification count"""
    return db.query(Notification).filter(
        and_(Notification.user_id == user_id, Notification.is_read == False)
    ).count()