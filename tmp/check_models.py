with open(r'c:\Projects\Grievance Intelligence System\backend\models.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()
    for i, line in enumerate(lines):
        if 'delay_risk_score' in line:
            print(f"Line {i+1}: {repr(line)}")
