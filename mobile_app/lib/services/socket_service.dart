import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class SocketService {
  IO.Socket? _socket;
  final String serverUrl;

  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notifications =>
      _notificationController.stream;

  SocketService({required this.serverUrl});

  void connect(int userId) {
    // ── Guard: already connected ─────────────────────────────────────────────
    if (_socket != null && _socket!.connected) {
      print('📡 [SOCKET] Already connected. Re-joining room for User: $userId');
      _socket!.emit('join_notifications', {'user_id': userId});
      return;
    }

    // ── Dispose broken socket ────────────────────────────────────────────────
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }

    print('🔌 [SOCKET] Connecting to $serverUrl for User: $userId');

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          // ✅ FIX 1: 'websocket' FIRST, then fall back to 'polling'.
          // Putting 'polling' first causes an immediate XHR 404 loop because
          // the Engine.IO polling handshake hits the FastAPI router before
          // the Socket.IO ASGIApp can intercept it.
          .setTransports(['websocket', 'polling'])
          // ✅ FIX 2: Explicit path must match socketio_path in main.py ASGIApp.
          // Default is '/socket.io/' — set it explicitly to avoid any mismatch.
          .setPath('/socket.io/')
          .disableAutoConnect()
          .enableReconnection()
          // ✅ FIX 3: Slow down reconnection attempts to stop the console spam.
          // 5 attempts with 5-second delay and 10-second max delay.
          .setReconnectionAttempts(5)
          .setReconnectionDelay(5000)
          .setReconnectionDelayMax(10000)
          .build(),
    );

    _socket!.onConnect((_) {
      print(
          '✅ [SOCKET] Connected. Joining notification room for User: $userId');
      _socket!.emit('join_notifications', {'user_id': userId});
    });

    _socket!.on('notification', (data) {
      print('🔔 [SOCKET] Real-time notification received: $data');
      _notificationController.add(Map<String, dynamic>.from(data));
    });

    _socket!.onDisconnect((_) => print('❌ [SOCKET] Disconnected'));
    _socket!.onConnectError(
        (err) => print('❌ [SOCKET] Connection error (will retry): $err'));
    _socket!.onError((err) => print('❌ [SOCKET] Error: $err'));
    _socket!.onReconnectFailed(
        (_) => print('⚠️ [SOCKET] All reconnection attempts exhausted.'));

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    _notificationController.close();
    disconnect();
  }
}