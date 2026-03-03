from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Database URL - Update with your PostgreSQL credentials
DATABASE_URL = "postgresql://postgres:Ratn123@localhost:5432/grievance_db"

# For SQLite (simpler for testing):
# DATABASE_URL = "sqlite:///./grievance.db"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    """Dependency for database sessions"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()