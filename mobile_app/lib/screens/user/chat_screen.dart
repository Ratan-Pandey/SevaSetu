import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final int complaintId;
  final String trackingId;
  final String userType;
  
  const ChatScreen({
    super.key,
    required this.complaintId,
    required this.trackingId,
    this.userType = "user",
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService(serverUrl: ApiService.baseUrl);
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isOfficerTyping = false;
  WebSocket? _socket;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectWebSocket();
  }

  Future<void> _loadMessages() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final response = await apiService.getChatMessages(widget.complaintId);
    if (response != null && mounted) {
      setState(() => _messages = List<Map<String, dynamic>>.from(response));
      _scrollToBottom();
    }
  }

  void _connectWebSocket() async {
    try {
      // Use standard WebSocket on 10.0.2.2 (Android Emulator localhost) or actual IP
      final baseUrl = ApiService.baseUrl.replaceAll("http://", "").replaceAll("https://", "");
      final wsUrl = "ws://$baseUrl/ws/chat/${widget.complaintId}";
      
      print("Connecting to WebSocket: $wsUrl");
      _socket = await WebSocket.connect(wsUrl);

      _socket!.listen((data) {
        if (mounted) {
          try {
            final decodedMessage = jsonDecode(data);
            
            // Prevent self-duplicates (we already did optimistic update)
            // But we need to handle incoming messages from the other side
            setState(() {
              _messages.add({
                "message": decodedMessage['message'],
                "sender_type": decodedMessage['sender_type'],
                "created_at": decodedMessage['timestamp'] ?? DateTime.now().toIso8601String(),
              });
            });
            _scrollToBottom();
          } catch (e) {
            print("Error decoding WebSocket message: $e");
          }
        }
      }, onError: (err) {
        print("WebSocket Error: $err");
      }, onDone: () {
        print("WebSocket Connection Closed");
      });

    } catch (e) {
      print("WebSocket Connection Failed: $e");
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final userId = authService.getUserId();
    
    if (userId == null) return;
    
    final message = _messageController.text.trim();
    _messageController.clear();

    // Optimistic Update: Add message instantly to UI
    setState(() {
      _messages.add({
        'sender_id': userId,
        'sender_type': widget.userType,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();
    
    // Send via WebSocket instantly as structured JSON
    final wsMessage = jsonEncode({
      "message": message,
      "sender_type": widget.userType,
      "timestamp": DateTime.now().toIso8601String()
    });
    _socket?.add(wsMessage);
    
    // Save to database
    await apiService.sendChatMessage(widget.complaintId, {
      'sender_id': userId,
      'sender_type': widget.userType,
      'message': message,
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.getUserId();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat - ${widget.trackingId}'),
            if (_isOfficerTyping)
              const Text(
                'Officer is typing...',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No messages yet', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'Say hi 👋 to start conversation with the assigned officer',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['sender_type'] == 'user';
                      
                      return _buildMessageBubble(message, isMe);
                    },
                  ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                      onChanged: (text) {
                        // Send typing indicator
                        _chatService.sendTyping(
                          widget.complaintId,
                          widget.userType,
                          text.isNotEmpty,
                        );
                      },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                )
              : null,
          color: isMe ? null : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  "Officer",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            Text(
              message['message'],
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message['created_at']),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message['is_read'] == true ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isMe ? Colors.white70 : Colors.grey.shade600,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('HH:mm').format(dt);
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _socket?.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}