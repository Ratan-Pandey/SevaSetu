from database import engine
from sqlalchemy import text

with engine.connect() as conn:
    conn.execute(text("ALTER TABLE officers ADD COLUMN govt_id_path VARCHAR(255);"))
    conn.execute(text("ALTER TABLE officers ADD COLUMN profile_completed BOOLEAN DEFAULT FALSE;"))
    conn.commit()
    print("Columns added successfully")
