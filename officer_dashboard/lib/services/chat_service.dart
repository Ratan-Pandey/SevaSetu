import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatService {
  IO.Socket? socket;
  
  void connect(int complaintId, int userId, String userType) {
    socket = IO.io('http://127.0.0.1:8000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    
    socket!.connect();
    
    socket!.onConnect((_) {
      print('Connected to chat server');
      // Join complaint chat room
      socket!.emit('join_chat', {
        'complaint_id': complaintId,
        'user_id': userId,
        'user_type': userType,
      });
    });
    
    socket!.onDisconnect((_) => print('Disconnected from chat'));
  }
  
  void sendMessage(int complaintId, int senderId, String senderType, String message) {
    socket?.emit('send_message', {
      'complaint_id': complaintId,
      'sender_id': senderId,
      'sender_type': senderType,
      'message': message,
    });
  }
  
  void sendTyping(int complaintId, String userType, bool isTyping) {
    socket?.emit('typing', {
      'complaint_id': complaintId,
      'user_type': userType,
      'is_typing': isTyping,
    });
  }
  
  void markAsRead(int complaintId) {
    socket?.emit('mark_read', {
      'complaint_id': complaintId,
    });
  }
  
  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
  }
}
