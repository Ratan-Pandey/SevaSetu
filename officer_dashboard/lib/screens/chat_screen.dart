// officer/screens/chat/chat_screen.dart
//
// Officer-side chat screen for Seva Setu.
// userType is hardcoded to "officer" — never needs to be passed as a prop.
// The "other party" from the officer's perspective is always the user/citizen.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final int complaintId;
  final String trackingId;

  // Officer screen always sends as "officer" — not configurable.
  // The "userType" parameter is intentionally removed to avoid accidental misuse.
  const ChatScreen({
    super.key,
    required this.complaintId,
    required this.trackingId,
  });

  // Convenience: the sender type this screen always uses
  static const String senderType = 'officer';
  // Label for the other party (shown in typing / presence subtitle)
  static const String otherPartyLabel = 'User';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late ApiService _apiService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];

  // State for the OTHER party (the citizen/user)
  bool _isOtherTyping = false;
  bool _isOtherOnline = false;
  String? _otherLastSeen;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _typingTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool _isSending = false;
  bool _isTyping = false;

  // Deduplication: stores DB ids (int) of messages we've already shown
  final Set<dynamic> _seenIds = {};

  // Officer's own ID — fetched from AuthService on init
  int? _officerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiService = Provider.of<ApiService>(context, listen: false);

    // Resolve officer ID synchronously if possible, async otherwise
    final authService = Provider.of<AuthService>(context, listen: false);
    _officerId = authService.getOfficerId();

    _loadChatHistory();
    _connectWebSocket();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sendPresence(true);
      // Re-sync in case messages arrived while backgrounded
      _loadChatHistory();
    } else if (state == AppLifecycleState.paused) {
      _sendPresence(false);
    }
  }

  // ─── Load history ─────────────────────────────────────────────────────────

  Future<void> _loadChatHistory() async {
    final response = await _apiService.getChatHistory(widget.complaintId);
    if (response != null && mounted) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        for (final m in _messages) {
          if (m['id'] != null) _seenIds.add(m['id']);
        }
        _sortMessages();
      });
      _scrollToBottom();
      // Mark everything as read
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _sendReadStatus();
      });
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

  // ─── WebSocket ────────────────────────────────────────────────────────────

  void _connectWebSocket() {
    if (_isConnected || _channel != null) return;

    try {
      final base = ApiService.baseUrl
          .replaceAll('http://', '')
          .replaceAll('https://', '');
      final wsUrl = 'ws://$base/ws/chat/${widget.complaintId}';
      print('🔌 [OFFICER] Connecting WS: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        _onWsData,
        onDone: _onWsClose,
        onError: (_) => _onWsClose(),
      );

      // Announce presence after socket is ready
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _sendPresence(true);
      });
    } catch (e) {
      print('❌ [OFFICER] WS connect error: $e');
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
    print('📩 [OFFICER] WS ← ${type ?? "message"}');

    // ── Presence ────────────────────────────────────────────────────────────
    if (type == 'presence') {
      // Only update if it's the OTHER party (user/citizen)
      if (data['sender_type'] != ChatScreen.senderType) {
        setState(() {
          _isOtherOnline = data['online'] == true;
          _otherLastSeen = data['last_seen'] as String?;
        });
      }
      return;
    }

    // ── Typing ───────────────────────────────────────────────────────────────
    if (type == 'typing' || type == 'stop_typing') {
      if (data['sender_type'] != ChatScreen.senderType) {
        setState(() {
          if (type == 'stop_typing') {
            _isOtherTyping = false;
          } else {
            _isOtherTyping = data['is_typing'] == true;
          }
        });
      }
      return;
    }

    // ── Status update (delivered / read ticks) ───────────────────────────────
    if (type == 'status_update') {
      final status     = data['status'] as String?;
      final messageId  = data['message_id'];
      final readerType = data['reader_type'] as String?;

      setState(() {
        if (messageId != null) {
          for (final m in _messages) {
            if (m['id'] == messageId) {
              m['status'] = status;
              break;
            }
          }
        } else if (status == 'read' &&
            readerType != null &&
            readerType != ChatScreen.senderType) {
          // Bulk-mark all officer messages as read
          for (final m in _messages) {
            if (m['sender_type'] == ChatScreen.senderType) {
              m['status'] = 'read';
            }
          }
        }
      });
      return;
    }

    // ── Regular message ──────────────────────────────────────────────────────
    final dbId  = data['id'];
    final isMine = data['sender_type'] == ChatScreen.senderType;

    // Drop already-seen DB ids (but still try to upgrade a temp bubble)
    if (dbId != null && _seenIds.contains(dbId)) {
      if (isMine) _upgradeTempMessage(data);
      return;
    }

    // If it's our own echo, try to replace the optimistic temp bubble
    if (isMine && _upgradeTempMessage(data)) {
      if (dbId != null) _seenIds.add(dbId);
      return;
    }

    if (dbId != null) _seenIds.add(dbId);

    setState(() {
      _messages.add(Map<String, dynamic>.from(data));
      _sortMessages();
    });
    _scrollToBottom();

    // Ack delivery + read for incoming messages
    if (!isMine && dbId != null) {
      _channel?.sink.add(jsonEncode({
        'type':        'status_update',
        'message_id':  dbId,
        'status':      'delivered',
        'sender_type': ChatScreen.senderType,
      }));
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _sendReadStatus(messageId: dbId);
      });
    }
  }

  /// Replace a temp (optimistic) bubble with the real DB entry.
  /// Returns true if a match was found and replaced.
  bool _upgradeTempMessage(Map<String, dynamic> data) {
    final text = data['message'] as String?;
    if (text == null) return false;

    for (int i = 0; i < _messages.length; i++) {
      final m   = _messages[i];
      final mId = m['id'];
      // Temp IDs are 13-digit epoch milliseconds (> 1_000_000_000_000)
      final isTemp = mId is int && mId > 1000000000000;

      if (isTemp &&
          m['message'] == text &&
          m['sender_type'] == ChatScreen.senderType) {
        setState(() {
          _messages[i] = {...m, ...data};
        });
        return true;
      }
    }
    return false;
  }

  // ─── Send ─────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _isSending = true;
    _messageController.clear();
    _typingTimer?.cancel();
    _sendTypingState(false);

    final senderId = _officerId;
    if (senderId == null) {
      print('❌ [OFFICER] No officer ID — cannot send message');
      _isSending = false;
      return;
    }

    // Optimistic bubble with temp ID
    final tempId = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _messages.add({
        'id':          tempId,
        'message':     message,
        'sender_type': ChatScreen.senderType,
        'timestamp':   DateTime.now().toIso8601String(),
        'status':      'sent',
      });
    });
    _scrollToBottom();

    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'sender_id':   senderId,
        'sender_type': ChatScreen.senderType,
        'message':     message,
      }));
    } else {
      // HTTP fallback
      await _apiService.sendChatMessage(widget.complaintId, {
        'sender_id':   senderId,
        'sender_type': ChatScreen.senderType,
        'message':     message,
      });
    }

    await Future.delayed(const Duration(milliseconds: 200));
    _isSending = false;
  }

  // ─── Presence / typing / read ─────────────────────────────────────────────

  void _sendPresence(bool online) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type':        'presence',
        'sender_type': ChatScreen.senderType,
        'status':      online ? 'online' : 'offline',
      }));
    }
  }

  void _sendReadStatus({int? messageId}) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type':        'status_update',
        'status':      'read',
        'sender_type': ChatScreen.senderType,
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
        'sender_type': ChatScreen.senderType,
        'is_typing':   isTyping,
      }));
    }
  }

  // ─── Scroll ───────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // Citizen avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF667eea).withOpacity(0.15),
              child: const Icon(Icons.person, size: 20, color: Color(0xFF667eea)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Complaint ${widget.trackingId}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  _buildSubtitle(),
                ],
              ),
            ),
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

  /// Subtitle under the complaint ID: shows typing / online / last seen
  Widget _buildSubtitle() {
    if (_isOtherTyping) {
      return Row(
        children: const [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.green),
          ),
          SizedBox(width: 4),
          Text(
            '${ChatScreen.otherPartyLabel} is typing…',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.green),
          ),
        ],
      );
    }
    if (_isOtherOnline) {
      return Row(
        children: const [
          Icon(Icons.circle, size: 8, color: Colors.green),
          SizedBox(width: 4),
          Text(
            '${ChatScreen.otherPartyLabel} is online',
            style: TextStyle(fontSize: 11, color: Colors.green),
          ),
        ],
      );
    }
    if (_otherLastSeen != null) {
      return Text(
        'Last seen ${_formatLastSeen(_otherLastSeen!)}',
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
            Text(
              'No messages yet.\nStart the conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message['sender_type'] == ChatScreen.senderType;

        // Show date separator if day changes
        final showDateSep = index == 0 ||
            _dayChanged(_messages[index - 1], message);

        return Column(
          children: [
            if (showDateSep) _buildDateSeparator(message),
            _buildMessageBubble(message, isMe),
          ],
        );
      },
    );
  }

  bool _dayChanged(Map<String, dynamic> prev, Map<String, dynamic> curr) {
    final prevDt = _parseTime(prev['timestamp'] ?? prev['created_at']);
    final currDt = _parseTime(curr['timestamp'] ?? curr['created_at']);
    return prevDt.day != currDt.day ||
        prevDt.month != currDt.month ||
        prevDt.year != currDt.year;
  }

  Widget _buildDateSeparator(Map<String, dynamic> message) {
    final dt = _parseTime(message['timestamp'] ?? message['created_at']).toLocal();
    final now = DateTime.now();
    String label;
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      label = 'Today';
    } else if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('dd MMM yyyy').format(dt);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'Reply to citizen…',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: _onTypingChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 6,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                )
              : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender label for received messages
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'Citizen',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            Text(
              message['message'] ?? '',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message['timestamp'] ?? message['created_at']),
                  style: TextStyle(
                    color: isMe ? Colors.white60 : Colors.grey.shade500,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  _buildStatusIcon(message['status'] as String?),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tick icons ───────────────────────────────────────────────────────────

  Widget _buildStatusIcon(String? status) {
    switch (status) {
      case 'read':
        // Double blue ticks — citizen has read it
        return const Icon(Icons.done_all, color: Colors.lightBlueAccent, size: 13);
      case 'delivered':
        // Double white ticks — delivered but not yet read
        return const Icon(Icons.done_all, color: Colors.white60, size: 13);
      default:
        // Single white tick — sent (or pending)
        return const Icon(Icons.check, color: Colors.white60, size: 13);
    }
  }

  // ─── Time / date helpers ──────────────────────────────────────────────────

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      return DateFormat('hh:mm a')
          .format(DateTime.parse(timestamp as String).toLocal());
    } catch (_) {
      return '';
    }
  }

  String _formatLastSeen(String isoString) {
    try {
      final dt   = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return DateFormat('hh:mm a').format(dt);
      return DateFormat('dd MMM').format(dt);
    } catch (_) {
      return '';
    }
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sendPresence(false);      // tell citizen we went offline
    _sendTypingState(false);   // stop any lingering typing indicator
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