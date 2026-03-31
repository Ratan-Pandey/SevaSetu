"""
Fix Officer Password Hash
Converts plain text passwords to bcrypt hashes for all officers
"""

from database import SessionLocal
from models import Officer
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def fix_officer_passwords():
    """Fix all officers with plain text passwords"""
    db = SessionLocal()
    
    try:
        officers = db.query(Officer).all()
        
        print("=" * 70)
        print("FIXING OFFICER PASSWORDS".center(70))
        print("=" * 70)
        print()
        
        for officer in officers:
            # Check if password is already hashed (bcrypt hashes start with $2b$)
            if not officer.password_hash.startswith('$2b$'):
                print(f"⚠️ Officer: {officer.email}")
                print(f"   Current hash: {officer.password_hash[:20]}... (plain text)")
                
                # Hash the plain text password
                new_hash = pwd_context.hash(officer.password_hash)
                officer.password_hash = new_hash
                
                print(f"   New hash: {new_hash[:20]}... (bcrypt)")
                print(f"   ✅ Fixed!")
                print()
            else:
                print(f"✅ Officer: {officer.email} - Already hashed correctly")
        
        db.commit()
        
        print()
        print("=" * 70)
        print("✅ ALL PASSWORDS FIXED!".center(70))
        print("=" * 70)
        print()
        print("You can now login with:")
        print("  Email: officer@test.com")
        print("  Password: password123")
        print()
        
    except Exception as e:
        print(f"❌ Error: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    fix_officer_passwords()