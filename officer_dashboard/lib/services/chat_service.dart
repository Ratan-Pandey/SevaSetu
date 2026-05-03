/// chat_service.dart
///
/// IMPORTANT FIX: The original file used `socket_io_client` (Socket.IO protocol)
/// which is INCOMPATIBLE with the FastAPI backend that uses raw WebSockets.
/// This rewrite uses `web_socket_channel` (same package already used in chat_screen.dart).
///
/// This file is OPTIONAL — ChatScreen connects directly to WebSocket without
/// needing this service class.  Use this if you want a shared singleton or if
/// the officer app reuses the same service layer.

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef MessageCallback = void Function(Map<String, dynamic> data);

class ChatService {
  final String serverUrl; // e.g. "http://127.0.0.1:8000"

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  Timer? _reconnectTimer;

  /// Called for every incoming WS frame (after JSON decode)
  MessageCallback? onMessage;

  ChatService({required this.serverUrl});

  // ─── Connect ────────────────────────────────────────────────────────────────

  void connect({
    required int complaintId,
    required int userId,
    required String userType,
  }) {
    if (_isConnected) return;

    final base = serverUrl
        .replaceAll('http://', '')
        .replaceAll('https://', '');
    final wsUrl = 'ws://$base/ws/chat/$complaintId';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      print('🔌 ChatService connected: $wsUrl');

      _subscription = _channel!.stream.listen(
        (raw) {
          try {
            final data = Map<String, dynamic>.from(jsonDecode(raw as String));
            onMessage?.call(data);
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
          _channel = null;
          _subscription = null;
          _scheduleReconnect(complaintId: complaintId, userId: userId, userType: userType);
        },
        onError: (_) {
          _isConnected = false;
          _channel = null;
          _subscription = null;
          _scheduleReconnect(complaintId: complaintId, userId: userId, userType: userType);
        },
      );

      // Announce presence
      _send({'type': 'presence', 'sender_type': userType, 'status': 'online'});
    } catch (e) {
      print('❌ ChatService connect error: $e');
      _isConnected = false;
      _channel = null;
    }
  }

  void _scheduleReconnect({
    required int complaintId,
    required int userId,
    required String userType,
  }) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect(complaintId: complaintId, userId: userId, userType: userType);
    });
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  void sendMessage({
    required int complaintId,
    required int senderId,
    required String senderType,
    required String message,
  }) {
    _send({
      'sender_id':   senderId,
      'sender_type': senderType,
      'message':     message,
    });
  }

  void sendTyping({required String userType, required bool isTyping}) {
    _send({
      'type':        isTyping ? 'typing' : 'stop_typing',
      'sender_type': userType,
      'is_typing':   isTyping,
    });
  }

  void sendReadAck({required String userType, int? messageId}) {
    _send({
      'type':        'status_update',
      'status':      'read',
      'sender_type': userType,
      if (messageId != null) 'message_id': messageId,
    });
  }

  void sendDeliveredAck({required String userType, required int messageId}) {
    _send({
      'type':        'status_update',
      'status':      'delivered',
      'message_id':  messageId,
      'sender_type': userType,
    });
  }

  void sendPresence({required String userType, required bool online}) {
    _send({
      'type':        'presence',
      'sender_type': userType,
      'status':      online ? 'online' : 'offline',
    });
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  void _send(Map<String, dynamic> payload) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  bool get isConnected => _isConnected;

  void disconnect({String userType = 'user'}) {
    sendPresence(userType: userType, online: false);
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    print('🔌 ChatService disconnected');
  }
}