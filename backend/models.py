"""
Database Models for Grievance Intelligence System v4.0 - Phase 4 Complete
All Tables with Phase 4 features: Image, Audio, Location, FCM, Chat, Rating
Authentication: Firebase (Google Sign-in) for users, Email/Password for officers
Language: English only
"""

from sqlalchemy import Column, Integer, String, Text, Float, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base
import secrets
from datetime import datetime


class User(Base):
    """
    Citizens who file complaints
    Authentication: Firebase (Google Sign-in)
    Phase 4: Added fcm_token for push notifications
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    
    # Firebase Authentication
    firebase_uid = Column(String(100), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=False, index=True)
    
    # Profile
    name = Column(String(100), nullable=False)
    phone_number = Column(String(15), nullable=True)
    address = Column(Text, nullable=True)
    pincode = Column(String(10), nullable=True)
    city = Column(String(50), nullable=True)
    state = Column(String(50), nullable=True)
    
    # Status
    is_active = Column(Boolean, default=True)
    profile_completed = Column(Boolean, default=False)
    
    # Phase 4: Push Notifications
    fcm_token = Column(String(255), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    complaints = relationship("Complaint", back_populates="user", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")


class Officer(Base):
    """
    Government officers who handle complaints
    Authentication: Email + Password (traditional login)
    """
    __tablename__ = "officers"

    id = Column(Integer, primary_key=True, index=True)
    
    # Authentication
    email = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    
    # Profile
    name = Column(String(100), nullable=False)
    employee_id = Column(String(50), unique=True, nullable=False)
    department = Column(String(50), nullable=False)
    # Departments: Power Department, Water Department, Municipal Services, 
    #              Health Department, Vigilance Department
    designation = Column(String(50), default='Officer')
    phone_number = Column(String(15))
    
    # Status
    is_active = Column(Boolean, default=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    assigned_complaints = relationship("Complaint", back_populates="assigned_officer")
    updates = relationship("ComplaintUpdate", back_populates="officer")
    ratings_received = relationship("ComplaintRating", back_populates="officer")


class Complaint(Base):
    """
    Complaints filed by users with AI predictions and status tracking
    Phase 4: Added image_path, audio_path, latitude, longitude, location_address
    """
    __tablename__ = "complaints"

    id = Column(Integer, primary_key=True, index=True)
    tracking_id = Column(String(20), unique=True, nullable=False, index=True)
    
    # User relationship
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Complaint content (English only)
    text = Column(Text, nullable=False)
    
    # Phase 4: Image Upload
    image_path = Column(String(255), nullable=True)
    
    # Phase 4: Audio Complaint
    audio_path = Column(String(255), nullable=True)
    audio_duration = Column(Integer, nullable=True)  # in seconds
    
    # Phase 4: Location Tracking
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    location_address = Column(String(500), nullable=True)
    
    # User selection
    selected_department = Column(String(50), nullable=False)
    
    # AI predictions
    ai_category = Column(String(50))
    ai_department = Column(String(50))
    ai_urgency = Column(String(20))
    delay_risk_label = Column(String(20))
    delay_risk_score = Column(Float)
    
    # Final values (after officer review)
    final_department = Column(String(50))
    final_category = Column(String(50), nullable=True)
    final_urgency = Column(String(20), nullable=True)
    
    # Status tracking
    status = Column(String(20), default='submitted')
    # Status values: submitted → under_review → in_progress → resolved → closed
    
    # Officer assignment
    assigned_officer_id = Column(Integer, ForeignKey("officers.id"), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="complaints")
    assigned_officer = relationship("Officer", back_populates="assigned_complaints")
    updates = relationship("ComplaintUpdate", back_populates="complaint", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="complaint", cascade="all, delete-orphan")
    ai_prediction = relationship("AIPrediction", back_populates="complaint", uselist=False, cascade="all, delete-orphan")
    rating = relationship("ComplaintRating", back_populates="complaint", uselist=False, cascade="all, delete-orphan")
    chat_messages = relationship("ChatMessage", back_populates="complaint", cascade="all, delete-orphan")


class ComplaintRating(Base):
    """
    Phase 4: User rating/feedback for resolved complaints
    Users can rate officer service 1-5 stars with optional feedback
    """
    __tablename__ = "complaint_ratings"

    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(Integer, ForeignKey("complaints.id", ondelete="CASCADE"), unique=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    officer_id = Column(Integer, ForeignKey("officers.id"), nullable=True)
    
    # Rating (1-5 stars)
    rating = Column(Integer, nullable=False)
    feedback = Column(Text, nullable=True)
    
    # Timestamp
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    complaint = relationship("Complaint", back_populates="rating")
    user = relationship("User")
    officer = relationship("Officer", back_populates="ratings_received")


class ComplaintUpdate(Base):
    """
    Officer comments and status changes on complaints
    """
    __tablename__ = "complaint_updates"

    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(Integer, ForeignKey("complaints.id", ondelete="CASCADE"), nullable=False)
    officer_id = Column(Integer, ForeignKey("officers.id"), nullable=False)
    
    # Update content
    update_text = Column(Text, nullable=False)
    status_changed_from = Column(String(20), nullable=True)
    status_changed_to = Column(String(20), nullable=True)
    
    # Timestamp
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    complaint = relationship("Complaint", back_populates="updates")
    officer = relationship("Officer", back_populates="updates")


class Notification(Base):
    """
    User notifications for complaint status updates
    """
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    complaint_id = Column(Integer, ForeignKey("complaints.id", ondelete="CASCADE"), nullable=True)
    
    # Notification content
    title = Column(String(100), nullable=False)
    message = Column(Text, nullable=False)
    notification_type = Column(String(20), default='info')
    # Types: status_update, comment, assignment, resolved
    
    # Status
    is_read = Column(Boolean, default=False)
    
    # Timestamp
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="notifications")
    complaint = relationship("Complaint", back_populates="notifications")


class AIPrediction(Base):
    """
    AI prediction details stored for analytics
    """
    __tablename__ = "ai_predictions"

    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(Integer, ForeignKey("complaints.id", ondelete="CASCADE"), unique=True, nullable=False)
    
    # AI predictions
    category = Column(String(50))
    department = Column(String(50))
    urgency = Column(String(20))
    delay_risk_label = Column(String(20))
    delay_risk_score = Column(Float)
    
    # Model version
    model_version = Column(String(20), default='v4.0')
    
    # Timestamp
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    complaint = relationship("Complaint", back_populates="ai_prediction")


class ChatMessage(Base):
    """
    Phase 4: Real-time chat messages between users and officers
    """
    __tablename__ = "chat_messages"
    
    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(Integer, ForeignKey('complaints.id', ondelete="CASCADE"), nullable=False)
    sender_id = Column(Integer, nullable=False)  # user_id or officer_id
    sender_type = Column(String(10), nullable=False)  # 'user' or 'officer'
    message = Column(Text, nullable=False)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationship
    complaint = relationship("Complaint", back_populates="chat_messages")


# Helper Functions
def generate_tracking_id() -> str:
    """
    Generate unique tracking ID
    Format: GRV2026001234
    """
    year = datetime.now().year
    random_num = secrets.randbelow(999999)
    return f"GRV{year}{random_num:06d}"