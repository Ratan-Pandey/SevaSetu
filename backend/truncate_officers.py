import os
from database import engine
from sqlalchemy import text
from dotenv import load_dotenv

# Force load .env from the current directory
load_dotenv()

def truncate_officers():
    try:
        # Check which database we are connected to
        db_url = str(engine.url)
        is_postgres = "postgresql" in db_url
        
        with engine.connect() as conn:
            print(f"⏳ Connecting to {'Supabase (Postgres)' if is_postgres else 'Local (SQLite)'}...")
            print("⏳ Truncating officers table...")
            
            if is_postgres:
                # Postgres command
                conn.execute(text("TRUNCATE TABLE officers RESTART IDENTITY CASCADE;"))
            else:
                # SQLite command
                conn.execute(text("DELETE FROM officers;"))
                # Reset auto-increment in SQLite
                conn.execute(text("DELETE FROM sqlite_sequence WHERE name='officers';"))
                
            conn.commit()
            print("✅ Officers table truncated successfully!")
    except Exception as e:
        print(f"❌ Error during truncation: {e}")

if __name__ == "__main__":
    truncate_officers()
