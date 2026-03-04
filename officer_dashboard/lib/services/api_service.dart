import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // CHANGE THIS TO YOUR BACKEND URL
  static const String baseUrl = 'http://127.0.0.1:8000';
  // For Android Emulator: 'http://10.0.2.2:8000'
  // For Real Device: 'http://192.168.1.X:8000'

  /// Officer login
  Future<Map<String, dynamic>?> officerLogin(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/officer/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Officer login error: $e');
      return null;
    }
  }

  /// Get officer dashboard stats
  Future<Map<String, dynamic>?> getOfficerDashboard(int officerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/officer/dashboard/$officerId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get dashboard error: $e');
      return null;
    }
  }

  /// Get complaints for officer
  Future<List<dynamic>?> getOfficerComplaints(int officerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/officer/complaints/$officerId'),
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

  /// Assign complaint to officer
  Future<bool> assignComplaint(int complaintId, int officerId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/officer/complaints/$complaintId/assign/$officerId'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Assign complaint error: $e');
      return false;
    }
  }

  /// Update complaint status and add comment
  Future<bool> updateComplaint(
    int complaintId,
    String status,
    String comment,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/officer/complaints/$complaintId/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': status,
          'update_text': comment,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Update complaint error: $e');
      return false;
    }
  }

  /// Get complaint detail
  Future<Map<String, dynamic>?> getComplaintDetail(int complaintId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/complaints/$complaintId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get complaint detail error: $e');
      return null;
    }
  }

  /// Get analytics summary
  Future<Map<String, dynamic>?> getAnalyticsSummary() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/summary'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get analytics error: $e');
      return null;
    }
  }
}