"""
Phase 4: Real-time Chat WebSocket Server
Handles WebSocket connections for officer-user chat
"""

import socketio
from typing import Dict, Set
from datetime import datetime

# Create Socket.IO server
sio = socketio.AsyncServer(
    async_mode='asgi',
    cors_allowed_origins='*'
)

# Store connected users
connected_users: Dict[int, str] = {}  # user_id -> sid
complaint_rooms: Dict[int, Set[str]] = {}  # complaint_id -> set of sids

@sio.event
async def connect(sid, environ):
    """Handle client connection"""
    print(f'✅ Client connected: {sid}')

@sio.event
async def disconnect(sid):
    """Handle client disconnection"""
    print(f'❌ Client disconnected: {sid}')
    # Remove from connected users
    user_id_to_remove = None
    for user_id, user_sid in connected_users.items():
        if user_sid == sid:
            user_id_to_remove = user_id
            break
    if user_id_to_remove:
        del connected_users[user_id_to_remove]

@sio.event
async def join_chat(sid, data):
    """User or officer joins a complaint chat room"""
    complaint_id = data.get('complaint_id')
    user_id = data.get('user_id')
    user_type = data.get('user_type')  # 'user' or 'officer'
    
    room = f'complaint_{complaint_id}'
    await sio.enter_room(sid, room)
    
    connected_users[user_id] = sid
    
    if complaint_id not in complaint_rooms:
        complaint_rooms[complaint_id] = set()
    complaint_rooms[complaint_id].add(sid)
    
    print(f'💬 {user_type} {user_id} joined chat for complaint {complaint_id}')
    
    # Notify others in room
    await sio.emit('user_joined', {
        'user_id': user_id,
        'user_type': user_type
    }, room=room, skip_sid=sid)

@sio.event
async def send_message(sid, data):
    """Send a message in a complaint chat"""
    complaint_id = data.get('complaint_id')
    sender_id = data.get('sender_id')
    sender_type = data.get('sender_type')
    message = data.get('message')
    
    room = f'complaint_{complaint_id}'
    
    # Broadcast to room
    await sio.emit('new_message', {
        'complaint_id': complaint_id,
        'sender_id': sender_id,
        'sender_type': sender_type,
        'message': message,
        'timestamp': datetime.utcnow().isoformat()
    }, room=room)
    
    print(f'📨 Message sent in complaint {complaint_id}')

@sio.event
async def typing(sid, data):
    """User is typing indicator"""
    complaint_id = data.get('complaint_id')
    user_type = data.get('user_type')
    
    room = f'complaint_{complaint_id}'
    
    await sio.emit('user_typing', {
        'user_type': user_type,
        'is_typing': data.get('is_typing', True)
    }, room=room, skip_sid=sid)

@sio.event
async def mark_read(sid, data):
    """Mark messages as read"""
    complaint_id = data.get('complaint_id')
    room = f'complaint_{complaint_id}'
    
    await sio.emit('messages_read', {
        'complaint_id': complaint_id
    }, room=room, skip_sid=sid)

@sio.event
async def leave_chat(sid, data):
    """User or officer leaves chat"""
    complaint_id = data.get('complaint_id')
    room = f'complaint_{complaint_id}'
    
    await sio.leave_room(sid, room)
    print(f'🚪 User left chat for complaint {complaint_id}')