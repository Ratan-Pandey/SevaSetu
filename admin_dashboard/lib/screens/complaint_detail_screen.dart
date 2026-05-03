import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final int complaintId;

  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    final detail = await apiService.getComplaintDetail(
      widget.complaintId, 
      token: authService.token!
    );

    if (mounted) {
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(_detail != null ? 'Complaint #${_detail!['tracking_id']}' : 'Complaint Detail'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(child: Text("Complaint not found"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildDescriptionSection(),
                      const SizedBox(height: 20),
                      _buildUserInfoSection(),
                      const SizedBox(height: 20),
                      _buildLocationSection(),
                      const SizedBox(height: 20),
                      _buildTimelineSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final status = _detail!['status'] ?? 'submitted';
    final priority = _detail!['ai_urgency'] ?? 'Low';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildBadge(status.toUpperCase(), _getStatusColor(status)),
              const SizedBox(width: 10),
              _buildBadge(priority.toUpperCase(), _getUrgencyColor(priority)),
              const Spacer(),
              Text(
                DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(_detail!['created_at'])),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.business, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                _detail!['selected_department'] ?? 'General',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return _sectionWrapper(
      title: "Description",
      icon: Icons.description_outlined,
      child: Text(
        _detail!['text'] ?? 'No description provided.',
        style: const TextStyle(fontSize: 15, height: 1.5),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return _sectionWrapper(
      title: "Citizen Details",
      icon: Icons.person_outline,
      child: Column(
        children: [
          _infoRow(Icons.account_circle, "Name", _detail!['user_name'] ?? "Citizen"),
          const Divider(),
          _infoRow(Icons.phone, "Phone", _detail!['user_phone'] ?? "N/A"),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _sectionWrapper(
      title: "Incident Location",
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.map, "User Pin", _detail!['incident_location'] ?? "N/A"),
          const Divider(),
          _infoRow(Icons.location_city, "Address", _detail!['location_address'] ?? "N/A"),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.gps_fixed, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  "GPS: ${_detail!['latitude']}, ${_detail!['longitude']}",
                  style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final updates = _detail!['updates'] as List;
    
    return _sectionWrapper(
      title: "Status Timeline",
      icon: Icons.timeline,
      child: updates.isEmpty 
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text("No updates yet", style: TextStyle(color: Colors.grey))),
          )
        : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: updates.length,
            itemBuilder: (context, i) {
              final up = updates[i];
              final isLast = i == updates.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(color: i == 0 ? Colors.green : Colors.grey.shade400, shape: BoxShape.circle),
                      ),
                      if (!isLast) Container(width: 2, height: 60, color: Colors.grey.shade300),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              up['officer_name'] ?? 'Officer',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('MMM dd, HH:mm').format(DateTime.parse(up['created_at'])),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (up['status_changed_to'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              "Status: ${up['status_changed_from']} → ${up['status_changed_to']}",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue),
                            ),
                          ),
                        Text(
                          up['update_text'],
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _sectionWrapper({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF059669)),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted': return Colors.blue;
      case 'under_review': return Colors.orange;
      case 'in_progress': return Colors.purple;
      case 'resolved': return Colors.green;
      default: return Colors.grey;
    }
  }

  Color _getUrgencyColor(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'critical': return Colors.red.shade900;
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }
}
