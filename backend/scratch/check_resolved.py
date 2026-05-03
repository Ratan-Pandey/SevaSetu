from sqlalchemy import create_engine, text
DATABASE_URL = "postgresql://postgres:Ratn%402305@localhost:5432/grievance_db"
engine = create_engine(DATABASE_URL)
with engine.connect() as conn:
    res = conn.execute(text('SELECT tracking_id, status, resolved_at FROM complaints WHERE status = \'resolved\''))
    rows = res.fetchall()
    print(f"Total resolved: {len(rows)}")
    for row in rows:
        print(row)
