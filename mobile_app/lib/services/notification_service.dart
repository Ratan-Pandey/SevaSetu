import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize(int userId, ApiService apiService) async {
    // Request permission/Users/Ratan Pandey/.gemini/antigravity/brain/5e09cb88-c080-4de3-a51c-3c4ea07e114b/task.md
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    final token = await _fcm.getToken();
    if (token != null) {
      // Save to backend
      await apiService.saveFCMToken(userId, token);
      print('FCM Token: $token');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground notification: ${message.notification?.title}');
    });

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Background notification opened: ${message.notification?.title}');
    });
  }
}
