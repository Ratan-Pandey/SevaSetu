import requests
try:
    r = requests.get('http://127.0.0.1:8000/auth/officer/verify', headers={'Authorization': 'Bearer test'})
    print(f"Status: {r.status_code}")
except Exception as e:
    print(f"Error: {e}")
