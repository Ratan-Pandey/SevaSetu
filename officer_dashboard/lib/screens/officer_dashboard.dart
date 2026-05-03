import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'complaints_list_screen.dart';
import 'profile_screen.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'complaint_detail_screen.dart';

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  int _pendingCount = 0;
  Timer? _pollingTimer;
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _fetchPendingCount();
    _initSocket();
    _pollingTimer = Timer.periodic(const Duration(minutes: 5), (_) => _fetchPendingCount());
    _screens = [
      DashboardHome(onTabRequested: (index) {
        setState(() => _currentIndex = index);
      }),
      const ComplaintsListScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _socketSubscription?.cancel();
    super.dispose();
  }

  void _initSocket() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    socketService.connect();
    _socketSubscription = socketService.dashboardUpdates.listen((_) {
      print("🔔 [DASHBOARD] Real-time update triggered via Socket");
      _fetchPendingCount();
    });
  }

  Future<void> _fetchPendingCount() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final officerId = authService.getOfficerId();
    if (officerId != null) {
      try {
        final data = await apiService.getOfficerDashboard(officerId);
        if (mounted && data != null) {
          setState(() {
            _pendingCount = data['pending'] ?? 0;
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Home' : _currentIndex == 1 ? 'Complaints' : 'Profile'),
        backgroundColor: const Color(0xFF1e3a8a),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1e3a8a),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFF1e3a8a)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    authService.officerData?['name'] ?? 'Officer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    authService.officerData?['email'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _currentIndex == 0,
              onTap: () {
                setState(() => _currentIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('All Complaints'),
              trailing: _pendingCount > 0 
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_pendingCount',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                : null,
              selected: _currentIndex == 1,
              onTap: () {
                setState(() => _currentIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              selected: _currentIndex == 2,
              onTap: () {
                setState(() => _currentIndex = 2);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context); // Close drawer
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await authService.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
    );
  }
}

class DashboardHome extends StatefulWidget {
  final Function(int)? onTabRequested;
  const DashboardHome({super.key, this.onTabRequested});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  bool _hasLoaded = false;
  Timer? _refreshTimer;
  DateTime? _lastUpdated;
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _initSocket();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socketSubscription?.cancel();
    super.dispose();
  }

  void _initSocket() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    _socketSubscription = socketService.dashboardUpdates.listen((_) {
      if (mounted) {
        print("🔔 [DASHBOARD-HOME] Real-time refresh triggered");
        _loadDashboard();
      }
    });
  }

  Future<void> _loadDashboard() async {
    // We removed the _hasLoaded guard to allow refreshing when coming back to this tab
    
    // But we still show a loader if it's the first time
    if (_dashboardData == null) {
      setState(() => _isLoading = true);
    }
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    // Use AuthService to get the ID (it already uses SharedPreferences)
    final officerId = authService.getOfficerId();
    print("🧠 OFFICER ID: $officerId");

    if (officerId != null) {
      final data = await apiService.getOfficerDashboard(officerId);
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
          if (data != null && data['last_activity_at'] != null) {
            _lastUpdated = DateTime.parse(data['last_activity_at']).toLocal();
          } else {
            _lastUpdated = null;
          }
        });
      }
    } else {
      print("❌ OFFICER ID NULL");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} mins ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    // Ensure no calls to _loadDashboard() here!
    final authService = Provider.of<AuthService>(context);
    final officerName = authService.officerData?['name'] ?? 'Officer';

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_dashboardData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text("Data Loading Failed", style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasLoaded = false; // Reset guard for manual retry
                    _isLoading = true;
                  });
                  _loadDashboard();
                },
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _hasLoaded = false); // Reset guard for pull-to-refresh
          await _loadDashboard();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Greeting Header
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1e3a8a),
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_lastUpdated != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Last activity: ${_formatTimeAgo(_lastUpdated!)}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Officer Info Header
              Container(
                padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.badge, color: Color(0xFF667eea)),
                              const SizedBox(width: 8),
                              Expanded( // 🔥 Added expanded to prevent overflow
                                child: Text(
                                  'Officer ID: ${authService.getOfficerId() ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            authService.officerData?['name'] ?? 'Officer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            authService.officerData?['email'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              authService.officerData?['department'] ?? 'Department',
                              style: const TextStyle(
                                color: Color(0xFF667eea),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stats Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = constraints.maxWidth > 600 ? 4 : (constraints.maxWidth < 380 ? 1 : 2);
                        double aspectRatio = constraints.maxWidth > 600 ? 2.5 : (constraints.maxWidth < 380 ? 4.0 : 1.5);
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: aspectRatio,
                          children: [
                        _buildStatCard(
                          'Total Complaints',
                          _dashboardData?['total_complaints']?.toString() ?? '0',
                          Icons.description,
                          const Color(0xFF3b82f6),
                        ),
                        _buildStatCard(
                          'Pending',
                          _dashboardData?['pending_complaints']?.toString() ?? '0',
                          Icons.pending,
                          const Color(0xFFf59e0b),
                        ),
                        _buildStatCard(
                          'In Progress',
                          _dashboardData?['in_progress_complaints']?.toString() ?? '0',
                          Icons.autorenew,
                          const Color(0xFF8b5cf6),
                        ),
                        _buildStatCard(
                          'Resolved',
                          _dashboardData?['resolved_complaints']?.toString() ?? '0',
                          Icons.check_circle,
                          const Color(0xFF10b981),
                        ),
                      ],
                    );
                  },
                ),
                    const SizedBox(height: 24),

                    // Recent Complaints Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Recent Complaints',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            if (widget.onTabRequested != null) {
                              widget.onTabRequested!(1);
                            }
                          },
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Recent Complaints List
                    if (_dashboardData?['recent_complaints'] != null &&
                        (_dashboardData!['recent_complaints'] as List).isNotEmpty)
                      ...(_dashboardData!['recent_complaints'] as List).take(5).map((complaint) {
                        return _buildRecentComplaintCard(complaint);
                      }).toList()
                    else
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No recent complaints',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentComplaintCard(Map<String, dynamic> complaint) {
    String priority = complaint['priority_label'] ?? 'Low';

    Color priorityColor;
    if (priority == 'Critical') {
      priorityColor = Colors.red;
    } else if (priority == 'High') {
      priorityColor = Colors.orange;
    } else if (priority == 'Medium') {
      priorityColor = Colors.amber;
    } else {
      priorityColor = Colors.green;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintDetailScreen(
              complaintId: complaint['id'],
            ),
          ),
        ).then((_) {
          // Re-load data when coming back
          _loadDashboard(); 
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.priority_high, color: priorityColor),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complaint['tracking_id'] ?? 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complaint['text'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // 🔹 ENTERPRISE PRIORITY BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: priorityColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: priorityColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    priority,
                    style: TextStyle(
                      color: priorityColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final authService = Provider.of<AuthService>(context, listen: false);
    final name = authService.officerData?['name']?.split(' ')[0] ?? 'Officer';

    if (hour < 12) {
      return 'Good Morning, $name';
    } else if (hour < 17) {
      return 'Good Afternoon, $name';
    } else {
      return 'Good Evening, $name';
    }
  }
}