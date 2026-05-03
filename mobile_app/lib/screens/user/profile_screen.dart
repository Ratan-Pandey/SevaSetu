import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'package:Seva_Setu/screens/user/help_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _fullUserData;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // Future to manually reload profile if needed
  Future<void> _loadProfile() async {
    if (_isFetching) return;
    
    setState(() => _isFetching = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final userId = authService.getUserId();
      
      if (userId != null) {
        final data = await apiService.getUserProfile(userId);
        if (data != null && mounted) {
          setState(() {
            _fullUserData = data;
          });
          print("🔥 FULL USER DATA: $_fullUserData");
        }
      }
      
      // Also trigger loadUserData from AuthService to keep it in sync
      await authService.loadUserData();
    } catch (e) {
      print("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    // Prefer full data from API, but fallback to auth service caches
    final userData = _fullUserData ?? authService.userData;
    
    final userName = userData?['name'] ?? 'User';
    final userEmail = userData?['email'] ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with Profile
              Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF667eea),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    _isFetching && _fullUserData == null
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    const SizedBox(height: 8),

                    // Email
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            userEmail,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content Cards
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Account Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Profile Info Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
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
                              _buildInfoTile(
                                Icons.person_outline,
                                'Name',
                                userName,
                                const Color(0xFF667eea),
                              ),
                              const Divider(height: 1),
                              _buildInfoTile(
                                Icons.email_outlined,
                                'Email',
                                userEmail,
                                const Color(0xFF42A5F5),
                              ),
                              const Divider(height: 1),
                              _buildInfoTile(
                                Icons.verified_user_outlined,
                                'Status',
                                userData?['profile_completed'] == true ? 'Verified' : 'Pending',
                                userData?['profile_completed'] == true ? const Color(0xFF66BB6A) : Colors.orange,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Quick Actions
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildActionCard(
                          context,
                          Icons.edit_outlined,
                          'Edit Profile',
                          'Update your personal information',
                          const Color(0xFF667eea),
                          () async {
                            // 🔥 PASS FULL DATA TO EDIT SCREEN
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditProfileScreen(initialData: userData),
                              ),
                            );

                            if (result == true) {
                              _loadProfile(); // 🔥 reload user data
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildActionCard(
                          context,
                          Icons.notifications_outlined,
                          'Notifications',
                          'Manage your notification preferences',
                          const Color(0xFFFFA726),
                          () {
                            final userId = authService.getUserId();
                            if (userId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NotificationsScreen(userId: userId),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        _buildActionCard(
                          context,
                          Icons.help_outline,
                          'Help & Support',
                          'Get help with your complaints',
                          const Color(0xFF42A5F5),
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => HelpSupportScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        // Sign Out Button
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.red.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Sign Out'),
                                    content: const Text(
                                      'Are you sure you want to sign out?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Sign Out'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true && context.mounted) {
                                  await authService.signOut();
                                  if (context.mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (_) => const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.logout,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Sign Out',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Version
                        Center(
                          child: Text(
                            'Grievance Intelligence v1.0.0',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}