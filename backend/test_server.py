"""Minimal test to verify Socket.IO ASGI wrapper works with uvicorn"""
import socketio
from fastapi import FastAPI

# Create Socket.IO server
sio = socketio.AsyncServer(async_mode="asgi", cors_allowed_origins="*")

@sio.event
async def connect(sid, environ):
    print(f"CONNECTED: {sid}")
    return True

# Create FastAPI
fastapi_app = FastAPI()

@fastapi_app.get("/")
async def root():
    return {"message": "hello"}

# Wrap
app = socketio.ASGIApp(sio, other_asgi_app=fastapi_app, socketio_path='socket.io')
print(f"[TEST SERVER] app type: {type(app)}")
print(f"[TEST SERVER] engineio_path: {app.engineio_path}")
