import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/admin/users"),
        headers: {'Authorization': 'Bearer ${authService.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _users = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading users: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUserDetails(dynamic user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF059669),
              child: Text(user['name'][0], style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(user['name'], style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailTile(Icons.email, "Email", user['email']),
                _detailTile(Icons.phone, "Phone", user['phone_number'] ?? "Not provided"),
                _detailTile(Icons.location_on, "Address", "${user['address'] ?? ''} ${user['city'] ?? ''} ${user['state'] ?? ''}".trim().isEmpty ? "No address" : "${user['address'] ?? ''}, ${user['city'] ?? ''}, ${user['state'] ?? ''}"),
                _detailTile(Icons.credit_card, "Aadhaar", user['aadhaar_number'] ?? "Not verified"),
                _detailTile(Icons.calendar_today, "Joined", _formatDate(user['created_at'])),
                
                const Divider(height: 32),
                
                Row(
                  children: [
                    const Icon(Icons.report_problem, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text("Account Status: ${user['is_suspended'] ? 'SUSPENDED' : 'ACTIVE'}", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: user['is_suspended'] ? Colors.red : Colors.green)),
                  ],
                ),
                
                if (user['report_count'] > 0) ...[
                  const SizedBox(height: 16),
                  const Text("Reports Log", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...(user['reports'] as List).map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['reason'] ?? "No reason provided", style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(_formatDate(r['created_at']), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  )).toList(),
                ] else ...[
                  const SizedBox(height: 16),
                  const Text("No reports recorded for this user.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          if (user['is_suspended'])
            ElevatedButton(
              onPressed: () => _handleSuspension(user['id'], false),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text("Lift Suspension"),
            )
          else if (user['report_count'] > 0)
            ElevatedButton(
              onPressed: () => _handleSuspension(user['id'], true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("Suspend User"),
            ),
        ],
      ),
    );
  }

  Future<void> _handleSuspension(int userId, bool suspend) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final endpoint = suspend ? "suspend" : "lift-suspension"; // This depends on your API routes
    // For now we'll just mock the call or implement if backend has it
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(suspend ? "User suspended" : "Suspension lifted")));
    _loadUsers();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "N/A";
    try {
      final dt = DateTime.parse(dateStr);
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }

  Widget _detailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text("No users found"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final bool isSuspended = user['is_suspended'] ?? false;
                    final int reports = user['report_count'] ?? 0;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        onTap: () => _showUserDetails(user),
                        leading: CircleAvatar(
                          backgroundColor: isSuspended ? Colors.red : const Color(0xFF059669),
                          child: Text(
                            user['name'][0],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (isSuspended)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: const Text("SUSPENDED", style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        subtitle: Text(user['email'], style: const TextStyle(fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${user['complaint_count']} complaints', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            if (reports > 0)
                              Text('$reports reports', style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}