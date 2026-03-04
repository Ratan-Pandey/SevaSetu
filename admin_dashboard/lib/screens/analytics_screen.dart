import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final data = await apiService.getSystemAnalytics();
    if (mounted) {
      setState(() {
        _analytics = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  // Urgency Distribution
                  const Text(
                    'Urgency Distribution',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 250,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _buildUrgencyChart(),
                  ),
                  const SizedBox(height: 28),

                  // Status Bar Chart
                  const Text(
                    'Status Breakdown',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 300,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _buildStatusBarChart(),
                  ),
                  const SizedBox(height: 28),

                  // Department Stats Table
                  const Text(
                    'Department Performance',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildDepartmentTable(),
                ],
              ),
            ),
    );
  }

  Widget _buildUrgencyChart() {
    final urgencyData = _analytics?['by_urgency'] as Map<String, dynamic>? ?? {};
    if (urgencyData.isEmpty) {
      return const Center(child: Text('No data'));
    }

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: (urgencyData['High'] ?? 0).toDouble(),
            title: 'High\n${urgencyData['High'] ?? 0}',
            radius: 80,
            color: Colors.red,
            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          PieChartSectionData(
            value: (urgencyData['Medium'] ?? 0).toDouble(),
            title: 'Medium\n${urgencyData['Medium'] ?? 0}',
            radius: 80,
            color: Colors.orange,
            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          PieChartSectionData(
            value: (urgencyData['Low'] ?? 0).toDouble(),
            title: 'Low\n${urgencyData['Low'] ?? 0}',
            radius: 80,
            color: Colors.green,
            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
        sectionsSpace: 4,
        centerSpaceRadius: 0,
      ),
    );
  }

  Widget _buildStatusBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 50,
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: (_analytics?['pending_complaints'] ?? 0).toDouble(), color: Colors.orange, width: 40)]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: (_analytics?['in_progress_complaints'] ?? 0).toDouble(), color: Colors.blue, width: 40)]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: (_analytics?['resolved_complaints'] ?? 0).toDouble(), color: Colors.green, width: 40)]),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 0: return const Text('Pending');
                  case 1: return const Text('In Progress');
                  case 2: return const Text('Resolved');
                  default: return const Text('');
                }
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }

  Widget _buildDepartmentTable() {
    final deptData = _analytics?['by_department'] as Map<String, dynamic>? ?? {};
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text('Count', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
          ...deptData.entries.map((entry) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(entry.key)),
                  Expanded(
                    child: Text(
                      entry.value.toString(),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}