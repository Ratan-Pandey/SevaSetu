import sys
sys.stdout.reconfigure(encoding='utf-8')
import urllib.request
import urllib.error

try:
    r = urllib.request.urlopen('http://127.0.0.1:8000/socket.io/?EIO=4&transport=polling')
    print('OK:', r.status, r.read().decode()[:200])
except urllib.error.HTTPError as e:
    print('HTTP Error:', e.code, e.read().decode()[:200])
except Exception as e:
    print('Error:', e)
