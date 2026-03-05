import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // For Desktop/Chrome:
  static const String baseUrl = 'http://127.0.0.1:8000';

  // For Android Emulator:
  // static const String baseUrl = 'http://10.0.2.2:8000';

  // For Real Android Device (use your PC's IP):
  // static const String baseUrl = 'http://192.168.1.X:8000'; 

  /// Firebase login
  Future<Map<String, dynamic>?> firebaseLogin(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/firebase'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Firebase login error: $e');
      return null;
    }
  }


  Future<List<dynamic>?> getChatMessages(int complaintId) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/$complaintId/messages'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  } catch (e) {
    print('Get chat messages error: $e');
    return null;
  }
}

Future<bool> sendChatMessage(int complaintId, Map<String, dynamic> messageData) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/$complaintId/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(messageData),
    );
    return response.statusCode == 200;
  } catch (e) {
    print('Send chat message error: $e');
    return false;
  }
}


Future<bool> rateComplaint(
  int complaintId,
  int userId,
  int rating,
  String? feedback,
) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/complaints/$complaintId/rate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'rating': rating,
        'feedback': feedback,
      }),
    );
    return response.statusCode == 200;
  } catch (e) {
    print('Rate complaint error: $e');
    return false;
  }
}

Future<Map<String, dynamic>?> getComplaintRating(int complaintId) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/complaints/$complaintId/rating'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  } catch (e) {
    print('Get rating error: $e');
    return null;
  }
}

Future<int> getUnreadChatCount(int complaintId, String userType) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/$complaintId/unread-count?user_type=$userType'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['unread_count'] ?? 0;
    }
    return 0;
  } catch (e) {
    print('Get unread count error: $e');
    return 0;
  }
}

  /// Update user profile
  Future<Map<String, dynamic>?> updateProfile(
    int userId,
    Map<String, dynamic> profileData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Update profile error: $e');
      return null;
    }
  }

  /// Submit complaint
  Future<Map<String, dynamic>?> submitComplaint(
    int userId,
    String text,
    String selectedDepartment, {
    double? latitude,
    double? longitude,
    String? locationAddress,
  }) async {
    try {
      final body = {
        'text': text,
        'selected_department': selectedDepartment,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (locationAddress != null) 'location_address': locationAddress,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/complaints/submit?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Submit complaint error: $e');
      return null;
    }
  }

  /// Get user's complaints
  Future<List<dynamic>?> getMyComplaints(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/complaints/my/$userId'),
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

  /// Get notifications
  Future<List<dynamic>?> getNotifications(int userId, {bool unreadOnly = false}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/$userId?unread_only=$unreadOnly'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get notifications error: $e');
      return null;
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationRead(int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Mark notification read error: $e');
      return false;
    }
  }

  /// Get chat message history
  Future<List<dynamic>> getChatMessages(int complaintId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/$complaintId/messages'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get chat messages error: $e');
      return [];
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/$userId/unread-count'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unread_count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Get unread count error: $e');
      return 0;
    }
  }

  /// Rate a resolved complaint
  Future<bool> rateComplaint(int complaintId, int userId, int rating, String? feedback) async {
    try {
      final body = {
        'rating': rating,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/complaints/$complaintId/rate?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Rate complaint error: $e');
      return false;
    }
  }
}