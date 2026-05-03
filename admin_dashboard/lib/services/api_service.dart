import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  Future<Map<String, dynamic>?> adminLogin(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/officer/login'), // Using officer login for now
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': email, // OAuth2 expects 'username'
          'password': password,
        },
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('Admin login error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSystemAnalytics({String? token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/summary'),
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('Get analytics error: $e');
      return null;
    }
  }

  Future<List<dynamic>?> getAllComplaints({String? token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/complaints/all'),
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get complaints error: $e');
      return null;
    }
  }
  Future<Map<String, dynamic>?> verifyOfficerToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/officer/verify'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('Verify token error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getComplaintDetail(int id, {required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/complaints/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('Get complaint detail error: $e');
      return null;
    }
  }
}