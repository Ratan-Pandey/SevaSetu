"""
Pydantic schemas for request/response validation
"""
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


# ===== AUTH SCHEMAS =====

class FirebaseAuthRequest(BaseModel):
    """Firebase ID token from mobile app"""
    id_token: str


class OfficerLoginRequest(BaseModel):
    """Officer login credentials"""
    email: EmailStr
    password: str


class AuthResponse(BaseModel):
    """Authentication response"""
    user_id: int
    email: str
    name: str
    role: str  # 'user' or 'officer'
    profile_completed: Optional[bool] = None
    department: Optional[str] = None


# ===== USER SCHEMAS =====

class UserProfileUpdate(BaseModel):
    """User profile update"""
    name: Optional[str] = None
    phone_number: Optional[str] = None
    address: Optional[str] = None
    pincode: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None


class UserProfileResponse(BaseModel):
    """User profile response"""
    id: int
    firebase_uid: str
    email: str
    name: str
    phone_number: Optional[str]
    address: Optional[str]
    pincode: Optional[str]
    city: Optional[str]
    state: Optional[str]
    profile_completed: bool
    created_at: datetime


# ===== COMPLAINT SCHEMAS =====

class ComplaintSubmit(BaseModel):
    """Submit new complaint"""
    text: str
    selected_department: str


class ComplaintResponse(BaseModel):
    """Complaint response with AI predictions"""
    id: int
    tracking_id: str
    text: str
    selected_department: str
    ai_category: Optional[str]
    ai_department: Optional[str]
    ai_urgency: Optional[str]
    delay_risk_label: Optional[str]
    delay_risk_score: Optional[float]
    status: str
    created_at: datetime


class ComplaintDetail(BaseModel):
    """Detailed complaint with updates"""
    id: int
    tracking_id: str
    text: str
    selected_department: str
    ai_category: Optional[str]
    ai_urgency: Optional[str]
    delay_risk_label: Optional[str]
    delay_risk_score: Optional[float]
    status: str
    assigned_officer_name: Optional[str]
    created_at: datetime
    updates: list


# ===== OFFICER SCHEMAS =====

class ComplaintUpdateRequest(BaseModel):
    """Officer update on complaint"""
    update_text: str
    new_status: Optional[str] = None


class OfficerDashboardStats(BaseModel):
    """Officer dashboard statistics"""
    total_complaints: int
    assigned_to_me: int
    pending: int
    in_progress: int
    resolved: int


# ===== NOTIFICATION SCHEMAS =====

class NotificationResponse(BaseModel):
    """Notification response"""
    id: int
    title: str
    message: str
    notification_type: str
    is_read: bool
    created_at: datetime
    complaint_tracking_id: Optional[str]