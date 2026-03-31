from database import SessionLocal
from models import Officer
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
db = SessionLocal()

# Delete and recreate officer with proper hash
officer = db.query(Officer).filter(Officer.email == "officer@test.com").first()
if officer:
    db.delete(officer)
    db.commit()

new_officer = Officer(
    email="officer@test.com",
    password_hash=pwd_context.hash("password123"),
    name="Test Officer",
    employee_id="EMP002",
    department="Power Department",
    designation="Senior Officer",
    phone_number="+91 9876543210",
    is_active=True
)

db.add(new_officer)
db.commit()
print("✅ Officer created with proper password!")
db.close()
exit()