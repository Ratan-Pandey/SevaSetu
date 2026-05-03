import sys
sys.stdout.reconfigure(encoding='utf-8')
import urllib.request
import urllib.error

try:
    print('Root OK:', urllib.request.urlopen('http://127.0.0.1:8000/').read().decode()[:100])
    req = urllib.request.Request('http://127.0.0.1:8000/socket.io/?EIO=4&transport=polling')
    print('Socket OK:', urllib.request.urlopen(req).status)
except urllib.error.HTTPError as e:
    print('HTTP Error:', e.code, e.read().decode())
except Exception as e:
    print('Error:', e)
