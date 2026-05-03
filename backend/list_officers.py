from database import SessionLocal
from models import Officer

db = SessionLocal()
officers = db.query(Officer).all()
print("List of Officers in Database:")
for o in officers:
    print(f"ID: {o.id} | Email: {o.email} | Name: {o.name} | Dept: {o.department}")
if not any(o.department == "Admin" for o in officers):
    print("\n[WARNING] NO ADMIN USER FOUND (Dept must be 'Admin')")
else:
    print("\n[SUCCESS] ADMIN USER FOUND!")
db.close()
