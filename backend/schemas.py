"""
Pydantic schemas for request/response validation
"""
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime, date


# ===== AUTH SCHEMAS =====

class FirebaseAuthRequest(BaseModel):
    """Firebase ID token from mobile app"""
    id_token: str


class OfficerLoginRequest(BaseModel):
    """Officer login credentials"""
    email: EmailStr
    password: str


class AdminLoginRequest(BaseModel):
    """Admin login (uses same structure as officer for now)"""
    email: EmailStr
    password: str


class OfficerCreate(BaseModel):
    """Administrative creation of a new officer"""
    name: str
    email: EmailStr
    password: str
    employee_id: str
    department: str


class OfficerCreateMinimal(BaseModel):
    """Admin creates officer with just login ID and password"""
    name: str
    email: EmailStr
    employee_id: str
    department: str
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
    dob: Optional[date] = None # ✅ NEW
    aadhaar_number: Optional[str] = None # ✅ NEW
    aadhaar_image_path: Optional[str] = None # ✅ NEW


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
    dob: Optional[date] # ✅ NEW
    aadhaar_number: Optional[str] # ✅ NEW
    aadhaar_image_path: Optional[str] # ✅ NEW
    profile_completed: bool
    created_at: datetime


# ===== COMPLAINT SCHEMAS =====

class ComplaintSubmit(BaseModel):
    """Submit new complaint"""
    text: str
    selected_department: str
    latitude: float
    longitude: float
    location_address: str
    incident_location: str # Manual location from user (Compulsory)


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
    priority_score: Optional[float] = None 
    priority_label: Optional[str] = None
    assigned_officer_id: Optional[int] = None
    status: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    location_address: Optional[str] = None
    incident_location: Optional[str] = None
    created_at: datetime


class ComplaintUpdateDetail(BaseModel):
    """Update detail for timeline"""
    id: int
    update_text: str
    status_changed_from: Optional[str]
    status_changed_to: Optional[str]
    officer_name: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True

class ComplaintDetail(BaseModel):
    """Detailed complaint with updates and location"""
    id: int
    tracking_id: str
    text: str
    selected_department: str
    ai_category: Optional[str]
    ai_urgency: Optional[str]
    delay_risk_label: Optional[str]
    delay_risk_score: Optional[float]
    status: str
    assigned_officer_name: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    location_address: Optional[str] = None
    incident_location: Optional[str] = None
    created_at: datetime
    resolved_at: Optional[datetime] = None
    updates: List[ComplaintUpdateDetail] = []
    user_name: Optional[str] = None
    user_phone: Optional[str] = None

    class Config:
        from_attributes = True


# ===== RATING SCHEMAS =====

class RatingSubmit(BaseModel):
    """Submit a rating for a resolved complaint"""
    rating: int  # 1-5
    feedback: Optional[str] = None

class RatingResponse(BaseModel):
    """Rating response"""
    id: int
    complaint_id: int
    rating: int
    feedback: Optional[str]
    created_at: datetime

# ===== OFFICER SCHEMAS =====

class ComplaintUpdateRequest(BaseModel):
    """Officer update on complaint"""
    update_text: str
    new_status: Optional[str] = None


class OfficerProfileUpdate(BaseModel):
    """Officer profile completion"""
    name: str
    department: str
    phone_number: Optional[str] = None
    designation: Optional[str] = None
    govt_id_path: Optional[str] = None


class OfficerDashboardStats(BaseModel):
    """Officer dashboard statistics"""
    total_complaints: int
    assigned_to_me: int
    pending: int
    in_progress: int
    resolved: int


class SystemAnalyticsResponse(BaseModel):
    """System-wide analytics"""
    total_users: int
    total_officers: int
    total_complaints: int
    complaints_by_status: dict
    complaints_by_department: dict
    high_urgency_count: int


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


# ===== CHAT SCHEMAS =====

class ChatMessageCreate(BaseModel):
    sender_id: int
    sender_type: str  # 'user' or 'officer'
    message: str


# ===== FCM ENDPOINTS =====