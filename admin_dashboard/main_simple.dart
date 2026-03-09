import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/complaints_screen.dart';
import 'screens/officers_management_screen.dart';
import 'screens/analytics_dashboard_screen.dart';

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SevaSetu Admin',
      theme: ThemeData(
        primaryColor: const Color(0xFF2c3e50),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2c3e50)),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ComplaintsScreen(),
    const OfficersManagementScreen(),
    const AnalyticsDashboardScreen(),
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
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Complaints'),
          NavigationDestination(icon: Icon(Icons.badge), label: 'Officers'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Analytics'),
        ],
      ),
    );
  }
}
