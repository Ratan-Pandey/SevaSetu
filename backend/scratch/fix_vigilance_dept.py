
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database import SessionLocal
import models

def fix_vigilance_dept():
    db = SessionLocal()
    try:
        officer = db.query(models.Officer).filter(models.Officer.email == "corruption@test.com").first()
        if officer:
            print(f"Updating officer {officer.name} department from '{officer.department}' to 'Vigilance Department'")
            officer.department = "Vigilance Department"
            db.commit()
            print("[SUCCESS] Update successful")
        else:
            print("[ERROR] Officer corruption@test.com not found")
            
        # Also check if there are any other officers with "Corruption" dept
        others = db.query(models.Officer).filter(models.Officer.department == "Corruption").all()
        for o in others:
            print(f"Updating officer {o.name} department from '{o.department}' to 'Vigilance Department'")
            o.department = "Vigilance Department"
        if others:
            db.commit()
            print(f"[SUCCESS] Updated {len(others)} more officers")
            
    finally:
        db.close()

if __name__ == "__main__":
    fix_vigilance_dept()
