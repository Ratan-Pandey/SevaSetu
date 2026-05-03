import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  RealTimeService? _realTimeService;
  String? _selectedDepartment;
  Map<String, dynamic>? _deptStats;
  bool _isLoadingDept = false;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
    
    // Initialize Real-time updates
    _realTimeService = RealTimeService(onUpdate: () {
      if (mounted) {
        _loadAnalytics();
      }
    });
    _realTimeService!.connect();
  }

  @override
  void dispose() {
    _realTimeService?.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    _realTimeService?.reconnect(); // Reconnect if socket was dropped
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final data = await apiService.getSystemAnalytics(token: authService.token);
    if (mounted) {
      setState(() {
        _analytics = data;
        _isLoading = false;
        
        // Default select first department if none selected
        if (_selectedDepartment == null && data != null) {
          final depts = data['by_department'] as List<dynamic>? ?? [];
          if (depts.isNotEmpty) {
            _selectedDepartment = depts.first['department'];
            _loadDeptStats(_selectedDepartment!);
          }
        } else if (_selectedDepartment != null) {
          _loadDeptStats(_selectedDepartment!);
        }
      });
    }
  }

  Future<void> _showTopOfficers(String deptName) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.stars, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(child: Text("Top Officers: $deptName", style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: FutureBuilder<List<dynamic>>(
          future: _fetchTopOfficers(deptName, authService.token),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Text("Failed to load officers");
            }
            final officers = snapshot.data!;
            if (officers.isEmpty) return const Text("No performance data available");
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Top 5 officers by resolution count", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                ...officers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final o = entry.value;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade100,
                      child: Text("${i+1}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(o['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text("${o['count']} Solved", style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  );
                }).toList(),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  Future<List<dynamic>> _fetchTopOfficers(String deptName, String? token) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/admin/department/${Uri.encodeComponent(deptName)}/top-officers"),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint("Error fetching top officers: $e");
    }
    return [];
  }

  Future<void> _loadDeptStats(String deptName) async {
    setState(() => _isLoadingDept = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/admin/department/${Uri.encodeComponent(deptName)}/stats"),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _deptStats = json.decode(response.body);
          _isLoadingDept = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dept stats: $e");
      if (mounted) setState(() => _isLoadingDept = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detailed Analytics'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Maps
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _mapSection('Complaint Hotspots', _buildComplaintMap())),
                        const SizedBox(width: 20),
                        Expanded(child: _mapSection('Complaint Density (Heatmap)', _buildHeatmapMap())),
                      ],
                    )
                  else ...[
                    _mapSection('Complaint Hotspots', _buildComplaintMap()),
                    const SizedBox(height: 20),
                    _mapSection('Complaint Density (Heatmap)', _buildHeatmapMap()),
                  ],
                  
                  const SizedBox(height: 28),

                  // Temporal Trends (Full Width)
                  _dataSection('Complaint Volume Trends (Last 7 Days)', _buildTemporalTrendChart()),
                  
                  const SizedBox(height: 28),

                  // Row 2: Deep Dive & Table
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _dataSection('Department Deep Dive', _buildDeptDeepDive())),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: _dataSection('Performance Table', _buildDepartmentTable())),
                      ],
                    )
                  else ...[
                    _dataSection('Department Deep Dive', _buildDeptDeepDive()),
                    const SizedBox(height: 28),
                    _dataSection('Performance Table', _buildDepartmentTable()),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _mapSection(String title, Widget map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: map,
          ),
        ),
      ],
    );
  }

  Widget _dataSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildHeatmapMap() {
    final locations = _analytics?['complaint_locations'] as List<dynamic>? ?? [];
    
    if (locations.isEmpty) {
      return const Center(child: Text('No location data available'));
    }

    final data = locations.map((loc) => WeightedLatLng(LatLng(loc['lat'], loc['lng']), 1.0)).toList();

    // Default center
    final center = locations.isNotEmpty 
        ? LatLng(locations[0]['lat'], locations[0]['lng'])
        : LatLng(20.5937, 78.9629);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 10.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.admin_dashboard',
          tileProvider: CancellableNetworkTileProvider(),
        ),
        HeatMapLayer(
          heatMapDataSource: InMemoryHeatMapDataSource(data: data),
          heatMapOptions: HeatMapOptions(
            radius: 30,
            gradient: {
              0.2: Colors.blue,
              0.5: Colors.green,
              0.8: Colors.amber,
              1.0: Colors.red,
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComplaintMap() {
    final locations = _analytics?['complaint_locations'] as List<dynamic>? ?? [];
    
    if (locations.isEmpty) {
      return const Center(child: Text('No location data available'));
    }

    // Default to the first location or a center point
    final center = locations.isNotEmpty 
        ? LatLng(locations[0]['lat'], locations[0]['lng'])
        : LatLng(20.5937, 78.9629); // Center of India

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 11.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.admin_dashboard',
          tileProvider: CancellableNetworkTileProvider(),
        ),
        MarkerLayer(
          markers: locations.map((loc) {
            final markerColor = _getStatusColor(loc['status']);
            
            return Marker(
              point: LatLng(loc['lat'], loc['lng']),
              width: 45,
              height: 45,
              child: GestureDetector(
                onTap: () => _showComplaintDetails(loc),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    decoration: BoxDecoration(
                      color: markerColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: markerColor,
                      size: 35,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showComplaintDetails(dynamic loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc['dept'] ?? 'General',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                      Text(
                        "ID: ${loc['id']}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(loc['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    loc['status']?.toString().toUpperCase() ?? 'PENDING',
                    style: TextStyle(color: _getStatusColor(loc['status']), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text("Complainant", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  radius: 16,
                  child: Text(loc['user']?[0] ?? 'U'),
                ),
                const SizedBox(width: 12),
                Text(loc['user'] ?? 'Unknown User', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  loc['desc'] ?? 'No description provided',
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'submitted':
      case 'under_review':
      case 'in_progress':
        return Colors.amber; // Better visibility than pure yellow
      case 'closed_by_user':
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  Widget _buildTemporalTrendChart() {
    final trends = _analytics?['temporal_trends'] as List<dynamic>? ?? [];
    if (trends.isEmpty) return const Center(child: Text('No trend data available'));

    final spots = trends.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['count'] as num).toDouble());
    }).toList();

    double maxCount = trends.map((e) => (e['count'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    if (maxCount < 5) maxCount = 5;

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 32, 32, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxCount / 5,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < trends.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(trends[index]['date'], style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (maxCount / 5).clamp(1.0, 1000.0),
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 10));
                },
                reservedSize: 28,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (trends.length - 1).toDouble(),
          minY: 0,
          maxY: maxCount * 1.2,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: const Color(0xFF1F2937), // Sleek dark grey
              tooltipRoundedRadius: 8,
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  return LineTooltipItem(
                    '${barSpot.y.toInt()} Complaints',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF059669),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF059669),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [const Color(0xFF059669).withOpacity(0.2), const Color(0xFF059669).withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeptDeepDive() {
    final depts = _analytics?['by_department'] as List<dynamic>? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business, color: Color(0xFF059669)),
              const SizedBox(width: 10),
              const Text("Select Department:", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
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
                      items: (_analytics?['by_department'] as List<dynamic>? ?? []).map((dynamic d) {
                        final String name = d['department'];
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(name, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() => _selectedDepartment = newValue);
                          _loadDeptStats(newValue);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoadingDept)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_deptStats != null)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSmallStatCard("Total Department Complaints", _deptStats!['total_complaints'].toString(), const Color(0xFF059669)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text("Status Distribution", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: _buildDeptStatusChart(),
                ),
              ],
            )
          else
            const Center(child: Text("Select a department to view details")),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }

  Widget _buildDeptStatusChart() {
    final statusMap = _deptStats?['status_breakdown'] as Map<String, dynamic>? ?? {};
    
    // Combining Pending (submitted), Under Review, and In Progress into "Under Work"
    final underWork = (
      (statusMap['submitted'] ?? 0) + 
      (statusMap['under_review'] ?? 0) + 
      (statusMap['in_progress'] ?? 0)
    ).toDouble();
    
    final resolved = (statusMap['resolved'] ?? 0).toDouble();

    final maxVal = underWork > resolved ? underWork : resolved;
    final maxY = maxVal > 5 ? maxVal * 1.2 : 5.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: const Color(0xFF1F2937),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String label = group.x == 0 ? 'Under Work' : 'Resolved';
              return BarTooltipItem(
                '$label\n',
                const TextStyle(color: Colors.white70, fontSize: 10),
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
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(
              toY: underWork, 
              color: const Color(0xFFF59E0B), // Amber
              width: 40, 
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6))
            )
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(
              toY: resolved, 
              color: const Color(0xFF10B981), // Emerald/Green
              width: 40, 
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6))
            )
          ]),
        ],
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 0: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Under Work', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)));
                  case 1: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Resolved', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)));
                  default: return const Text('');
                }
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildStatusBarChart() {
    return const SizedBox.shrink();
  }

  Widget _buildDepartmentTable() {
    final depts = _analytics?['by_department'] as List<dynamic>? ?? [];
    
    // Sort by resolution rate (Top Performing)
    final sortedDepts = List<dynamic>.from(depts);
    sortedDepts.sort((a, b) => (b['resolution_rate'] as num).compareTo(a['resolution_rate'] as num));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
          if (sortedDepts.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No department data available")))
          else
            ...sortedDepts.map((d) {
              final rate = (d['resolution_rate'] as num).toDouble();
              final color = rate > 70 ? Colors.green : rate > 40 ? Colors.orange : Colors.red;
              
              return InkWell(
                onTap: () => _showTopOfficers(d['department']),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3, 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['department'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            const Text("View Top Officers", style: TextStyle(fontSize: 9, color: Colors.blue)),
                          ],
                        )
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text("${rate.toStringAsFixed(1)}%", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          d['total'].toString(),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}