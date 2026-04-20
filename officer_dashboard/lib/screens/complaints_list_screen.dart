import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'complaint_detail_screen.dart';

class ComplaintsListScreen extends StatefulWidget {
  const ComplaintsListScreen({super.key});

  @override
  State<ComplaintsListScreen> createState() => _ComplaintsListScreenState();
}

class _ComplaintsListScreenState extends State<ComplaintsListScreen> {
  List<dynamic>? _complaints;
  bool _isLoading = true;
  String _filterStatus = 'all';
  String _selectedSort = 'priority';
  String _searchText = '';
  String _selectedPriority = "";
  Map<String, dynamic> _stats = {};
  bool _isStatsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
    _loadStats();
  }
 
  Future<void> _loadStats() async {
    setState(() => _isStatsLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final officerId = authService.getOfficerId();
 
    if (officerId != null) {
      final statsData = await apiService.getOfficerStats(officerId);
      if (mounted && statsData != null) {
        setState(() {
          _stats = statsData;
          _isStatsLoading = false;
        });
      }
    }
  }

  Future<void> _loadComplaints({String? search, String? sortBy, String? priority}) async {
    if (search != null) _searchText = search;
    if (sortBy != null) _selectedSort = sortBy;
    if (priority != null) _selectedPriority = priority;

    setState(() => _isLoading = true);
 
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final officerId = authService.getOfficerId();
 
    if (officerId != null) {
      final complaints = await apiService.getOfficerComplaints(
        officerId,
        search: _searchText,
        sortBy: _selectedSort,
        priority: _selectedPriority,
      );
      if (mounted) {
        setState(() {
          _complaints = complaints;
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredComplaints {
    if (_complaints == null) return [];
    if (_filterStatus == 'all') return _complaints!;
    return _complaints!
        .where((c) => (c['status'] as String).toLowerCase() == _filterStatus)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Complaints'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                   _isStatsLoading
                      ? const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(),
                        ))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatCard("Total", _stats["total"] ?? 0, Colors.blue),
                            _buildStatCard("High", _stats["high"] ?? 0, Colors.red),
                            _buildStatCard("Medium", _stats["medium"] ?? 0, Colors.orange),
                            _buildStatCard("Low", _stats["low"] ?? 0, Colors.green),
                          ],
                        ),
                  const SizedBox(height: 15),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Search complaints...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) {
                      _loadComplaints(search: value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedSort,
                    decoration: InputDecoration(
                      labelText: "Sort By",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: "priority", child: Text("Priority")),
                      DropdownMenuItem(value: "latest", child: Text("Latest")),
                      DropdownMenuItem(value: "oldest", child: Text("Oldest")),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _loadComplaints(sortBy: value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPriorityChip("High", Colors.red),
                      _buildPriorityChip("Medium", Colors.orange),
                      _buildPriorityChip("Low", Colors.green),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _loadComplaints(),
                      child: _filteredComplaints.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 8),
                              itemCount: _filteredComplaints.length,
                              itemBuilder: (context, index) {
                                return _buildComplaintCard(_filteredComplaints[index]);
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> complaint) {
    String priority = complaint['priority_label'] ?? 'Low';

    Color priorityColor;
    if (priority == 'High') {
      priorityColor = Colors.red;
    } else if (priority == 'Medium') {
      priorityColor = Colors.orange;
    } else {
      priorityColor = Colors.green;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ComplaintDetailScreen(
                  complaintId: complaint['id'],
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1e3a8a).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        complaint['tracking_id'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e3a8a),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildStatusChip(complaint['status'] ?? 'submitted'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  complaint['text'] ?? '',
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
                    Icon(Icons.priority_high, size: 14, color: priorityColor),
                    const SizedBox(width: 4),
                    Text(
                      priority,
                      style: TextStyle(
                        fontSize: 12,
                        color: priorityColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(status),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No complaints found',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
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
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _getUrgencyColor(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String label, Color color) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedPriority == label,
      selectedColor: color.withOpacity(0.3),
      onSelected: (selected) {
        setState(() {
          _selectedPriority = selected ? label : "";
        });

        _loadComplaints(
          priority: _selectedPriority,
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Filter by Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('All', 'all'),
            _buildFilterOption('Submitted', 'submitted'),
            _buildFilterOption('Under Review', 'under_review'),
            _buildFilterOption('In Progress', 'in_progress'),
            _buildFilterOption('Resolved', 'resolved'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String value) {
    return RadioListTile(
      title: Text(label),
      value: value,
      groupValue: _filterStatus,
      onChanged: (val) {
        setState(() => _filterStatus = val as String);
        Navigator.pop(context);
      },
    );
  }
}