import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isProfileComplete => _userData?['profile_completed'] ?? false;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    _user = user;
    notifyListeners();
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false; // User cancelled
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      _user = userCredential.user;

      if (_user != null) {
        // Get Firebase ID token
        final idToken = await _user!.getIdToken();
        
        // Register/login with backend
        final apiService = ApiService();
        final response = await apiService.firebaseLogin(idToken!);
        
        if (response != null) {
          _userData = response;
          
          // Save user data locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', response['user_id']);
          await prefs.setString('email', response['email']);
          await prefs.setString('name', response['name']);
          await prefs.setBool('profile_completed', response['profile_completed'] ?? false);
          
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _isLoading = false;
      notifyListeners();
      return false;

    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('Sign in error: $e');
      return false;
    }
  }

  /// Load user data from local storage
  Future<void> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (prefs.containsKey('user_id')) {
        _userData = {
          'user_id': prefs.getInt('user_id'),
          'email': prefs.getString('email'),
          'name': prefs.getString('name'),
          'profile_completed': prefs.getBool('profile_completed') ?? false,
        };
        notifyListeners();
      }
    } catch (e) {
      print('Load user data error: $e');
    }
  }

  /// Update profile completion status
  void updateProfileStatus(bool completed) {
    if (_userData != null) {
      _userData!['profile_completed'] = completed;
      notifyListeners();
      
      // Save to local storage
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('profile_completed', completed);
      });
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      _user = null;
      _userData = null;
      notifyListeners();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  /// Get current user ID
  int? getUserId() {
    return _userData?['user_id'];
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}