import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Load .env file for local development
load_dotenv()

# Database URL - Uses environment variable 'DATABASE_URL' for production
# Fallback to local SQLite if no environment variable is set
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./grievance.db")

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