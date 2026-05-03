import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000'; // ⚡ FINAL FIX: Use IP for web reliability

  // For Android Emulator:
  // static const String baseUrl = 'http://10.0.2.2:8000';

  // For Real Android Device (use your PC's IP):
  // static const String baseUrl = 'http://192.168.1.X:8000'; 

  // ============================================================================
  // AUTHENTICATION
  // ============================================================================

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

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return decoded;
      } else {
        print('Update profile error (${response.statusCode}): ${decoded['detail']}');
        return decoded; // Return error map containing 'detail'
      }
    } catch (e) {
      print('Update profile error: $e');
      return null;
    }
  }

  /// Upload Aadhaar image (Cross-Platform)
  Future<String?> uploadAadhaarImage(XFile imageFile) async {
    try {
      print("📤 Uploading Aadhaar image...");
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/image'), // Re-using general image upload
      );

      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: imageFile.name,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            imageFile.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        return data['file_path'];
      }
      return null;
    } catch (e) {
      print('Upload Aadhaar error: $e');
      return null;
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile/$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get user profile error: $e');
      return null;
    }
  }

  // ============================================================================
  // PHASE 4: PUSH NOTIFICATIONS
  // ============================================================================

  /// Save FCM token for push notifications
  Future<bool> saveFCMToken(int userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/$userId/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Save FCM token error: $e');
      return false;
    }
  }

  // ============================================================================
  // COMPLAINTS
  // ============================================================================

  /// Submit complaint with Phase 4 location support
  Future<Map<String, dynamic>?> submitComplaint(Map<String, dynamic> data) async {
    try {
      // 🔑 Get fresh Firebase token for secure submission
      String? token = await AuthService().getFirebaseToken();

      final response = await http.post(
        Uri.parse('$baseUrl/complaints/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print("Response: $result");
        return result;
      } else {
        print("Submit error (${response.statusCode}): ${response.body}");
      }
      return null;
    } catch (e) {
      print('Submit complaint error: $e');
      return null;
    }
  }

  /// Get my complaints
  Future<List<dynamic>?> getMyComplaints(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/complaints/user/$userId'),
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

  /// Cancel a complaint (soft delete)
  Future<bool> cancelComplaint(int complaintId, int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/complaints/$complaintId/cancel?user_id=$userId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("❌ Cancel error: $e");
      return false;
    }
  }

  /// Finish a complaint (close by user)
  Future<bool> finishComplaint(int complaintId, int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/complaints/$complaintId/finish?user_id=$userId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("❌ Finish error: $e");
      return false;
    }
  }

  // ============================================================================
  // PHASE 4: IMAGE UPLOAD
  // ============================================================================

  /// Upload image for a complaint (Cross-Platform)
  Future<bool> uploadComplaintImage(int complaintId, XFile imageFile) async {
    try {
      print("📤 Uploading image for complaint: $complaintId");
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/complaints/$complaintId/upload-image'),
      );

      // ✅ ADD AUTHORIZATION HEADER
      String? token = await AuthService().getFirebaseToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: imageFile.name,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            imageFile.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final response = await request.send();
      print("✅ Upload image response: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print('Upload image error: $e');
      return false;
    }
  }

  /// Get complaint image URL
  Future<String?> getComplaintImage(int complaintId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/complaints/$complaintId/image'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['image_url'];
      }
      return null;
    } catch (e) {
      print('Get complaint image error: $e');
      return null;
    }
  }

  // ============================================================================
  // PHASE 4: AUDIO UPLOAD
  // ============================================================================

  /// Upload audio for a complaint (Cross-Platform)
  Future<bool> uploadComplaintAudio(int complaintId, XFile audioFile) async {
    try {
      print("📤 Uploading audio for complaint: $complaintId");

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/complaints/$complaintId/upload-audio'),
      );

      // ✅ ADD AUTHORIZATION HEADER
      String? token = await AuthService().getFirebaseToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (kIsWeb) {
        final bytes = await audioFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: audioFile.name,
            contentType: MediaType('audio', 'm4a'),
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            audioFile.path,
            contentType: MediaType('audio', 'm4a'),
          ),
        );
      }

      final response = await request.send();
      print("✅ Upload audio response: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print('Upload audio error: $e');
      return false;
    }
  }

  /// Get complaint audio URLaudio URL
  Future<String?> getComplaintAudio(int complaintId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/complaints/$complaintId/audio'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['audio_url'];
      }
      return null;
    } catch (e) {
      print('Get complaint audio error: $e');
      return null;
    }
  }

  // ============================================================================
  // NOTIFICATIONS
  // ============================================================================

  /// Get notifications
  Future<List<dynamic>?> getNotifications(int userId, {bool unreadOnly = false}) async {
    try {
      final endpoint = unreadOnly
          ? '$baseUrl/notifications/$userId/unread'
          : '$baseUrl/notifications/$userId';

      final response = await http.get(Uri.parse(endpoint));

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

  // ============================================================================
  // PHASE 4: REAL-TIME CHAT
  // ============================================================================

  /// Get chat history for a complaint (Simplified)
  Future<List<dynamic>?> getChatHistory(int complaintId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/$complaintId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get chat history error: $e');
      return null;
    }
  }

  /// Get chat messages for a complaint
  Future<List<dynamic>?> getChatMessages(int complaintId, [String? userType]) async {
    try {
      final url = userType != null
          ? '$baseUrl/chat/$complaintId/messages?user_type=$userType'
          : '$baseUrl/chat/$complaintId/messages';
          
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get chat messages error: $e');
      return null;
    }
  }

  /// Send chat message
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

  /// Get unread chat message count
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

  // ============================================================================
  // PHASE 4: RATING SYSTEM
  // ============================================================================

  /// Submit rating for a resolved complaint
  Future<bool> rateComplaint(
    int complaintId,
    int userId,
    int rating,
    String? feedback,
  ) async {
    try {
      final body = {
        'user_id': userId,
        'rating': rating,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/complaints/$complaintId/rate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Rate complaint error: $e');
      return false;
    }
  }

  /// Get complaint rating
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

  /// Get user statistics
  Future<Map<String, dynamic>?> getUserStats(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/stats/$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get user stats error: $e');
      return null;
    }
  }
}