from sqlalchemy import create_engine, text
from datetime import datetime

DATABASE_URL = "postgresql://postgres:Ratn%402305@localhost:5432/grievance_db"
engine = create_engine(DATABASE_URL)

with engine.connect() as conn:
    # 1. Update 'resolved' complaints
    print("Backfilling 'resolved' complaints...")
    res = conn.execute(text("""
        UPDATE complaints 
        SET resolved_at = COALESCE(
            (SELECT created_at FROM complaint_updates WHERE complaint_id = complaints.id ORDER BY created_at DESC LIMIT 1),
            created_at
        )
        WHERE status = 'resolved' AND resolved_at IS NULL
    """))
    conn.commit()
    print(f"Updated resolved rows.")

    # 2. Update 'closed_by_user' complaints
    print("Backfilling 'closed_by_user' complaints...")
    res = conn.execute(text("""
        UPDATE complaints 
        SET resolved_at = COALESCE(
            (SELECT created_at FROM complaint_updates WHERE complaint_id = complaints.id ORDER BY created_at DESC LIMIT 1),
            created_at
        )
        WHERE status = 'closed_by_user' AND resolved_at IS NULL
    """))
    conn.commit()
    print(f"Updated closed_by_user rows.")
