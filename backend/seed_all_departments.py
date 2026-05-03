import sys
import os

# Ensure we can import from the database and models
from database import SessionLocal
from models import Officer
from security import get_password_hash

def seed_all_officers():
    db = SessionLocal()
    
    # Define a comprehensive list of officers for all departments
    # Admin is included as a separate role/dept as per the system design
    officers_data = [
        {
            "email": "power@test.com",
            "password": "password123",
            "name": "Power Dept Officer",
            "employee_id": "OFF_PWR_001",
            "department": "Power Department",
            "designation": "Executive Engineer",
            "phone_number": "+91 9876543201"
        },
        {
            "email": "water@test.com",
            "password": "password123",
            "name": "Water Dept Officer",
            "employee_id": "OFF_WTR_001",
            "department": "Water Department",
            "designation": "Superintending Engineer",
            "phone_number": "+91 9876543202"
        },
        {
            "email": "municipal@test.com",
            "password": "password123",
            "name": "Municipal Officer",
            "employee_id": "OFF_MUN_001",
            "department": "Municipal Services",
            "designation": "Zonal Commissioner",
            "phone_number": "+91 9876543203"
        },
        {
            "email": "health@test.com",
            "password": "password123",
            "name": "Health Officer",
            "employee_id": "OFF_HLT_001",
            "department": "Health Department",
            "designation": "Medical Officer",
            "phone_number": "+91 9876543204"
        },
        {
            "email": "corruption@test.com",
            "password": "corruption123",
            "name": "Vigilance Officer",
            "employee_id": "OFF_VIG_001",
            "department": "Vigilance Department",
            "designation": "Anti-Corruption Inspector",
            "phone_number": "+91 9876543205"
        },
        {
            "email": "officer@test.com",
            "password": "password123",
            "name": "General Power Officer",
            "employee_id": "OFF_GEN_001",
            "department": "Power Department",
            "designation": "Field Officer",
            "phone_number": "+91 9876543206"
        },
        {
            "email": "police@test.com",
            "password": "password123",
            "name": "Police Dept Officer",
            "employee_id": "OFF_POL_001",
            "department": "Police Department",
            "designation": "Police Inspector",
            "phone_number": "+91 9876543206"
        },
        {
            "email": "admin@test.com",
            "password": "admin123",
            "name": "System Administrator",
            "employee_id": "ADM_001",
            "department": "Admin",
            "designation": "IT Administrator",
            "phone_number": "+91 9999999999"
        }
    ]

    print("--- Seeding Officers and Admin for SevaSetu ---")

    for data in officers_data:
        email = data["email"]
        # Check if officer already exists
        existing = db.query(Officer).filter(Officer.email == email).first()
        
        if existing:
            print(f"Updating existing record: {email} ({data['department']})")
            existing.password_hash = get_password_hash(data["password"])
            existing.name = data["name"]
            existing.department = data["department"]
            existing.designation = data["designation"]
            existing.phone_number = data["phone_number"]
        else:
            print(f"Creating new record: {email} ({data['department']})")
            new_officer = Officer(
                email=email,
                password_hash=get_password_hash(data["password"]),
                name=data["name"],
                employee_id=data["employee_id"],
                department=data["department"],
                designation=data["designation"],
                phone_number=data["phone_number"],
                is_active=True,
                profile_completed=True
            )
            db.add(new_officer)
    
    try:
        db.commit()
        print("\nSUCCESS: All department officers and admin have been seeded!")
        print("-" * 55)
        print(f"{'Department':<25} | {'Email':<20} | {'Password'}")
        print("-" * 55)
        for d in officers_data:
            print(f"{d['department']:<25} | {d['email']:<20} | {d['password']}")
        print("-" * 55)
    except Exception as e:
        db.rollback()
        print(f"ERROR during seeding: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_all_officers()
