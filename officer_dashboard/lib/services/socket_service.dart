import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class SocketService {
  IO.Socket? _socket;
  final String serverUrl;

  final _updateController = StreamController<DateTime>.broadcast();
  Stream<DateTime> get dashboardUpdates => _updateController.stream;

  SocketService({required this.serverUrl});

  void connect() {
    if (_socket != null && _socket!.connected) {
      print('📡 [SOCKET-OFFICER] Already connected.');
      return;
    }

    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }

    print('🔌 [SOCKET-OFFICER] Connecting to $serverUrl');

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io/')
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      print('✅ [SOCKET-OFFICER] Connected.');
    });

    // Listen for the broadcast event from the backend
    _socket!.on('dashboard_update', (data) {
      print('🔔 [SOCKET-OFFICER] Real-time dashboard update received: $data');
      _updateController.add(DateTime.now());
    });

    _socket!.onDisconnect((_) => print('❌ [SOCKET-OFFICER] Disconnected'));
    _socket!.onConnectError((err) => print('❌ [SOCKET-OFFICER] Connection error: $err'));
    _socket!.onError((err) => print('❌ [SOCKET-OFFICER] Error: $err'));

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    _updateController.close();
    disconnect();
  }
}
