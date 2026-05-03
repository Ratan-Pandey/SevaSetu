import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final profile = await apiService.getUserProfile(widget.userId);

    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  Future<void> _reportUser() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report User'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason for reporting'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Report'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final officerId = authService.getOfficerId();
      
      if (officerId != null) {
        final res = await apiService.reportUser(widget.userId, officerId, reasonController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res?['message'] ?? 'Reported successfully')),
          );
          _loadProfile(); // Reload to see if suspended
        }
      }
    }
  }

  Future<void> _liftSuspension() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lift Suspension'),
        content: const Text('Are you sure you want to lift the suspension for this user?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm == true) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final success = await apiService.liftSuspension(widget.userId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suspension lifted')));
          _loadProfile();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to lift suspension')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        elevation: 0,
        backgroundColor: const Color(0xFF1e3a8a),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Failed to load profile'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1e3a8a),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person, size: 50, color: Color(0xFF1e3a8a)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _profile!['name'] ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _profile!['email'] ?? 'N/A',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            if (_profile!['is_suspended'] == true) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'SUSPENDED',
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoSection('Basic Information', [
                              _buildInfoTile(Icons.phone, 'Phone', _profile!['phone_number'] ?? 'Not provided'),
                              _buildInfoTile(Icons.cake, 'DOB', _profile!['dob'] ?? 'Not provided'),
                            ]),
                            const SizedBox(height: 20),
                            _buildInfoSection('Address Details', [
                              _buildInfoTile(Icons.location_on, 'Address', _profile!['address'] ?? 'Not provided'),
                              _buildInfoTile(Icons.location_city, 'City/State', '${_profile!['city'] ?? 'N/A'}, ${_profile!['state'] ?? 'N/A'}'),
                              _buildInfoTile(Icons.pin_drop, 'Pincode', _profile!['pincode'] ?? 'N/A'),
                            ]),
                            const SizedBox(height: 20),
                            _buildInfoSection('Identity Verification', [
                              _buildInfoTile(Icons.badge, 'Aadhaar Number', _profile!['aadhaar_number'] ?? 'N/A'),
                              const SizedBox(height: 12),
                              const Text(
                                'Aadhaar Document',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _profile!['aadhaar_image_path'] != null
                                  ? InkWell(
                                      onTap: () {
                                        _showFullImage(context, '${ApiService.baseUrl}/${_profile!['aadhaar_image_path']}');
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          '${ApiService.baseUrl}/${_profile!['aadhaar_image_path']}',
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            height: 200,
                                            color: Colors.grey.shade200,
                                            child: const Center(child: Text('Aadhaar image not found')),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: const Text('No Aadhaar image uploaded'),
                                    ),
                            ]),
                            const SizedBox(height: 32),
                            
                            // Administrative Actions
                            Text(
                              'Administrative Actions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (_profile!['is_suspended'] == true)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _liftSuspension,
                                      icon: const Icon(Icons.gavel),
                                      label: const Text('Lift Suspension'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _reportUser,
                                      icon: const Icon(Icons.report_problem),
                                      label: const Text('Report User'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1e3a8a),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF3b82f6), size: 20),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
      ),
      dense: true,
    );
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
}
