import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'user_profile_screen.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final int complaintId;

  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  final _commentController = TextEditingController();

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

  Future<void> _assignToMe() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final officerId = authService.getOfficerId();

    if (officerId == null) return;

    final success = await apiService.assignComplaint(widget.complaintId, officerId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint assigned successfully')),
      );
      _loadDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to assign complaint'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateStatus(String status) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final comment = _commentController.text.trim();
    final officerId = authService.getOfficerId();

    if (officerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Officer ID not found. Please re-login.')),
      );
      return;
    }

    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a comment')),
      );
      return;
    }

    final success = await apiService.updateComplaint(widget.complaintId, status, comment, officerId);

    if (!mounted) return;

    if (success) {
      _commentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated successfully')),
      );
      _loadDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update'), backgroundColor: Colors.red),
      );
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Complaint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Add Comment',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text('Select New Status:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus('under_review');
              },
              child: const Text('Mark Under Review'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus('in_progress');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Mark In Progress'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus('resolved');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Mark Resolved'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus('rejected');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject Complaint'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Failed to load details'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tracking ID
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Tracking ID',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _data!['complaint']['tracking_id'] ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildInfoRow('Status', _data!['complaint']['status'] ?? 'N/A'),
                              const Divider(),
                              _buildInfoRow('Category', _data!['complaint']['ai_category'] ?? 'N/A'),
                              const Divider(),
                              _buildInfoRow('Urgency', _data!['complaint']['ai_urgency'] ?? 'N/A'),
                              const Divider(),
                              _buildInfoRow('Department', _data!['complaint']['ai_department'] ?? 'N/A'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // User Info Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF1e3a8a),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            _data!['complaint']['user_name'] ?? 'Citizen', 
                            style: const TextStyle(fontWeight: FontWeight.bold)
                          ),
                          subtitle: const Text('Complaint filed by'),
                          trailing: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProfileScreen(
                                    userId: _data!['complaint']['user_id'],
                                  ),
                                ),
                              );
                            },
                            child: const Text('View Profile'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Description',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Text(_data!['complaint']['text'] ?? 'N/A'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Audio Evidence
                      if (_data!['complaint']['audio_path'] != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Voice Recording',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200),
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
                                            final url = '${ApiService.baseUrl}/${_data!['complaint']['audio_path']}';
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
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Image Evidence
                      if (_data!['complaint']['image_path'] != null &&
                          _data!['complaint']['image_path'].toString().isNotEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Photo Evidence',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    '${ApiService.baseUrl}/${_data!['complaint']['image_path']}',
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
                        ),
                      if (_data!['complaint']['image_path'] != null &&
                          _data!['complaint']['image_path'].toString().isNotEmpty)
                        const SizedBox(height: 16),

                      // Location Info
                      if (_data!['complaint']['location_address'] != null &&
                          _data!['complaint']['location_address'].toString().isNotEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Location',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _data!['complaint']['location_address'],
                                        overflow: TextOverflow.ellipsis,
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
                        ),
                      if (_data!['complaint']['location_address'] != null &&
                          _data!['complaint']['location_address'].toString().isNotEmpty)
                        const SizedBox(height: 16),


                      // Actions
                      if (_data!['complaint']['status'] != "closed_by_user" && 
                          _data!['complaint']['status'] != "cancelled" &&
                          _data!['complaint']['status'] != "resolved")
                        ElevatedButton(
                          onPressed: _showUpdateDialog,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Update Status'),
                        ),
                      
                      if (_data!['complaint']['status'] == "closed_by_user")
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            "This complaint has been closed by the user.",
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (_data!['complaint']['status'] == "cancelled")
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            "This complaint was cancelled by the user.",
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
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
              backgroundColor: const Color(0xFF1e3a8a),
              child: const Icon(Icons.chat, color: Colors.white),
            )
          : null,
    );
  }
  Widget _buildInfoRow(String label, String value) {
    String displayValue = value;
    if (label == 'Status') {
      displayValue = value.replaceAll('_', ' ').toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              displayValue,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: label == 'Status' ? _getStatusColor(value) : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.blue;
      case 'under_review':
        return Colors.orange;
      case 'in_progress':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      case 'closed':
      case 'closed_by_user':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}