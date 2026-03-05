import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'rating_dialog.dart';
import 'package:audioplayers/audioplayers.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final int complaintId;

  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  int _selectedRating = 0;
  final _feedbackController = TextEditingController();
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadDetail();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final data = await apiService.getComplaintDetail(widget.complaintId);
    
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF667eea).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _data == null
                  ? _buildErrorState()
                  : RefreshIndicator(
                      onRefresh: _loadDetail,
                      child: CustomScrollView(
                        slivers: [
                          // App Bar
                          SliverAppBar(
                            expandedHeight: 120,
                            pinned: true,
                            backgroundColor: const Color(0xFF667eea),
                            leading: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                            flexibleSpace: FlexibleSpaceBar(
                              title: const Text(
                                'Complaint Details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              background: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Content
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Tracking ID Card
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF667eea).withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Tracking ID',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _data!['complaint']['tracking_id'] ?? 'N/A',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Status Info Card
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        _buildInfoRow(
                                          'Status',
                                          _data!['complaint']['status'] ?? 'N/A',
                                          _getStatusColor(_data!['complaint']['status']),
                                        ),
                                        const Divider(height: 24),
                                        _buildInfoRow(
                                          'Category',
                                          _data!['complaint']['ai_category'] ?? 'N/A',
                                          const Color(0xFF667eea),
                                        ),
                                        const Divider(height: 24),
                                        _buildInfoRow(
                                          'Urgency',
                                          _data!['complaint']['ai_urgency'] ?? 'N/A',
                                          _getUrgencyColor(_data!['complaint']['ai_urgency']),
                                        ),
                                        const Divider(height: 24),
                                        _buildInfoRow(
                                          'Department',
                                          _data!['complaint']['ai_department'] ?? 'N/A',
                                          const Color(0xFF42A5F5),
                                        ),
                                        if (_data!['assigned_officer'] != null) ...[
                                          const Divider(height: 24),
                                          _buildInfoRow(
                                            'Assigned To',
                                            _data!['assigned_officer'],
                                            const Color(0xFF66BB6A),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Complaint Description
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: const [
                                            Icon(Icons.description, color: Color(0xFF667eea)),
                                            SizedBox(width: 12),
                                            Text(
                                              'Complaint Description',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _data!['complaint']['text'] ?? 'N/A',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.6,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Chat with Officer Button (if assigned)
                                  if (_data!['assigned_officer'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 20),
                                      child: Container(
                                        width: double.infinity,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF667eea).withOpacity(0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChatScreen(
                                                  complaintId: widget.complaintId,
                                                  trackingId: _data!['complaint']['tracking_id'],
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.chat_bubble, color: Colors.white),
                                          label: const Text(
                                            'Chat with Officer',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Audio Evidence
                                  if (_data!['complaint']['audio_path'] != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(Icons.mic, color: Colors.red),
                                              SizedBox(width: 12),
                                              Text(
                                                'Voice Recording',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                                    color: Colors.red,
                                                    size: 36,
                                                  ),
                                                  onPressed: () async {
                                                    if (_isPlaying) {
                                                      await _audioPlayer.pause();
                                                    } else {
                                                      final url = 'http://127.0.0.1:8000/${_data!['complaint']['audio_path']}';
                                                      await _audioPlayer.play(UrlSource(url));
                                                    }
                                                  },
                                                ),
                                                Expanded(
                                                  child: Slider(
                                                    activeColor: Colors.red,
                                                    inactiveColor: Colors.red.shade100,
                                                    min: 0,
                                                    max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1,
                                                    value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1),
                                                    onChanged: (value) async {
                                                      final position = Duration(seconds: value.toInt());
                                                      await _audioPlayer.seek(position);
                                                    },
                                                  ),
                                                ),
                                                Text(
                                                  '${_position.toString().split('.')[0].padLeft(8, '0').substring(3)} / '
                                                  '${_duration.toString().split('.')[0].padLeft(8, '0').substring(3)}',
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // Image Evidence
                                  if (_data!['complaint']['image_path'] != null &&
                                      _data!['complaint']['image_path'].toString().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.1),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(Icons.image, color: Color(0xFF667eea)),
                                              SizedBox(width: 12),
                                              Text(
                                                'Photo Evidence',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              'http://10.0.2.2:8000/${_data!['complaint']['image_path']}',
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  Container(
                                                    height: 150,
                                                    color: Colors.grey.shade200,
                                                    child: const Center(child: Text('Image not available')),
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_data!['complaint']['image_path'] != null &&
                                      _data!['complaint']['image_path'].toString().isNotEmpty)
                                    const SizedBox(height: 20),

                                  // Location Info
                                  if (_data!['complaint']['location_address'] != null &&
                                      _data!['complaint']['location_address'].toString().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.1),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(Icons.location_on, color: Color(0xFF667eea)),
                                              SizedBox(width: 12),
                                              Text(
                                                'Location',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              const Icon(Icons.place, color: Colors.red, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _data!['complaint']['location_address'],
                                                  style: const TextStyle(fontSize: 14, height: 1.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_data!['complaint']['latitude'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Text(
                                                'Coordinates: ${_data!['complaint']['latitude']}, ${_data!['complaint']['longitude']}',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  if (_data!['complaint']['location_address'] != null &&
                                      _data!['complaint']['location_address'].toString().isNotEmpty)
                                    const SizedBox(height: 20),

                                  // Updates Timeline
                                  if (_data!['updates'] != null && 
                                      (_data!['updates'] as List).isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.1),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(Icons.timeline, color: Color(0xFF667eea)),
                                              SizedBox(width: 12),
                                              Text(
                                                'Updates Timeline',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          ...(_data!['updates'] as List).map((update) {
                                            return _buildTimelineItem(
                                              update['update_text'] ?? '',
                                              update['created_at'],
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.schedule,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No updates yet',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'You will be notified when there are updates',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade500,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),

                                  // Rating Display & Button
                                  FutureBuilder<Map<String, dynamic>?>(
                                    future: Provider.of<ApiService>(context, listen: false).getComplaintRating(widget.complaintId),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        final ratingData = snapshot.data!;
                                        final status = _data?['complaint']['status'] ?? '';
                                        
                                        // Show rating if already rated
                                        if (ratingData['rated'] == true) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 20),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.amber.shade200),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Your Rating',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: List.generate(5, (index) {
                                                    return Icon(
                                                      index < ratingData['rating']
                                                          ? Icons.star
                                                          : Icons.star_border,
                                                      color: Colors.amber,
                                                      size: 24,
                                                    );
                                                  }),
                                                ),
                                                if (ratingData['feedback'] != null) ...[
                                                  const SizedBox(height: 8),
                                                  Text(ratingData['feedback']),
                                                ],
                                              ],
                                            ),
                                          );
                                        }
                                        
                                        // Show rate button if resolved/closed and not rated
                                        if (['resolved', 'closed'].contains(status.toLowerCase())) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 20),
                                            child: ElevatedButton.icon(
                                              onPressed: () => _showRatingDialog(),
                                              icon: const Icon(Icons.star),
                                              label: const Text('Rate this Service'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.amber,
                                                minimumSize: const Size(double.infinity, 50),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
      floatingActionButton: (_data != null && _data!['assigned_officer'] != null)
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      complaintId: widget.complaintId,
                      trackingId: _data!['complaint']['tracking_id'],
                    ),
                  ),
                );
              },
              backgroundColor: const Color(0xFF667eea),
              child: const Icon(Icons.chat, color: Colors.white),
            )
          : null,
    );
  }

  Future<void> _showRatingDialog() async {
    showDialog(
      context: context,
      builder: (_) => RatingDialog(
        onSubmit: (rating, feedback) async {
          final authService = Provider.of<AuthService>(context, listen: false);
          final apiService = Provider.of<ApiService>(context, listen: false);
          final userId = authService.getUserId();
          
          if (userId != null) {
            final success = await apiService.rateComplaint(
              widget.complaintId,
              userId,
              rating,
              feedback,
            );
            
            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your rating!')),
              );
              setState(() {}); // Refresh UI
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Failed to load details',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadDetail,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(String text, dynamic timestamp) {
    final timeStr = _formatTimestamp(timestamp);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF667eea),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 40,
                color: Colors.grey.shade300,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final dt = DateTime.parse(timestamp.toString());
      return DateFormat('MMM dd, yyyy - hh:mm a').format(dt);
    } catch (e) {
      return 'Recently';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'submitted':
        return const Color(0xFF42A5F5);
      case 'under_review':
        return const Color(0xFFFFA726);
      case 'in_progress':
        return const Color(0xFF764ba2);
      case 'resolved':
        return const Color(0xFF66BB6A);
      case 'closed':
        return Colors.grey;
      default:
        return const Color(0xFF42A5F5);
    }
  }

  Color _getUrgencyColor(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF5350);
      case 'medium':
        return const Color(0xFFFFA726);
      case 'low':
        return const Color(0xFF66BB6A);
      default:
        return Colors.grey;
    }
  }
}