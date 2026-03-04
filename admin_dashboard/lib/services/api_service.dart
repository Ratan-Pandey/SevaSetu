import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  Future<Map<String, dynamic>?> adminLogin(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/officer/login'), // Using officer login for now
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('Admin login error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSystemAnalytics() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/analytics/summary'));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('Get analytics error: $e');
      return null;
    }
  }

  Future<List<dynamic>?> getAllComplaints() async {
    try {
      // For now, get from analytics endpoint
      final response = await http.get(Uri.parse('$baseUrl/analytics/summary'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['complaints'] ?? [];
      }
      return null;
    } catch (e) {
      print('Get complaints error: $e');
      return null;
    }
  }
}