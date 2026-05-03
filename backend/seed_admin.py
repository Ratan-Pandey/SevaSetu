from database import SessionLocal
from models import Officer
from security import get_password_hash

db = SessionLocal()

# Check if admin already exists
existing = db.query(Officer).filter(Officer.email == "admin@test.com").first()
if existing:
    db.delete(existing)
    db.commit()

admin = Officer(
    email="admin@test.com",
    password_hash=get_password_hash("admin123"),
    name="System Admin",
    employee_id="ADM001",
    department="Admin",
    designation="Chief Administrator",
    is_active=True
)

db.add(admin)
db.commit()
print("✅ Admin created successfully!")
print("Email: admin@test.com")
print("Password: admin123")
db.close()
