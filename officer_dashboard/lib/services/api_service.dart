// officer/services/api_service.dart
//
// Seva Setu — Officer App API Service
// All endpoints wired to the FastAPI backend.

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ── Base URL ────────────────────────────────────────────────────────────────
  // Local dev (web / iOS simulator):
  static const String baseUrl = 'http://127.0.0.1:8000';
  // Android Emulator:  'http://10.0.2.2:8000'
  // Real device:       'http://192.168.X.X:8000'  ← replace with your PC's LAN IP

  // ── Auth ────────────────────────────────────────────────────────────────────

  /// Officer login — returns access_token, officer_id, name, department, role
  Future<Map<String, dynamic>?> officerLogin(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/officer/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password}, // OAuth2 form
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      print('❌ officerLogin ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      print('officerLogin error: $e');
      return null;
    }
  }

  /// Verify stored JWT is still valid.  Returns officer info or null.
  Future<Map<String, dynamic>?> verifyToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/officer/verify'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('verifyToken error: $e');
      return null;
    }
  }

  // ── Dashboard & Stats ───────────────────────────────────────────────────────

  /// Officer dashboard: total / pending / in_progress / resolved counts
  Future<Map<String, dynamic>?> getOfficerDashboard(int officerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/officer/dashboard/$officerId'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      print('❌ getOfficerDashboard ${response.statusCode}');
      return null;
    } catch (e) {
      print('getOfficerDashboard error: $e');
      return null;
    }
  }

  /// Priority-based stats for the officer's department
  Future<Map<String, dynamic>?> getOfficerStats(int officerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/officer/stats/$officerId'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('getOfficerStats error: $e');
      return null;
    }
  }

  // ── Complaints ──────────────────────────────────────────────────────────────

  /// Get complaints list for officer (filterable)
  Future<List<dynamic>?> getOfficerComplaints(
    int officerId, {
    String search   = '',
    String sortBy   = 'priority',
    String priority = '',
    String? status,
  }) async {
    try {
      final params = {
        'search':   search,
        'sort_by':  sortBy,
        'priority': priority,
        if (status != null) 'status': status,
      };
      final uri = Uri.parse('$baseUrl/officer/complaints/$officerId')
          .replace(queryParameters: params);
      final response = await http.get(uri);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('getOfficerComplaints error: $e');
      return null;
    }
  }

  /// Get full complaint detail (with updates list)
  Future<Map<String, dynamic>?> getComplaintDetail(int complaintId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/complaints/$complaintId'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('getComplaintDetail error: $e');
      return null;
    }
  }

  /// Get user profile details
  Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/profile'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('getUserProfile error: $e');
      return null;
    }
  }

  /// Report a user
  Future<Map<String, dynamic>?> reportUser(int userId, int officerId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/officer/user/$userId/report?officer_id=$officerId&reason=${Uri.encodeComponent(reason)}'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('reportUser error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Lift user suspension
  Future<bool> liftSuspension(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/officer/user/$userId/lift-suspension'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('liftSuspension error: $e');
      return false;
    }
  }

  /// Update complaint status + add officer comment.
  ///
  /// FIX: The backend's ComplaintStatusUpdate model requires `officer_id`.
  /// The original code omitted it, causing a 422 Unprocessable Entity error.
  Future<bool> updateComplaint(
    int complaintId,
    String status,
    String comment,
    int officerId, // ← REQUIRED — was missing in original
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/officer/complaints/$complaintId/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status':      status,
          'update_text': comment,
          'officer_id':  officerId, // ← FIXED: now included
        }),
      );
      if (response.statusCode != 200) {
        print('❌ updateComplaint ${response.statusCode}: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      print('updateComplaint error: $e');
      return false;
    }
  }

  /// Assign a complaint to this officer
  Future<bool> assignComplaint(int complaintId, int officerId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/officer/complaints/$complaintId/assign/$officerId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('assignComplaint error: $e');
      return false;
    }
  }

  // ── Analytics ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getAnalyticsSummary() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/summary'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('getAnalyticsSummary error: $e');
      return null;
    }
  }

  // ── Notifications ───────────────────────────────────────────────────────────

  Future<List<dynamic>?> getOfficerNotifications(int officerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/officer/$officerId'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('getOfficerNotifications error: $e');
      return null;
    }
  }

  Future<bool> markNotificationRead(int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('markNotificationRead error: $e');
      return false;
    }
  }

  // ── Ratings ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getOfficerRatings(int officerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/officer/$officerId/ratings'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('getOfficerRatings error: $e');
      return null;
    }
  }

  // ── Chat ────────────────────────────────────────────────────────────────────

  /// Load full chat history for a complaint (used on screen open)
  Future<List<dynamic>?> getChatHistory(int complaintId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/$complaintId'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('getChatHistory error: $e');
      return null;
    }
  }

  /// Load messages with auto-read marking (used for badge clearing)
  Future<List<dynamic>?> getChatMessages(
    int complaintId,
    String userType,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/$complaintId/messages?user_type=$userType'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('getChatMessages error: $e');
      return null;
    }
  }

  /// HTTP fallback when WebSocket is unavailable
  Future<bool> sendChatMessage(
    int complaintId,
    Map<String, dynamic> messageData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/$complaintId/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(messageData),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('sendChatMessage error: $e');
      return false;
    }
  }

  /// Unread message count badge
  Future<int> getUnreadChatCount(int complaintId, String userType) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/chat/$complaintId/unread-count?user_type=$userType',
        ),
      );
      if (response.statusCode == 200) {
        return (jsonDecode(response.body)['unread_count'] ?? 0) as int;
      }
      return 0;
    } catch (e) {
      print('getUnreadChatCount error: $e');
      return 0;
    }
  }

  /// Online/last-seen presence for both parties in a chat room
  Future<Map<String, dynamic>?> getChatPresence(int complaintId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/$complaintId/presence'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print('getChatPresence error: $e');
      return null;
    }
  }
}