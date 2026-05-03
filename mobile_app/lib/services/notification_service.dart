import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'api_service.dart';
import 'socket_service.dart';
import '../screens/user/notifications_screen.dart';

class NotificationService extends ChangeNotifier {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  int _unreadCount = 0;
  int? _currentUserId;
  int get unreadCount => _unreadCount;
  bool _isInitialized = false;
  StreamSubscription? _socketSubscription;

  Future<void> initialize(int userId, ApiService apiService, SocketService socketService) async {
    if (_isInitialized && _currentUserId == userId) {
      print('ℹ️ NotificationService already initialized for User: $userId');
      return;
    }
    
    // 🔥 CLEANUP OLD SUBSCRIPTION (Crucial for Logout/Login reliability)
    await _socketSubscription?.cancel();
    _isInitialized = true;
    _currentUserId = userId;
    print('🔔 Initializing NotificationService for User: $userId');
    
    // 1. Setup Socket Listener FIRST (more reliable)
    _socketSubscription = socketService.notifications.listen((data) async {
      print('📬 [NOTIFICATION_SERVICE] Socket event received: ${data['title']}');
      print('📥 Data: $data');
      
      // Update unread count
      try {
        _unreadCount = await apiService.getUnreadCount(userId);
        notifyListeners();
      } catch (e) {
        print('Error updating unread count: $e');
      }

      // Show Global SnackBar
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['title'] ?? 'New Notification', 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(data['message'] ?? '', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.close, color: Colors.white70, size: 20),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF667eea),
          duration: const Duration(seconds: 6), // Increased duration to allow time to click
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(userId: _currentUserId ?? 0),
                ),
              );
            },
          ),
        ),
      );
    });

    // 2. Initial count fetch
    try {
      _unreadCount = await apiService.getUnreadCount(userId);
      notifyListeners();
    } catch (e) {
      print('⚠️ Error fetching initial unread count: $e');
    }


    // 3. Setup FCM (May fail on some platforms/browsers)
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('📱 FCM permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // web vapid key is required for some setups, but we'll try standard first
        final token = await _fcm.getToken();
        if (token != null) {
          await apiService.saveFCMToken(userId, token);
          print('✅ FCM Token saved');
        }
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        print('📨 FCM foreground message received');
        _unreadCount = await apiService.getUnreadCount(userId);
        notifyListeners();
      });
    } catch (e) {
      print('⚠️ FCM Initialization skipped/failed: $e');
    }
  }

  void refreshCount(int userId, ApiService apiService) async {
    _unreadCount = await apiService.getUnreadCount(userId);
    notifyListeners();
  }
  void markAsRead() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }
}
