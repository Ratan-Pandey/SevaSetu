
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database import SessionLocal
import models

def check_vigilance():
    db = SessionLocal()
    try:
        # Check officers
        officers = db.query(models.Officer).all()
        print("--- Officers ---")
        for o in officers:
            print(f"ID: {o.id}, Name: {o.name}, Email: {o.email}, Dept: {o.department}")
        
        # Check complaints for Vigilance
        complaints = db.query(models.Complaint).filter(
            models.Complaint.selected_department.ilike("%vigilance%")
        ).all()
        print("\n--- Vigilance Complaints ---")
        if not complaints:
            print("No complaints found for 'Vigilance'")
        for c in complaints:
            print(f"ID: {c.id}, Tracking: {c.tracking_id}, Dept: {c.selected_department}, Assigned Officer: {c.assigned_officer_id}, Status: {c.status}")
            
    finally:
        db.close()

if __name__ == "__main__":
    check_vigilance()
