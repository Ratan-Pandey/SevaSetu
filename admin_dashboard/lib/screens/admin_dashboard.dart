import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'analytics_screen.dart';
import 'users_screen.dart';
import 'officers_screen.dart';
import 'all_complaints_screen.dart';
import 'profile_screen.dart';
import '../services/realtime_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const DashboardHome(),
    const AnalyticsScreen(),
    const UsersScreen(),
    const OfficersScreen(),
    const AllComplaintsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.badge), label: 'Officers'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Complaints'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});
  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  Map<String, dynamic> stats = {};
  List departmentStats = [];
  List topProblems = [];
  List officers = [];
  Map<String, dynamic>? systemAnalytics;
  bool isLoading = true;
  RealTimeService? _realTimeService;

  // Expandable card states
  String? _expandedCard;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
    _realTimeService = RealTimeService(onUpdate: () {
      if (mounted) loadDashboardData();
    });
    _realTimeService!.connect();
  }

  @override
  void dispose() {
    _realTimeService?.dispose();
    super.dispose();
  }

  void _handleAuthError() {
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.signOut();
  }

  Future<void> loadDashboardData() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/admin/dashboard-summary"),
        headers: {'Authorization': 'Bearer ${authService.token}'},
      );
      if (response.statusCode == 401) { _handleAuthError(); return; }
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          stats = data['stats'];
          departmentStats = data['department_stats'];
          topProblems = data['top_problems'];
          officers = data['officers'];
          systemAnalytics = data['system_analytics'];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _toggleCard(String cardId) {
    setState(() => _expandedCard = _expandedCard == cardId ? null : cardId);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final adminName = authService.adminData?['name'] ?? 'Admin';
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Command Center', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh & Reconnect',
            onPressed: () {
              setState(() => isLoading = true);
              loadDashboardData();
              _realTimeService?.reconnect();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(adminName),
                    const SizedBox(height: 24),
                    _buildMetricCards(isDesktop),
                    const SizedBox(height: 24),
                    if (isDesktop)
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 3, child: _buildDeptPieSection()),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: _buildTopProblemsSection()),
                      ])
                    else ...[
                      _buildDeptPieSection(),
                      const SizedBox(height: 20),
                      _buildTopProblemsSection(),
                    ],
                    const SizedBox(height: 24),
                    if (isDesktop)
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _buildStatusChartSection()),
                        const SizedBox(width: 20),
                        Expanded(child: _buildOfficersSection()),
                      ])
                    else ...[
                      _buildStatusChartSection(),
                      const SizedBox(height: 20),
                      _buildOfficersSection(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // ─── GREETING BANNER ───
  Widget _buildGreeting(String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final total = stats['total'] ?? 0;
    final pending = stats['pending'] ?? 0;
    final rate = stats['resolution_rate'] ?? 0;
    final today = stats['today_complaints'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF059669).withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('System Administrator', style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 8, children: [
              _bannerChip(Icons.today, '$today today'),
              _bannerChip(Icons.pending_actions, '$pending pending'),
              _bannerChip(Icons.check_circle_outline, '$rate% resolved'),
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
          child: Text('$total', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _bannerChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ─── INTERACTIVE METRIC CARDS ───
  Widget _buildMetricCards(bool isDesktop) {
    final totalOfficers = systemAnalytics?['total_officers'] ?? 0;
    final totalUsers = systemAnalytics?['total_users'] ?? 0;
    final total = stats['total'] ?? 0;
    final pending = stats['pending'] ?? 0;
    final resolved = stats['resolved'] ?? 0;

    final cardWidth = isDesktop 
        ? (MediaQuery.of(context).size.width - 40 - (16 * 3)) / 4 
        : (MediaQuery.of(context).size.width - 40 - 16) / 2;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: cardWidth,
          child: _metricCard('complaints', 'Total Complaints', '$total', Icons.assignment, const Color(0xFF3B82F6),
            children: [
              _detailRow('Critical', '${stats['critical'] ?? 0}', Colors.red),
              _detailRow('High', '${stats['high_priority'] ?? 0}', Colors.deepOrange),
              _detailRow('Medium', '${stats['medium_priority'] ?? 0}', Colors.amber.shade700),
              _detailRow('Low', '${stats['low_priority'] ?? 0}', Colors.green),
            ]),
        ),
        SizedBox(
          width: cardWidth,
          child: _metricCard('officers', 'Active Officers', '$totalOfficers', Icons.badge, const Color(0xFF8B5CF6),
            children: officers.take(4).map((o) =>
              _detailRow(o['name'] ?? '', o['department'] ?? '', const Color(0xFF8B5CF6))
            ).toList()),
        ),
        SizedBox(
          width: cardWidth,
          child: _metricCard('pending', 'Pending', '$pending', Icons.hourglass_top, const Color(0xFFF59E0B),
            children: [
              _detailRow('Submitted', '${stats['submitted'] ?? 0}', Colors.orange),
              _detailRow('Under Review', '${stats['under_review'] ?? 0}', Colors.blue),
              _detailRow('In Progress', '${stats['in_progress'] ?? 0}', Colors.teal),
            ]),
        ),
        SizedBox(
          width: cardWidth,
          child: _metricCard('resolved', 'Resolved', '$resolved', Icons.check_circle, const Color(0xFF10B981),
            children: [
              _detailRow('Resolution Rate', '${stats['resolution_rate'] ?? 0}%', Colors.green),
              _detailRow('Total Users', '$totalUsers', Colors.purple),
              _detailRow('Today\'s New', '${stats['today_complaints'] ?? 0}', Colors.blue),
            ]),
        ),
      ],
    );
  }

  Widget _metricCard(String id, String title, String value, IconData icon, Color color, {List<Widget> children = const []}) {
    final isExpanded = _expandedCard == id;
    return GestureDetector(
      onTap: () => _toggleCard(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isExpanded ? color.withOpacity(0.5) : Colors.grey.shade200, width: isExpanded ? 2 : 1),
          boxShadow: [BoxShadow(color: isExpanded ? color.withOpacity(0.15) : Colors.black.withOpacity(0.04), blurRadius: isExpanded ? 16 : 8, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey.shade400, size: 20),
          ]),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          if (isExpanded && children.isNotEmpty) ...[
            Divider(height: 20, color: Colors.grey.shade200),
            ...children,
          ],
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  // ─── PIE CHART ───
  Widget _buildDeptPieSection() {
    return _sectionCard('Complaints by Department', Icons.pie_chart, _buildDepartmentChart());
  }

  int _touchedIndex = -1;

  Widget _buildDepartmentChart() {
    if (departmentStats.isEmpty) return Center(child: Text('No data', style: TextStyle(color: Colors.grey.shade500)));
    
    final total = departmentStats.fold<int>(0, (sum, d) => sum + (d['total'] as int));

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 4,
                    centerSpaceRadius: 50,
                    sections: departmentStats.asMap().entries.map((entry) {
                      final i = entry.key;
                      final d = entry.value;
                      final isTouched = i == _touchedIndex;
                      final double val = (d['total'] as num).toDouble();
                      final double radius = isTouched ? 30.0 : 20.0;
                      
                      return PieChartSectionData(
                        value: val,
                        title: '',
                        radius: radius,
                        color: _deptColor(i).withOpacity(isTouched ? 1.0 : 0.85),
                        badgeWidget: null,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: departmentStats.asMap().entries.map((entry) {
                      final i = entry.key;
                      final d = entry.value;
                      final isSelected = i == _touchedIndex;
                      final percentage = total > 0 ? (d['total'] as int) / total * 100 : 0;
                      
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? _deptColor(i).withOpacity(0.05) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _deptColor(i),
                                shape: BoxShape.circle,
                                boxShadow: isSelected ? [BoxShadow(color: _deptColor(i).withOpacity(0.4), blurRadius: 6)] : [],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['department'],
                                    style: TextStyle(
                                      fontSize: 12, 
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, 
                                      color: isSelected ? _deptColor(i) : const Color(0xFF1F2937)
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${d['total']} issues (${percentage.toStringAsFixed(0)}%)',
                                    style: TextStyle(fontSize: 10, color: isSelected ? _deptColor(i).withOpacity(0.7) : Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          // Center Label
          Positioned.fill(
            child: Align(
              alignment: const Alignment(-0.45, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _touchedIndex == -1 ? '$total' : '${departmentStats[_touchedIndex]['total']}',
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.w800, 
                      color: _touchedIndex == -1 ? const Color(0xFF1F2937) : _deptColor(_touchedIndex), 
                      letterSpacing: -1
                    ),
                  ),
                  Text(
                    _touchedIndex == -1 ? 'TOTAL' : (departmentStats[_touchedIndex]['department'] as String).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9, 
                      fontWeight: FontWeight.w800, 
                      color: _touchedIndex == -1 ? Colors.grey.shade400 : _deptColor(_touchedIndex).withOpacity(0.6),
                      letterSpacing: 0.5
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TOP PROBLEMS ───
  Widget _buildTopProblemsSection() {
    return _sectionCard('Top Problem Areas', Icons.warning_amber_rounded, SizedBox(
      height: 210,
      child: topProblems.isEmpty
          ? const Center(child: Text('No critical areas'))
          : ListView.separated(
              itemCount: topProblems.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (_, i) {
                final d = topProblems[i];
                final ratio = (d['pending_ratio'] as num).toDouble();
                final c = ratio > 0.7 ? Colors.red : ratio > 0.4 ? Colors.orange : Colors.green;
                return ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.warning, color: c, size: 18),
                  ),
                  title: Text(d['department'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  subtitle: Text('${d['pending']}/${d['total']} pending', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('${(ratio * 100).toStringAsFixed(0)}%', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                );
              },
            ),
    ));
  }

  // ─── STATUS BAR CHART ───
  Widget _buildStatusChartSection() {
    return _sectionCard('Status Overview', Icons.bar_chart, Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem('Pending', Colors.orange),
            const SizedBox(width: 12),
            _legendItem('Review', Colors.blue),
            const SizedBox(width: 12),
            _legendItem('Resolved', Colors.green),
            const SizedBox(width: 12),
            _legendItem('Total', const Color(0xFF6366F1)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(height: 200, child: _buildStatusBarChart()),
      ],
    ));
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatusBarChart() {
    final double maxY = ((stats['total'] ?? 50) as num).toDouble();
    final double pendingPart = (((stats['submitted'] ?? 0) + (stats['in_progress'] ?? 0)) as num).toDouble();
    final double reviewPart = ((stats['under_review'] ?? 0) as num).toDouble();
    
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY > 0 ? maxY : 50,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          tooltipBgColor: const Color(0xFF1F2937),
          tooltipRoundedRadius: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            String label = groupIndex == 0 ? 'Active' : groupIndex == 1 ? 'Resolved' : 'Total';
            return BarTooltipItem(
              '$label\n',
              const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: rod.toY.toInt().toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            );
          },
        ),
      ),
      barGroups: [
        // Bar 0: Stacked Pending + Under Review
        BarChartGroupData(
          x: 0,
          barRods: [
            BarChartRodData(
              toY: pendingPart + reviewPart,
              width: 28,
              borderRadius: BorderRadius.circular(6),
              rodStackItems: [
                BarChartRodStackItem(0, pendingPart, Colors.orange),
                BarChartRodStackItem(pendingPart, pendingPart + reviewPart, Colors.blue),
              ],
            ),
          ],
        ),
        // Bar 1: Resolved
        _bar(1, ((stats['resolved'] ?? 0) as num).toDouble(), Colors.green),
        // Bar 2: Total Complaints
        _bar(2, ((stats['total'] ?? 0) as num).toDouble(), const Color(0xFF6366F1)),
      ],
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
          const labels = ['Pending/Review', 'Resolved', 'Total'];
          return Padding(padding: const EdgeInsets.only(top: 8), child: Text(v.toInt() < labels.length ? labels[v.toInt()] : '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)));
        })),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY > 0 ? maxY / 5 : 10),
    ));
  }

  BarChartGroupData _bar(int x, double y, Color c) {
    return BarChartGroupData(x: x, barRods: [BarChartRodData(toY: y, color: c, width: 28, borderRadius: BorderRadius.circular(6),
      backDrawRodData: BackgroundBarChartRodData(show: true, toY: ((stats['total'] ?? 50) as num).toDouble(), color: c.withOpacity(0.07)))]);
  }

  // ─── OFFICERS ───
  Widget _buildOfficersSection() {
    return _sectionCard('Officers', Icons.people_alt, SizedBox(
      height: 200,
      child: officers.isEmpty
          ? const Center(child: Text('No officers'))
          : ListView.separated(
              itemCount: officers.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (_, i) {
                final o = officers[i];
                return ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: _deptColor(i).withOpacity(0.15),
                    child: Text((o['name'] ?? 'O')[0], style: TextStyle(color: _deptColor(i), fontWeight: FontWeight.bold)),
                  ),
                  title: Text(o['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text('${o['department']} • ${o['employee_id']}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), onPressed: () => _deleteOfficer(o)),
                );
              },
            ),
    ));
  }

  Future<void> _deleteOfficer(dynamic o) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Officer"),
        content: Text("Delete ${o['name']}? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Delete")),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final response = await http.delete(
          Uri.parse("${ApiService.baseUrl}/admin/delete-officer/${o['id']}"),
          headers: {'Authorization': 'Bearer ${authService.token}'},
        );
        if (response.statusCode == 200) {
          loadDashboardData();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Officer deleted')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ─── SHARED SECTION CARD ───
  Widget _sectionCard(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: const Color(0xFF059669)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  Color _deptColor(int i) {
    const c = [Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4), Color(0xFFEC4899)];
    return c[i % c.length];
  }
}