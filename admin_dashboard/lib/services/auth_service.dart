import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService apiService = ApiService(); // ✅ ADDED
  Map<String, dynamic>? _adminData;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get adminData => _adminData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _adminData != null;
  String? get token => _adminData?['access_token'];

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await apiService.adminLogin(email, password);
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
        _adminData = response;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response['access_token']);
        await prefs.setInt('admin_id', response['officer_id']); // ✅ FIXED KEY
        await prefs.setString('email', response['email']);
        await prefs.setString('name', response['name']);
        
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

  Future<void> loadAdminData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token != null) {
        final verification = await apiService.verifyOfficerToken(token);
        if (verification != null && verification['valid'] == true) {
          _adminData = {
            'user_id': verification['officer_id'],
            'email': verification['email'],
            'name': verification['name'],
            'access_token': token,
          };
          notifyListeners();
          return;
        }
      }
      
      // If we reach here, token is missing or invalid
      await prefs.clear();
      _adminData = null;
      notifyListeners();
    } catch (e) {
      print('Load admin data error: $e');
      _adminData = null;
      notifyListeners();
    }
  }

  int? getAdminId() => _adminData?['user_id'];

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _adminData = null;
      notifyListeners();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}