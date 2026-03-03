import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'department_selection_screen.dart';
import 'my_complaints_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const DashboardHome(),
    const MyComplaintsScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'My Complaints',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userName = authService.userData?['name'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grievance Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Grievance Intelligence',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Grievance Intelligence System',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $userName!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submit and track your complaints with AI assistance',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Submit Complaint Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DepartmentSelectionScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Submit New Complaint'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            
            // Quick Info Cards
            Text(
              'Departments',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            
            _buildDepartmentCard(
              context,
              'Power Department',
              'Electricity issues, power cuts, transformer problems',
              Icons.electrical_services,
              Colors.amber,
            ),
            _buildDepartmentCard(
              context,
              'Water Department',
              'Water supply, leakage, quality issues',
              Icons.water_drop,
              Colors.blue,
            ),
            _buildDepartmentCard(
              context,
              'Municipal Services',
              'Sanitation, roads, street lights, drainage',
              Icons.business,
              Colors.green,
            ),
            _buildDepartmentCard(
              context,
              'Health Department',
              'Hospital facilities, medical services',
              Icons.local_hospital,
              Colors.red,
            ),
            _buildDepartmentCard(
              context,
              'Vigilance Department',
              'Corruption, bribery, misconduct',
              Icons.security,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(
          description,
          style: const TextStyle(fontSize: 12),
        ),
        dense: true,
      ),
    );
  }
}