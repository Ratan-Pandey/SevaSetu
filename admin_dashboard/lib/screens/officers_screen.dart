import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class OfficersScreen extends StatefulWidget {
  const OfficersScreen({super.key});

  @override
  State<OfficersScreen> createState() => _OfficersScreenState();
}

class _OfficersScreenState extends State<OfficersScreen> {
  List<dynamic> _officers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfficers();
  }

  Future<void> _loadOfficers() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/admin/officers"),
        headers: {'Authorization': 'Bearer ${authService.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _officers = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading officers: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addOfficer() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final idController = TextEditingController();
    final passController = TextEditingController();
    String? selectedDepartment;
 
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add New Officer"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name", hintText: "e.g. John Doe")),
                TextField(controller: idController, decoration: const InputDecoration(labelText: "Employee ID", hintText: "e.g. POL-101")),
                DropdownButtonFormField<String>(
                  value: selectedDepartment,
                  decoration: const InputDecoration(labelText: "Department"),
                  items: const [
                    DropdownMenuItem(value: "Power Department", child: Text("Power Department")),
                    DropdownMenuItem(value: "Water Department", child: Text("Water Department")),
                    DropdownMenuItem(value: "Municipal Services", child: Text("Municipal Services")),
                    DropdownMenuItem(value: "Health Department", child: Text("Health Department")),
                    DropdownMenuItem(value: "Police Department", child: Text("Police Department")),
                    DropdownMenuItem(value: "Vigilance Department", child: Text("Vigilance Department")),
                  ],
                  onChanged: (value) => setDialogState(() => selectedDepartment = value),
                ),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: "Official Email")),
                TextField(controller: passController, decoration: const InputDecoration(labelText: "Temporary Password"), obscureText: true),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || emailController.text.isEmpty || 
                    idController.text.isEmpty || passController.text.isEmpty || 
                    selectedDepartment == null) return;
                
                final authService = Provider.of<AuthService>(context, listen: false);
                final response = await http.post(
                  Uri.parse("${ApiService.baseUrl}/admin/officers/create"),
                  headers: {
                    'Authorization': 'Bearer ${authService.token}',
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'name': nameController.text,
                    'email': emailController.text,
                    'employee_id': idController.text,
                    'department': selectedDepartment,
                    'password': passController.text,
                  }),
                );

              if (response.statusCode == 200) {
                Navigator.pop(context);
                _loadOfficers();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Officer account created successfully")));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to create officer")));
              }
            },
            child: const Text("Create Account"),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteOfficer(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Officer?"),
        content: Text("Are you sure you want to remove $name? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await http.delete(
        Uri.parse("${ApiService.baseUrl}/admin/officers/$id"),
        headers: {'Authorization': 'Bearer ${authService.token}'},
      );

      if (response.statusCode == 200) {
        _loadOfficers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Officer removed")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Officer Management', style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOfficers),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOfficer,
        backgroundColor: const Color(0xFF059669),
        icon: const Icon(Icons.person_add),
        label: const Text("Add Officer"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _officers.isEmpty
              ? const Center(child: Text("No officers found"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _officers.length,
                  itemBuilder: (context, index) {
                    final officer = _officers[index];
                    final bool isPending = !(officer['profile_completed'] ?? false);
                    final String name = officer['name'] ?? "Pending Onboarding";
                    final String dept = officer['department'] ?? "Not Assigned";

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isPending ? Colors.orange.shade100 : const Color(0xFF059669).withOpacity(0.1),
                                  child: Icon(
                                    isPending ? Icons.hourglass_empty : Icons.person,
                                    color: isPending ? Colors.orange : const Color(0xFF059669),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(officer['email'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _deleteOfficer(officer['id'], name),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _infoChip(dept, isPending ? Colors.grey : Colors.blue),
                                const Spacer(),
                                Text(
                                  "ID: ${officer['employee_id']}",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                              ],
                            ),
                            if (isPending)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: const [
                                    Icon(Icons.info_outline, size: 14, color: Colors.amber),
                                    SizedBox(width: 8),
                                    Text("Waiting for officer to complete profile", style: TextStyle(fontSize: 10, color: Colors.amber)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}