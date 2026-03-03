"""
Firebase Admin SDK Configuration
For verifying Firebase Auth tokens from mobile app
"""

import firebase_admin
from firebase_admin import credentials, auth
from typing import Optional

# Initialize Firebase Admin SDK
def initialize_firebase():
    """
    Initialize Firebase Admin SDK
    
    IMPORTANT: You need a service account JSON file from Firebase Console
    Steps to get it:
    1. Go to Firebase Console: https://console.firebase.google.com/
    2. Select your project (or create new)
    3. Go to Project Settings > Service Accounts
    4. Click "Generate New Private Key"
    5. Save as firebase-service-account.json in backend folder
    """
    try:
        # Try to initialize (skip if already initialized)
        firebase_admin.get_app()
        print("✅ Firebase already initialized")
    except ValueError:
        # Initialize with service account
        cred = credentials.Certificate("firebase-service-account.json")
        firebase_admin.initialize_app(cred)
        print("✅ Firebase Admin SDK initialized")


def verify_firebase_token(id_token: str) -> Optional[dict]:
    """
    Verify Firebase ID token from mobile app
    
    Args:
        id_token: Firebase ID token from mobile app
        
    Returns:
        dict with user info (uid, email, name) or None if invalid
    """
    try:
        # Verify the token
        decoded_token = auth.verify_id_token(id_token)
        
        return {
            'uid': decoded_token['uid'],
            'email': decoded_token.get('email'),
            'name': decoded_token.get('name', ''),
            'email_verified': decoded_token.get('email_verified', False)
        }
    except Exception as e:
        print(f"❌ Firebase token verification failed: {e}")
        return None


# Mock verification for testing WITHOUT Firebase
def verify_firebase_token_mock(id_token: str) -> Optional[dict]:
    """
    Mock Firebase verification for testing
    USE THIS during development if you don't have Firebase setup yet
    
    Returns fake user data for any token
    """
    if not id_token or len(id_token) < 10:
        return None
    
    # Return mock user data
    return {
        'uid': f"mock_uid_{id_token[:10]}",
        'email': "testuser@gmail.com",
        'name': "Test User",
        'email_verified': True
    }


# Toggle between real and mock
USE_MOCK = False  # Set to False when you have Firebase configured

def verify_token(id_token: str) -> Optional[dict]:
    """
    Main verification function
    Switches between mock and real based on USE_MOCK flag
    """
    if USE_MOCK:
        return verify_firebase_token_mock(id_token)
    else:
        return verify_firebase_token(id_token)