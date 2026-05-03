"""
Firebase Admin SDK Configuration
For verifying Firebase Auth tokens from mobile app
"""

import firebase_admin
from firebase_admin import credentials, auth
from typing import Optional

import os
import json

# Initialize Firebase Admin SDK
def initialize_firebase():
    try:
        # Try to get app to see if already initialized
        firebase_admin.get_app()
        print("✅ Firebase already initialized")
        return
    except ValueError:
        pass

    # 1. Try to load from environment variable (Best for production)
    service_account_info = os.getenv("FIREBASE_SERVICE_ACCOUNT")
    if service_account_info:
        try:
            cert_dict = json.loads(service_account_info)
            cred = credentials.Certificate(cert_dict)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK initialized from Environment Variable")
            return
        except Exception as e:
            print(f"⚠️ Failed to initialize Firebase from Env Var: {e}")

    # 2. Try to load from local file
    file_path = "firebase-service-account.json"
    if os.path.exists(file_path):
        try:
            cred = credentials.Certificate(file_path)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK initialized from local file")
        except Exception as e:
            print(f"⚠️ Failed to initialize Firebase from local file: {e}")
    else:
        print("⚠️ Firebase service account not found. Firebase features will be disabled or use MOCK.")


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