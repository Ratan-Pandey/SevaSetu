import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  Map<String, dynamic>? _officerData;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get officerData => _officerData;
  Map<String, dynamic>? get currentUser => _officerData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _officerData != null;

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final apiService = ApiService();
      final response = await apiService.officerLogin(email, password);
      print("🔥 LOGIN RESPONSE: $response");

      if (response != null) {
        print("✅ Response not null");
        if (response['access_token'] != null) {
          print("✅ TOKEN FOUND");
        } else {
          print("❌ TOKEN MISSING");
        }
      } else {
        print("❌ RESPONSE NULL");
      }

      if (response != null && response['access_token'] != null) {
        print("✅ TOKEN FOUND");
        _officerData = response;
        
        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response['access_token']);
        await prefs.setInt('officer_id', response['officer_id']);
        await prefs.setString('email', response['email']);
        await prefs.setString('name', response['name']);
        await prefs.setString('department', response['department'] ?? '');
        
        _isLoading = false;
        notifyListeners();
        print("🚀 RETURNING TRUE");
        return true;
      }

      print("❌ RETURNING FALSE");
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print("❌ LOGIN ERROR: $e");
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load officer data from local storage
  Future<void> loadOfficerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (prefs.containsKey('officer_id') && prefs.containsKey('token')) {
        _officerData = {
          'officer_id': prefs.getInt('officer_id'), // ✅ FIXED KEY
          'email': prefs.getString('email'),
          'name': prefs.getString('name'),
          'department': prefs.getString('department'),
        };
        notifyListeners();
      }
    } catch (e) {
      print('Load officer data error: $e');
    }
  }

  /// Get current officer ID
  int? getOfficerId() {
    return _officerData?['officer_id']; // ✅ FIXED KEY
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      _officerData = null;
      notifyListeners();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}