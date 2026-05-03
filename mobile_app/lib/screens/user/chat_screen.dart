import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

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

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late ApiService _apiService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isOfficerTyping = false;
  bool _isOfficerOnline = false;
  String? _officerLastSeen;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _typingTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool _isSending = false;
  bool _isTyping = false;

  // ─── Duplicate guard ─────────────────────────────────────────────────────────
  // Key: DB message id (int) OR temp key (String "tmp_<text>_<type>")
  final Set<dynamic> _seenIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiService = Provider.of<ApiService>(context, listen: false);
    _loadChatHistory();
    _connectWebSocket();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sendPresence(true);
    } else if (state == AppLifecycleState.paused) {
      _sendPresence(false);
    }
  }

  // ─── Load history ─────────────────────────────────────────────────────────────

  Future<void> _loadChatHistory() async {
    final response = await _apiService.getChatHistory(widget.complaintId);
    if (response != null && mounted) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        // Register all loaded IDs so WS broadcast duplicates are dropped
        for (final m in _messages) {
          if (m['id'] != null) _seenIds.add(m['id']);
        }
        _sortMessages();
      });
      _scrollToBottom();
      
      // Tell the other party we've read everything (UI bubble logic)
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _sendReadStatus();
      });

      // ✅ Mark notifications as read for this complaint
      final user = Provider.of<AuthService>(context, listen: false).userData;
      if (user != null && widget.userType == "user") {
        try {
          http.put(
            Uri.parse("${ApiService.baseUrl}/notifications/mark-chat-read/${user['user_id']}/${widget.complaintId}"),
          );
        } catch (e) {
          debugPrint("Error clearing notifications: $e");
        }
      }
    }
  }

  void _sortMessages() {
    _messages.sort((a, b) {
      final aTime = _parseTime(a['timestamp'] ?? a['created_at']);
      final bTime = _parseTime(b['timestamp'] ?? b['created_at']);
      return aTime.compareTo(bTime);
    });
  }

  DateTime _parseTime(dynamic ts) {
    if (ts == null) return DateTime.now();
    try {
      return DateTime.parse(ts as String);
    } catch (_) {
      return DateTime.now();
    }
  }

  // ─── WebSocket ────────────────────────────────────────────────────────────────

  void _connectWebSocket() {
    if (_isConnected || _channel != null) return;

    try {
      final base = ApiService.baseUrl
          .replaceAll('http://', '')
          .replaceAll('https://', '');
      final wsUrl = 'ws://$base/ws/chat/${widget.complaintId}';
      print('🔌 Connecting WS: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        _onWsData,
        onDone: _onWsClose,
        onError: (_) => _onWsClose(),
      );

      // Announce presence after a short delay (channel may not be ready instantly)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _sendPresence(true);
      });
    } catch (e) {
      print('❌ WS connect error: $e');
      _isConnected = false;
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _onWsClose() {
    _isConnected = false;
    _channel = null;
    _subscription = null;
    if (mounted) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _connectWebSocket();
    });
  }

  void _onWsData(dynamic raw) {
    if (!mounted) return;
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(raw as String));
    } catch (_) {
      return;
    }

    final type = data['type'] as String?;
    print('📩 WS ← ${type ?? "message"}');

    // ── Presence ──────────────────────────────────────────────────────────────
    if (type == 'presence') {
      final senderType = data['sender_type'];
      if (senderType != widget.userType) {
        setState(() {
          _isOfficerOnline = data['online'] == true;
          _officerLastSeen = data['last_seen'] as String?;
        });
      }
      return;
    }

    // ── Typing indicator ──────────────────────────────────────────────────────
    if (type == 'typing' || type == 'stop_typing') {
      if (data['sender_type'] != widget.userType) {
        setState(() {
          // If type is stop_typing, it's always false. 
          // Otherwise check is_typing field.
          if (type == 'stop_typing') {
            _isOfficerTyping = false;
          } else {
            _isOfficerTyping = data['is_typing'] == true;
          }
        });
      }
      return;
    }

    // ── Status update (delivered / read) ─────────────────────────────────────
    if (type == 'status_update') {
      final status     = data['status'] as String?;
      final messageId  = data['message_id'];
      final readerType = data['reader_type'] as String?;

      setState(() {
        if (messageId != null) {
          // Update a specific message
          for (final m in _messages) {
            if (m['id'] == messageId) {
              m['status'] = status;
              break;
            }
          }
        } else if (status == 'read' && readerType != null && readerType != widget.userType) {
          // Bulk: mark all our sent messages as read
          for (final m in _messages) {
            if (m['sender_type'] == widget.userType) {
              m['status'] = 'read';
            }
          }
        }
      });
      return;
    }

    // ── Regular message ───────────────────────────────────────────────────────
    final dbId = data['id'];

    // Drop if we've already seen this DB id
    if (dbId != null && _seenIds.contains(dbId)) {
      // Still update the status of any matching temp message
      _upgradeTempMessage(data);
      return;
    }

    // Also deduplicate by content when it's our own echo
    final isMine = data['sender_type'] == widget.userType;
    if (isMine) {
      // Try to find a temp message with the same text and promote it
      if (_upgradeTempMessage(data)) {
        if (dbId != null) _seenIds.add(dbId);
        return;
      }
    }

    // New message from the other party (or our own if no temp match)
    if (dbId != null) _seenIds.add(dbId);

    setState(() {
      _messages.add(Map<String, dynamic>.from(data));
      _sortMessages();
    });
    _scrollToBottom();

    // Send delivery ack for incoming messages
    if (!isMine && dbId != null) {
      _channel?.sink.add(jsonEncode({
        'type':        'status_update',
        'message_id':  dbId,
        'status':      'delivered',
        'sender_type': widget.userType,
      }));
      // Then read ack after a moment
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _sendReadStatus(messageId: dbId);
      });
    }
  }

  /// Finds a temp (null-id) message matching [data] and promotes it to the
  /// real DB entry.  Returns true if a match was found.
  bool _upgradeTempMessage(Map<String, dynamic> data) {
    final text = data['message'] as String?;
    if (text == null) return false;

    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      // Temp messages have integer IDs generated by DateTime.now().millisecondsSinceEpoch
      // They are always > 1_000_000_000_000 (13-digit epoch ms)
      final mId = m['id'];
      final isTemp = mId is int && mId > 1000000000000;

      if (isTemp && m['message'] == text && m['sender_type'] == widget.userType) {
        setState(() {
          _messages[i] = {
            ...m,
            ...data,  // overlay real id, timestamp, status etc.
          };
        });
        return true;
      }
    }
    return false;
  }

  // ─── Send ─────────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _isSending = true;
    _messageController.clear();
    _typingTimer?.cancel();
    _sendTypingState(false);

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.getUserId();
    if (userId == null) {
      _isSending = false;
      return;
    }

    // Use a large integer as temp ID (distinguishable from small DB IDs)
    final tempId = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _messages.add({
        'id':          tempId,
        'message':     message,
        'sender_type': widget.userType,
        'timestamp':   DateTime.now().toIso8601String(),
        'status':      'sent',
      });
    });
    _scrollToBottom();

    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'sender_id':   userId,
        'sender_type': widget.userType,
        'message':     message,
      }));
    } else {
      await _apiService.sendChatMessage(widget.complaintId, {
        'sender_id':   userId,
        'sender_type': widget.userType,
        'message':     message,
      });
    }

    await Future.delayed(const Duration(milliseconds: 200));
    _isSending = false;
  }

  // ─── Presence / typing / read ─────────────────────────────────────────────────

  void _sendPresence(bool online) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type':        'presence',
        'sender_type': widget.userType,
        'status':      online ? 'online' : 'offline',
      }));
    }
  }

  void _sendReadStatus({int? messageId}) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type':        'status_update',
        'status':      'read',
        'sender_type': widget.userType,
        if (messageId != null) 'message_id': messageId,
      }));
    }
  }

  void _onTypingChanged(String text) {
    if (!_isTyping) {
      _isTyping = true;
      _sendTypingState(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      _sendTypingState(false);
    });
  }

  void _sendTypingState(bool isTyping) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type':        isTyping ? 'typing' : 'stop_typing',
        'sender_type': widget.userType,
        'is_typing':   isTyping,
      }));
    }
  }

  // ─── Scroll ───────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat - ${widget.trackingId}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            _buildSubtitle(),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    if (_isOfficerTyping) {
      return const Text(
        'Officer is typing…',
        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.green),
      );
    }
    if (_isOfficerOnline) {
      return const Row(
        children: [
          Icon(Icons.circle, size: 8, color: Colors.green),
          SizedBox(width: 4),
          Text('Online', style: TextStyle(fontSize: 12, color: Colors.green)),
        ],
      );
    }
    if (_officerLastSeen != null) {
      return Text(
        'Last seen ${_formatLastSeen(_officerLastSeen!)}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No messages yet',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message['sender_type'] == widget.userType;
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
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
              decoration: const InputDecoration(
                hintText: 'Type a message…',
                border: InputBorder.none,
              ),
              onChanged: _onTypingChanged,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF667eea)),
            onPressed: _sendMessage,
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)])
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
            Text(
              message['message'] ?? '',
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
                  _formatTime(message['timestamp'] ?? message['created_at']),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(message['status'] as String?),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tick icons ───────────────────────────────────────────────────────────────

  Widget _buildStatusIcon(String? status) {
    switch (status) {
      case 'read':
        return const Icon(Icons.done_all, color: Colors.blue, size: 14);
      case 'delivered':
        return const Icon(Icons.done_all, color: Colors.white70, size: 14);
      default: // 'sent' or null
        return const Icon(Icons.check, color: Colors.white70, size: 14);
    }
  }

  // ─── Time helpers ─────────────────────────────────────────────────────────────

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(timestamp as String).toLocal());
    } catch (_) {
      return '';
    }
  }

  String _formatLastSeen(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return DateFormat('hh:mm a').format(dt);
      return DateFormat('dd MMM').format(dt);
    } catch (_) {
      return '';
    }
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sendPresence(false);
    _reconnectTimer?.cancel();
    _typingTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}