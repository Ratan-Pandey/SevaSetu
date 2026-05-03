import 'dart:async';
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
  
  // Search enhancements
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
    _loadStats();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
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

    // We don't want to show a FULL transparency loader for search, 
    // it makes the search bar disappear/lose focus.
    setState(() => _isLoading = true);
 
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final officerId = authService.getOfficerId();
 
    if (officerId != null) {
      print("📡 Fetching complaints for officer: $officerId (Search: '$_searchText')");
      final complaints = await apiService.getOfficerComplaints(
        officerId,
        search: _searchText,
        sortBy: _selectedSort,
        priority: _selectedPriority,
      );
      
      if (mounted) {
        setState(() {
          _complaints = complaints ?? [];
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() { _complaints = []; _isLoading = false; });
    }
  }

  void _onSearchChanged(String value) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _loadComplaints(search: value);
    });
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
      body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 5), // Reduced space since cards are gone
                  const SizedBox(height: 15),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search complaints...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear), 
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged("");
                            })
                        : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedPriority == "" ? "All" : _selectedPriority,
                    decoration: InputDecoration(
                      labelText: "Filter by Priority",
                      prefixIcon: const Icon(Icons.filter_list),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: ["All", "Critical", "High", "Medium", "Low"]
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _loadComplaints(priority: value == "All" ? "" : value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: () => _loadComplaints(),
                            child: _filteredComplaints.isEmpty
                                ? ListView(
                                    children: [SizedBox(height: 200, child: _buildEmptyState())],
                                  )
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
    if (priority == 'Critical') {
      priorityColor = Colors.red;
    } else if (priority == 'High') {
      priorityColor = Colors.orange;
    } else if (priority == 'Medium') {
      priorityColor = Colors.amber; // Vibrant Yellow
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
            ).then((_) => _loadComplaints());
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1e3a8a).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          complaint['tracking_id'] ?? 'N/A',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1e3a8a),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    Expanded(
                      child: Text(
                        complaint['ai_category'] ?? 'N/A',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
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
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
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
      case 'closed_by_user':
      case 'cancelled':
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