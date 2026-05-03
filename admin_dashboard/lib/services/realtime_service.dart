import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class RealTimeService {
  IO.Socket? socket;
  final VoidCallback onUpdate;

  RealTimeService({required this.onUpdate});

  void connect() {
    socket = IO.io(ApiService.baseUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'], // Allow fallback to polling for stability
      'autoConnect': true,
      'path': '/socket.io/',
      'extraHeaders': {'Connection': 'upgrade', 'Upgrade': 'websocket'},
    });

    socket!.onConnect((_) {
      debugPrint('✅ Admin Dashboard connected to real-time server');
      // Join admin room if needed, or just listen to global updates
    });

    socket!.on('dashboard_update', (_) {
      debugPrint('🔔 Real-time dashboard update received');
      onUpdate();
    });

    socket!.onDisconnect((_) => debugPrint('❌ Disconnected from real-time server'));
    
    socket!.onError((data) => debugPrint('⚠️ Socket Error: $data'));
  }

  void reconnect() {
    debugPrint('🔄 Manually attempting to reconnect real-time server...');
    if (socket != null && socket!.disconnected) {
      socket!.connect();
    } else if (socket == null) {
      connect();
    }
  }

  void dispose() {
    socket?.disconnect();
    socket?.dispose();
  }
}
