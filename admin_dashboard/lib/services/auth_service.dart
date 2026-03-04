import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  Map<String, dynamic>? _adminData;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get adminData => _adminData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _adminData != null;

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final apiService = ApiService();
      final response = await apiService.adminLogin(email, password);

      if (response != null) {
        _adminData = response;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('admin_id', response['user_id']);
        await prefs.setString('email', response['email']);
        await prefs.setString('name', response['name']);
        
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadAdminData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('admin_id')) {
        _adminData = {
          'user_id': prefs.getInt('admin_id'),
          'email': prefs.getString('email'),
          'name': prefs.getString('name'),
        };
        notifyListeners();
      }
    } catch (e) {
      print('Load admin data error: $e');
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