import sys
# Set encoding for Windows console
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

from database import SessionLocal
from models import Officer
from security import get_password_hash

def seed_officers():
    db = SessionLocal()
    
    test_officers = [
        {
            "email": "officer@test.com",
            "password": "password123",
            "name": "Test Officer",
            "employee_id": "EMP001",
            "department": "Power Department",
            "designation": "Senior Officer",
            "phone_number": "+91 9876543210"
        },
        {
            "email": "corruption@test.com",
            "password": "corruption123",
            "name": "Vigilance Officer",
            "employee_id": "EMP002",
            "department": "Vigilance Department",
            "designation": "Inspector",
            "phone_number": "+91 9876543211"
        },
        {
            "email": "admin@test.com",
            "password": "admin123",
            "name": "System Admin",
            "employee_id": "ADM001",
            "department": "Admin",
            "designation": "Chief Administrator",
            "phone_number": "+91 9999999999"
        }
    ]

    for data in test_officers:
        email = data["email"]
        existing = db.query(Officer).filter(Officer.email == email).first()
        
        if existing:
            print(f"Updating existing officer: {email}")
            existing.password_hash = get_password_hash(data["password"])
            existing.name = data["name"]
            existing.department = data["department"]
            existing.designation = data["designation"]
            existing.phone_number = data["phone_number"]
        else:
            print(f"Creating new officer: {email}")
            new_officer = Officer(
                email=email,
                password_hash=get_password_hash(data["password"]),
                name=data["name"],
                employee_id=data["employee_id"],
                department=data["department"],
                designation=data["designation"],
                phone_number=data["phone_number"],
                is_active=True
            )
            db.add(new_officer)
    
    try:
        db.commit()
        print("Success: All test officers seeded!")
    except Exception as e:
        db.rollback()
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_officers()
