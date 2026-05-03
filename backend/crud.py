"""
CRUD operations for database
"""
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func, case
from models import User, Officer, Complaint, ComplaintUpdate, Notification, AIPrediction, generate_tracking_id, UserReport
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
    if all([user.phone_number, user.address, user.pincode, user.city, user.state, user.dob, user.aadhaar_number]):
        user.profile_completed = True
    
    db.commit()
    db.refresh(user)
    return user


# ===== OFFICER CRUD =====

def get_officer_by_email(db: Session, email: str) -> Optional[Officer]:
    """Get officer by email"""
    return db.query(Officer).filter(Officer.email == email).first()


def get_all_officers(db: Session):
    """Retrieve all officers for management dashboard"""
    # Filter out System Admin and Admin department from the display list
    officers = db.query(Officer).filter(
        Officer.name != "System Admin",
        Officer.department != "Admin"
    ).all()

    return [
        {
            "id": o.id,
            "name": o.name,
            "email": o.email,
            "employee_id": o.employee_id,
            "department": o.department,
            "is_active": o.is_active
        }
        for o in officers
    ]


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

def get_least_busy_officer(db: Session, department: str) -> Optional[int]:
    """
    Find the least busy officer in a specific department.
    Includes aggressive normalization (Step 5) and least-busy logic.
    """
    # Step 5: Normalize department
    dept = department.strip().lower()

    if "police" in dept:
        dept = "police"
    elif "water" in dept:
        dept = "water"
    elif "electric" in dept or "power" in dept:
        # Normalize to Power Department if that's the DB standard, 
        # or use standard 'electricity' as requested.
        # We'll use 'power department' as it's common in this codebase
        dept = "power department"
    elif "health" in dept:
        dept = "health"
    elif "municipal" in dept:
        dept = "municipal"
    elif "vigilance" in dept or "corruption" in dept:
        dept = "vigilance department"

    # Search for officer in the normalized department
    officer = (
        db.query(Officer)
        .filter(func.lower(Officer.department) == dept)
        .outerjoin(Complaint, Officer.id == Complaint.assigned_officer_id)
        .group_by(Officer.id)
        .order_by(func.count(Complaint.id).asc())
        .first()
    )
    
    # Second pass: If still not found, try a looser contains-match
    if not officer:
        officer = (
            db.query(Officer)
            .filter(Officer.department.ilike(f"%{dept}%"))
            .outerjoin(Complaint, Officer.id == Complaint.assigned_officer_id)
            .group_by(Officer.id)
            .order_by(func.count(Complaint.id).asc())
            .first()
        )
        
    return officer.id if officer else None


def create_complaint(db: Session, user_id: int, text: str, selected_department: str,
                    ai_result: dict, latitude: float, longitude: float,
                    location_address: str, incident_location: str) -> Complaint:
    """Create new complaint with AI predictions and AUTO-ASSIGNMENT"""
    tracking_id = generate_tracking_id()
    
    # 🔥 AUTO ASSIGNMENT
    assigned_officer_id = get_least_busy_officer(db, selected_department)

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
        priority_score=ai_result.get('priority_score'),
        priority_label=ai_result.get('priority_label'),
        priority_explanation=ai_result.get('explanation'),
        final_department=ai_result.get('department'),
        status='submitted',
        assigned_officer_id=assigned_officer_id,
        latitude=latitude,
        longitude=longitude,
        location_address=location_address,
        incident_location=incident_location
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
        delay_risk_score=ai_result.get('delay_risk_score'),
        priority_score=ai_result.get('priority_score'),
        priority_label=ai_result.get('priority_label')
    )
    db.add(ai_prediction)
    
    db.commit()
    db.refresh(complaint)
    return complaint


def get_user_complaints(db: Session, user_id: int, limit: int = 20):
    """Get complaints for a user"""
    return db.query(Complaint).filter(Complaint.user_id == user_id)\
             .order_by(Complaint.created_at.desc()).limit(limit).all()


def get_user_stats(db: Session, user_id: int):
    """Get complaint statistics for a specific user"""
    total = db.query(Complaint).filter(Complaint.user_id == user_id).count()

    active = db.query(Complaint).filter(
        Complaint.user_id == user_id,
        Complaint.status.in_(["under_review", "in_progress"])
    ).count()

    resolved = db.query(Complaint).filter(
        Complaint.user_id == user_id,
        Complaint.status == "resolved"
    ).count()

    return {
        "total": total,
        "active": active,
        "resolved": resolved
    }


def get_admin_stats(db: Session):
    """Get overall system statistics for admin dashboard"""
    from sqlalchemy import func
    
    total = db.query(Complaint).count()

    resolved = db.query(Complaint).filter(
        Complaint.status == "resolved"
    ).count()

    pending = db.query(Complaint).filter(
        Complaint.status.in_(["submitted", "under_review", "in_progress"])
    ).count()

    # Priority breakdown
    critical = db.query(Complaint).filter(Complaint.priority_label == "Critical").count()
    high_priority = db.query(Complaint).filter(Complaint.priority_label == "High").count()
    medium_priority = db.query(Complaint).filter(Complaint.priority_label == "Medium").count()
    low_priority = db.query(Complaint).filter(Complaint.priority_label == "Low").count()

    # Status breakdown
    submitted = db.query(Complaint).filter(Complaint.status == "submitted").count()
    under_review = db.query(Complaint).filter(Complaint.status == "under_review").count()
    in_progress = db.query(Complaint).filter(Complaint.status == "in_progress").count()

    # Resolution rate
    resolution_rate = round((resolved / total * 100), 1) if total > 0 else 0

    # Today's complaints
    from datetime import datetime, timedelta
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    today_complaints = db.query(Complaint).filter(Complaint.created_at >= today_start).count()

    return {
        "total": total,
        "resolved": resolved,
        "pending": pending,
        "high_priority": high_priority,
        "critical": critical,
        "medium_priority": medium_priority,
        "low_priority": low_priority,
        "submitted": submitted,
        "under_review": under_review,
        "in_progress": in_progress,
        "resolution_rate": resolution_rate,
        "today_complaints": today_complaints,
    }


def get_department_stats(db: Session):
    """Get metrics broken down by department"""
    departments = db.query(Complaint.selected_department).distinct().all()

    result = []

    for dept_tuple in departments:
        dept = dept_tuple[0]

        total = db.query(Complaint).filter(
            Complaint.selected_department == dept
        ).count()

        resolved = db.query(Complaint).filter(
            Complaint.selected_department == dept,
            Complaint.status == "resolved"
        ).count()

        pending = db.query(Complaint).filter(
            Complaint.selected_department == dept,
            Complaint.status != "resolved"
        ).count()

        # Avoid division by zero
        res_rate = (resolved / total * 100) if total > 0 else 0

        result.append({
            "department": dept,
            "total": total,
            "resolved": resolved,
            "pending": pending,
            "resolution_rate": round(res_rate, 1)
        })

    return result


def get_top_problem_departments(db: Session):
    """Identify categories or departments struggling with high pending ratios"""
    # Let's focus on CATEGORIES (Types of problems) as that's usually what 'Top Problems' refers to
    # We'll get categories that have at least one pending complaint
    categories = db.query(Complaint.ai_category).filter(Complaint.ai_category.isnot(None)).distinct().all()

    result = []

    for cat_tuple in categories:
        cat = cat_tuple[0]
        if not cat: continue

        total = db.query(Complaint).filter(
            Complaint.ai_category == cat
        ).count()

        # ONLY count active statuses as pending (submitted, under_review, in_progress)
        # Exclude 'resolved' and 'closed_by_user'
        pending = db.query(Complaint).filter(
            Complaint.ai_category == cat,
            Complaint.status.in_(['submitted', 'under_review', 'in_progress'])
        ).count()
        
        # Only include if there are pending issues
        if pending > 0:
            pending_ratio = (pending / total) if total > 0 else 0
            result.append({
                "department": cat, # Keep key as 'department' for frontend compatibility or change both
                "pending": pending,
                "total": total,
                "pending_ratio": round(pending_ratio, 2)
            })

    # Sort by quantity of pending issues, then by ratio
    result.sort(key=lambda x: (x["pending"], x["pending_ratio"]), reverse=True)

    # If result is empty, fall back to departments to avoid empty section
    if not result:
        depts = db.query(Complaint.selected_department).distinct().all()
        for d_tuple in depts:
            d = d_tuple[0]
            t = db.query(Complaint).filter(Complaint.selected_department == d).count()
            p = db.query(Complaint).filter(
                Complaint.selected_department == d,
                Complaint.status.in_(['submitted', 'under_review', 'in_progress'])
            ).count()
            
            if p > 0:
                result.append({
                    "department": d,
                    "pending": p,
                    "total": t,
                    "pending_ratio": round(p/t if t > 0 else 0, 2)
                })
        result.sort(key=lambda x: x["pending_ratio"], reverse=True)

    return result[:10] # Limit to top 10


def get_complaint_by_id(db: Session, complaint_id: int) -> Optional[Complaint]:
    """Get complaint by ID"""
    return db.query(Complaint).filter(Complaint.id == complaint_id).first()


def get_complaints_for_officer(db: Session, department: str, officer_id: Optional[int] = None,
                               status: Optional[str] = None, search: Optional[str] = None, 
                               priority: Optional[str] = None,
                               sort_by: str = "priority", limit: int = 50):
    """Get complaints for officer dashboard"""
    from sqlalchemy import or_

    dept_clean = department.strip().lower()

    # Always include: explicitly assigned to this officer OR matching department (case-insensitive)
    if officer_id:
        query = db.query(Complaint).filter(
            or_(
                Complaint.assigned_officer_id == officer_id,
                Complaint.selected_department.ilike(f"%{dept_clean}%")
            )
        )
    else:
        query = db.query(Complaint).filter(
            Complaint.selected_department.ilike(f"%{dept_clean}%")
        )

    if status:
        query = query.filter(Complaint.status == status)

    if search:
        search_term = f"%{search.lower()}%"
        query = query.filter(
            or_(
                Complaint.text.ilike(search_term),
                Complaint.tracking_id.ilike(search_term)
            )
        )

    if priority and priority.strip():
        query = query.filter(Complaint.priority_label == priority)

    # Group 1: Active (under_review, in_progress, submitted)
    # Group 2: Resolved
    # Group 3: Closed by User
    status_order = case(
        (Complaint.status.in_(['in_progress', 'under_review', 'submitted']), 0),
        (Complaint.status == 'resolved', 1),
        (Complaint.status == 'closed_by_user', 2),
        else_=3
    )

    # Define custom priority ordering weights
    priority_order = case(
        (Complaint.priority_label == 'Critical', 0),
        (Complaint.priority_label == 'High', 1),
        (Complaint.priority_label == 'Medium', 2),
        (Complaint.priority_label == 'Low', 3),
        else_=4
    )

    # Unified Sorting: Group by STATUS first, then PRIORITY inside each group, then TIME
    query = query.order_by(status_order.asc(), priority_order.asc(), Complaint.created_at.desc())

    results = query.limit(limit).all()
    print(f"✅ [QUERY] officer_id={officer_id} dept='{department}' → {len(results)} complaints found")
    return results


def get_top_officers_by_department(db: Session, department: str, limit: int = 5):
    """Retrieve top performing officers for a specific department based on resolved complaints"""
    from sqlalchemy import func
    top_officers = (
        db.query(
            Officer.name,
            func.count(Complaint.id).label('resolved_count')
        )
        .join(Complaint, Officer.id == Complaint.assigned_officer_id)
        # Use LIKE or case-insensitive comparison to handle "Police" vs "Police Department"
        .filter(func.lower(Officer.department).contains(func.lower(department.replace(" Department", ""))))
        .filter(Complaint.status == 'resolved')
        .group_by(Officer.id)
        .order_by(func.count(Complaint.id).desc())
        .limit(limit)
        .all()
    )
    return [{"name": o[0], "count": o[1]} for o in top_officers]


def get_complaint_stats(db: Session, department: str):
    total = db.query(Complaint).filter(
        Complaint.selected_department == department
    ).count()

    high = db.query(Complaint).filter(
        Complaint.selected_department == department,
        Complaint.priority_label == "High"
    ).count()

    medium = db.query(Complaint).filter(
        Complaint.selected_department == department,
        Complaint.priority_label == "Medium"
    ).count()

    low = db.query(Complaint).filter(
        Complaint.selected_department == department,
        Complaint.priority_label == "Low"
    ).count()

    return {
        "total": total,
        "high": high,
        "medium": medium,
        "low": low
    }


# def assign_complaint_to_officer(db: Session, complaint_id: int, officer_id: int) -> Complaint:
#     """Assign complaint to officer"""
#     complaint = get_complaint_by_id(db, complaint_id)
#     complaint.assigned_officer_id = officer_id
#     complaint.status = 'under_review'
#     db.commit()
#     # db.refresh(complaint)
#     return complaint


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
    return True

# ===== USER REPORTING & SUSPENSION =====

def report_user(db: Session, user_id: int, officer_id: int, reason: Optional[str] = None):
    """
    Report a user. If they get 5 reports from different officers, suspend them.
    """
    # Check if this officer already reported this user
    existing = db.query(UserReport).filter(
        UserReport.user_id == user_id,
        UserReport.officer_id == officer_id
    ).first()
    
    if existing:
        return {"success": False, "message": "You have already reported this user"}
    
    new_report = UserReport(
        user_id=user_id,
        officer_id=officer_id,
        reason=reason
    )
    db.add(new_report)
    
    # Check total reports from DIFFERENT officers
    report_count = db.query(UserReport).filter(UserReport.user_id == user_id).count()
    
    if report_count >= 5:
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            user.is_suspended = True
            
    db.commit()
    return {"success": True, "report_count": report_count, "is_suspended": report_count >= 5}

def lift_suspension(db: Session, user_id: int):
    """Lift suspension for a user"""
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.is_suspended = False
        db.commit()
        return True
    return False


def get_unread_count(db: Session, user_id: int) -> int:
    """Get unread notification count"""
    from sqlalchemy import and_
    return db.query(Notification).filter(
        and_(Notification.user_id == user_id, Notification.is_read == False)
    ).count()


# ===== ADMIN CRUD =====

def get_all_users(db: Session, skip: int = 0, limit: int = 100):
    """Get all registered users with their complaint and report statistics"""
    users = db.query(User).offset(skip).limit(limit).all()
    
    result = []
    for u in users:
        # Count complaints
        complaint_count = db.query(Complaint).filter(Complaint.user_id == u.id).count()
        # Fetch reports
        reports = db.query(UserReport).filter(UserReport.user_id == u.id).all()
        report_list = [
            {
                "reason": r.reason,
                "created_at": r.created_at.isoformat() if r.created_at else None,
                "officer_id": r.officer_id
            } for r in reports
        ]
        
        result.append({
            "id": u.id,
            "name": u.name,
            "email": u.email,
            "phone_number": u.phone_number,
            "address": u.address,
            "city": u.city,
            "state": u.state,
            "pincode": u.pincode,
            "is_suspended": u.is_suspended,
            "complaint_count": complaint_count,
            "report_count": len(report_list),
            "reports": report_list,
            "aadhaar_number": u.aadhaar_number,
            "created_at": u.created_at.isoformat() if u.created_at else None
        })
        
    return result





def create_officer_minimal(db: Session, name: str, email: str, employee_id: str, department: str, password: str):
    """Admin creates officer account with just login credentials"""
    from security import get_password_hash
    password_hash = get_password_hash(password)
    
    db_officer = Officer(
        name=name,
        email=email,
        employee_id=employee_id,
        department=department,
        password_hash=password_hash,
        is_active=True,
        profile_completed=False
    )
    db.add(db_officer)
    db.commit()
    db.refresh(db_officer)
    return db_officer

def update_officer_profile(db: Session, officer_id: int, name: str, department: str, phone_number: str = None, designation: str = None, govt_id_path: str = None):
    """Officer updates their profile information"""
    db_officer = db.query(Officer).filter(Officer.id == officer_id).first()
    if db_officer:
        db_officer.name = name
        db_officer.department = department
        if phone_number is not None:
            db_officer.phone_number = phone_number
        if designation is not None:
            db_officer.designation = designation
        if govt_id_path is not None:
            db_officer.govt_id_path = govt_id_path
            
        db_officer.profile_completed = True
        db.commit()
        db.refresh(db_officer)
        return db_officer
    return None

def delete_officer(db: Session, officer_id: int):
    """Admin deletes an officer account"""
    db_officer = db.query(Officer).filter(Officer.id == officer_id).first()
    if db_officer:
        # Check if officer has assigned complaints - handle as needed
        # For now, just delete
        db.delete(db_officer)
        db.commit()
        return True
    return False

def get_all_complaints(db: Session, skip: int = 0, limit: int = 100):
    """Get all complaints system-wide"""
    return db.query(Complaint).order_by(Complaint.created_at.desc()).offset(skip).limit(limit).all()


def get_system_analytics(db: Session):
    """Calculate system-wide statistics"""
    from sqlalchemy import func
    
    total_users = db.query(User).count()
    total_officers = db.query(Officer).count()
    total_complaints = db.query(Complaint).count()
    
    # Status breakdown
    status_counts = db.query(Complaint.status, func.count(Complaint.status)).group_by(Complaint.status).all()
    status_dict = {status: count for status, count in status_counts}
    
    # Department breakdown
    dept_counts = db.query(Complaint.final_department, func.count(Complaint.final_department)).group_by(Complaint.final_department).all()
    dept_dict = {dept: count for dept, count in dept_counts if dept}
    
    # Urgency breakdown
    high_urgency = db.query(Complaint).filter(Complaint.ai_urgency == 'High').count()
    
    return {
        "total_users": total_users,
        "total_officers": total_officers,
        "total_complaints": total_complaints,
        "complaints_by_status": status_dict,
        "complaints_by_department": dept_dict,
        "high_urgency_count": high_urgency
    }


def get_complaint_detail(db: Session, complaint_id: int):
    """Fetch complaint with all updates and relations for timeline"""
    complaint = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not complaint:
        return None
        
    # Map updates to include officer names
    detailed_updates = []
    for up in complaint.updates:
        detailed_updates.append({
            "id": up.id,
            "update_text": up.update_text,
            "status_changed_from": up.status_changed_from,
            "status_changed_to": up.status_changed_to,
            "officer_name": up.officer.name if up.officer else "Unknown",
            "created_at": up.created_at
        })
    
    # Sort updates by date
    detailed_updates.sort(key=lambda x: x['created_at'], reverse=True)

    return {
        "id": complaint.id,
        "tracking_id": complaint.tracking_id,
        "text": complaint.text,
        "selected_department": complaint.selected_department,
        "ai_category": complaint.ai_category,
        "ai_urgency": complaint.ai_urgency,
        "delay_risk_label": complaint.delay_risk_label,
        "delay_risk_score": complaint.delay_risk_score,
        "status": complaint.status,
        "assigned_officer_name": complaint.assigned_officer.name if complaint.assigned_officer else None,
        "latitude": complaint.latitude,
        "longitude": complaint.longitude,
        "location_address": complaint.location_address,
        "incident_location": complaint.incident_location,
        "created_at": complaint.created_at,
        "resolved_at": complaint.resolved_at,
        "updates": detailed_updates,
        "user_name": complaint.user.name if complaint.user else "Citizen",
        "user_phone": complaint.user.phone_number if complaint.user else None
    }