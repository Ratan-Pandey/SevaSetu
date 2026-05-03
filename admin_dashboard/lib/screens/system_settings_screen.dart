import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  bool _autoAssignment = true;
  bool _maintenanceMode = false;
  String _systemEmail = "admin@sevasetu.gov.in";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoAssignment = prefs.getBool('auto_assignment') ?? true;
      _maintenanceMode = prefs.getBool('maintenance_mode') ?? false;
      _systemEmail = prefs.getString('system_email') ?? "admin@sevasetu.gov.in";
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    
    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_assignment', _autoAssignment);
    await prefs.setBool('maintenance_mode', _maintenanceMode);
    await prefs.setString('system_email', _systemEmail);
    
    // Save to Backend
    try {
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/admin/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Provider.of<AuthService>(context, listen: false).token}',
        },
        body: jsonEncode({
          'auto_assignment': _autoAssignment,
          'maintenance_mode': _maintenanceMode,
          'system_email': _systemEmail,
        }),
      );
      
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved to cloud successfully!')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error saving settings to backend: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('System Settings'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Automation"),
                  _buildSettingCard(
                    title: "AI Auto-Assignment",
                    subtitle: "Automatically assign complaints to the least busy officer",
                    trailing: Switch(
                      value: _autoAssignment,
                      onChanged: (v) {
                        setState(() => _autoAssignment = v);
                        _saveSettings(); // Auto-save for immediate feedback
                      },
                      activeColor: const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader("Infrastructure"),
                  _buildSettingCard(
                    title: "System Maintenance Mode",
                    subtitle: "Temporarily disable citizen complaint submissions",
                    trailing: Switch(
                      value: _maintenanceMode,
                      onChanged: (v) {
                        setState(() => _maintenanceMode = v);
                        _saveSettings(); // Auto-save for immediate feedback
                      },
                      activeColor: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingCard(
                    title: "System Admin Email",
                    subtitle: "Destination for critical alerts and system recovery logs",
                    trailing: Container(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: TextField(
                        controller: TextEditingController(text: _systemEmail),
                        onChanged: (v) => _systemEmail = v,
                        decoration: const InputDecoration(
                          hintText: "Enter email",
                          isDense: true,
                          border: OutlineInputBorder(),
                          suffixIcon: Tooltip(
                            message: "This is for system alerts only. Use your existing credentials to login.",
                            child: Icon(Icons.info_outline, size: 16),
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      label: const Text('Force Cloud Sync', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingCard({required String title, required String subtitle, required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 400;
          return Flex(
            direction: isWide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isWide ? 1 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (!isWide) const SizedBox(height: 16),
              if (isWide) const SizedBox(width: 20),
              trailing,
            ],
          );
        },
      ),
    );
  }
}
