import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'complaint_detail_screen.dart';

class AllComplaintsScreen extends StatefulWidget {
  const AllComplaintsScreen({super.key});

  @override
  State<AllComplaintsScreen> createState() => _AllComplaintsScreenState();
}

class _AllComplaintsScreenState extends State<AllComplaintsScreen> {
  List<dynamic>? _complaints;
  bool _isLoading = true;
  String _selectedDepartment = 'All';
  String _selectedPriority = 'All';

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final complaints = await apiService.getAllComplaints(token: authService.token);
    if (mounted) {
      setState(() {
        _complaints = complaints;
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredComplaints {
    if (_complaints == null) return [];
    var filtered = List<dynamic>.from(_complaints!);
    
    if (_selectedDepartment != 'All') {
      filtered = filtered.where((c) => c['selected_department'] == _selectedDepartment).toList();
    }
    
    if (_selectedPriority != 'All') {
      // Check both priority_label and ai_urgency for better match
      filtered = filtered.where((c) {
        final p = (c['priority_label'] ?? c['ai_urgency'] ?? 'Low').toString().toLowerCase();
        return p == _selectedPriority.toLowerCase();
      }).toList();
    }
    
    return filtered;
  }

  List<String> get _departments {
    if (_complaints == null || _complaints!.isEmpty) return ['All'];
    final depts = _complaints!
        .map((c) => (c['selected_department'] ?? 'Other').toString())
        .toSet()
        .toList();
    depts.sort();
    return ['All', ...depts];
  }

  @override
  Widget build(BuildContext context) {
    // Ensure selected values are still valid after data loads
    final depts = _departments;
    if (!depts.contains(_selectedDepartment)) {
      _selectedDepartment = 'All';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Complaints Archive', style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComplaints,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      // Department Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Department", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedDepartment,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                  style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                                  items: _departments.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    setState(() => _selectedDepartment = newValue!);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Priority Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Priority", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedPriority,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                  style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                                  items: <String>['All', 'Critical', 'High', 'Medium', 'Low'].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) {
                                    setState(() => _selectedPriority = newValue!);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Results Count
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        '${_filteredComplaints.length} complaints found',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Complaints List
                Expanded(
                  child: _filteredComplaints.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'No complaints found',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredComplaints.length,
                          itemBuilder: (context, index) {
                            final complaint = _filteredComplaints[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ComplaintDetailScreen(
                                      complaintId: complaint['id'],
                                    ),
                                  ),
                                );
                              },
                              child: _buildComplaintCard(complaint),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> complaint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  complaint['tracking_id'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
              const Spacer(),
              _buildStatusChip(complaint['status'] ?? 'submitted'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            complaint['text'] ?? 'No description',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.category, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                complaint['ai_category'] ?? 'N/A',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.flag,
                size: 14,
                color: _getUrgencyColor(complaint['ai_urgency']),
              ),
              const SizedBox(width: 4),
              Text(
                complaint['ai_urgency'] ?? 'Low',
                style: TextStyle(
                  fontSize: 12,
                  color: _getUrgencyColor(complaint['ai_urgency']),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                complaint['ai_department'] ?? 'N/A',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(status),
        ),
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