import os
from database import SessionLocal
from models import Officer
import bcrypt

def migrate_passwords():
    db = SessionLocal()
    try:
        officers = db.query(Officer).all()
        count = 0
        for officer in officers:
            # Check if it's already a hash
            if not officer.password_hash.startswith('$2'):
                pwd = str(officer.password_hash).strip()
                print(f"Hashing password for: {officer.email}")
                
                # Use bcrypt directly
                salt = bcrypt.gensalt()
                hashed = bcrypt.hashpw(pwd.encode('utf-8'), salt)
                officer.password_hash = hashed.decode('utf-8')
                count += 1
        
        db.commit()
        print(f"Successfully migrated {count} passwords.")
    except Exception as e:
        db.rollback()
        print(f"Error: {str(e)}")
    finally:
        db.close()

if __name__ == "__main__":
    migrate_passwords()
