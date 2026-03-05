"""
Create Test Data for Grievance Intelligence System
Adds test officer and sample complaint for testing
"""

from database import SessionLocal
from models import Officer, User, Complaint, generate_tracking_id
from passlib.context import CryptContext
from datetime import datetime

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def create_test_officer():
    """Create a test officer for login testing"""
    db = SessionLocal()
    
    try:
        # Check if test officer already exists
        existing = db.query(Officer).filter(Officer.email == "officer@test.com").first()
        if existing:
            print("✅ Test officer already exists")
            return existing
        
        # Create test officer
        test_officer = Officer(
            email="officer@test.com",
            password_hash=pwd_context.hash("password123"),
            name="Test Officer",
            employee_id="EMP001",
            department="Power Department",
            designation="Senior Officer",
            phone_number="+91 9876543210",
            is_active=True
        )
        
        db.add(test_officer)
        db.commit()
        db.refresh(test_officer)
        
        print("✅ Test officer created successfully")
        print(f"   Email: officer@test.com")
        print(f"   Password: password123")
        print(f"   Department: Power Department")
        
        return test_officer
        
    except Exception as e:
        print(f"❌ Error creating test officer: {e}")
        db.rollback()
        return None
    finally:
        db.close()


def create_sample_user():
    """Create a sample user for testing"""
    db = SessionLocal()
    
    try:
        # Check if test user exists
        existing = db.query(User).filter(User.email == "testuser@gmail.com").first()
        if existing:
            print("✅ Test user already exists")
            return existing
        
        # Create test user
        test_user = User(
            firebase_uid="test_firebase_uid_12345",
            email="testuser@gmail.com",
            name="Test User",
            phone_number="+91 9876543211",
            address="123 Test Street, Test Area",
            pincode="201301",
            city="Noida",
            state="Uttar Pradesh",
            is_active=True,
            profile_completed=True
        )
        
        db.add(test_user)
        db.commit()
        db.refresh(test_user)
        
        print("✅ Test user created successfully")
        print(f"   Email: testuser@gmail.com")
        print(f"   Name: Test User")
        
        return test_user
        
    except Exception as e:
        print(f"❌ Error creating test user: {e}")
        db.rollback()
        return None
    finally:
        db.close()


def create_sample_complaint(user_id):
    """Create a sample complaint for testing"""
    db = SessionLocal()
    
    try:
        # Check if sample complaint exists
        existing = db.query(Complaint).filter(Complaint.user_id == user_id).first()
        if existing:
            print("✅ Sample complaint already exists")
            return existing
        
        # Create sample complaint
        sample_complaint = Complaint(
            tracking_id=generate_tracking_id(),
            user_id=user_id,
            text="Frequent power cuts in our area for the last three days. No electricity during evening hours. Emergency situation.",
            selected_department="Power Department",
            ai_category="Electricity",
            ai_department="Power Department",
            ai_urgency="High",
            delay_risk_label="Low",
            delay_risk_score=0.25,
            status="submitted",
            created_at=datetime.utcnow()
        )
        
        db.add(sample_complaint)
        db.commit()
        db.refresh(sample_complaint)
        
        print("✅ Sample complaint created successfully")
        print(f"   Tracking ID: {sample_complaint.tracking_id}")
        print(f"   Department: Power Department")
        print(f"   Status: submitted")
        
        return sample_complaint
        
    except Exception as e:
        print(f"❌ Error creating sample complaint: {e}")
        db.rollback()
        return None
    finally:
        db.close()


def main():
    """Main function to create all test data"""
    print("=" * 70)
    print("CREATING TEST DATA FOR GRIEVANCE INTELLIGENCE SYSTEM".center(70))
    print("=" * 70)
    print()
    
    # Create test officer
    print("📝 Creating test officer...")
    officer = create_test_officer()
    print()
    
    # Create test user
    print("📝 Creating test user...")
    user = create_sample_user()
    print()
    
    # Create sample complaint
    if user:
        print("📝 Creating sample complaint...")
        complaint = create_sample_complaint(user.id)
        print()
    
    print("=" * 70)
    print("✅ TEST DATA CREATION COMPLETE!".center(70))
    print("=" * 70)
    print()
    
    print("🎯 NEXT STEPS:")
    print("1. Start backend: python -m uvicorn main:socket_app --reload")
    print("2. Login as officer:")
    print("   - Email: officer@test.com")
    print("   - Password: password123")
    print("3. Or run Flutter apps to test end-to-end")
    print()
    
    print("🔍 DATABASE STATUS:")
    db = SessionLocal()
    try:
        officer_count = db.query(Officer).count()
        user_count = db.query(User).count()
        complaint_count = db.query(Complaint).count()
        
        print(f"   Officers: {officer_count}")
        print(f"   Users: {user_count}")
        print(f"   Complaints: {complaint_count}")
    finally:
        db.close()
    
    print()
    print("=" * 70)


if __name__ == "__main__":
    main()