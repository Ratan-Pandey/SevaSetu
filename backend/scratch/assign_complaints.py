
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database import SessionLocal
import models
import crud

def assign_unassigned_complaints():
    db = SessionLocal()
    try:
        # Find unassigned complaints
        unassigned = db.query(models.Complaint).filter(models.Complaint.assigned_officer_id == None).all()
        print(f"Found {len(unassigned)} unassigned complaints")
        
        for c in unassigned:
            print(f"Assigning complaint {c.id} (Dept: {c.selected_department})...")
            officer_id = crud.get_least_busy_officer(db, c.selected_department)
            if officer_id:
                c.assigned_officer_id = officer_id
                c.status = "under_review"
                print(f"  Assigned to officer ID {officer_id}")
            else:
                print(f"  No officer found for department '{c.selected_department}'")
        
        db.commit()
        print("[SUCCESS] Assignment complete")
            
    finally:
        db.close()

if __name__ == "__main__":
    assign_unassigned_complaints()
