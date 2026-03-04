import 'package:flutter/material.dart';
import 'complaint_form_screen.dart';

class DepartmentSelectionScreen extends StatelessWidget {
  const DepartmentSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final departments = [
      {
        'name': 'Power Department',
        'description': 'Electricity issues, power cuts, transformer problems',
        'icon': Icons.electrical_services,
        'color': const Color(0xFFFFA726),
        'gradient': [const Color(0xFFFFA726), const Color(0xFFFF9800)],
      },
      {
        'name': 'Water Department',
        'description': 'Water supply, leakage, pipeline, quality issues',
        'icon': Icons.water_drop,
        'color': const Color(0xFF42A5F5),
        'gradient': [const Color(0xFF42A5F5), const Color(0xFF2196F3)],
      },
      {
        'name': 'Municipal Services',
        'description': 'Sanitation, roads, street lights, drainage',
        'icon': Icons.business,
        'color': const Color(0xFF66BB6A),
        'gradient': [const Color(0xFF66BB6A), const Color(0xFF4CAF50)],
      },
      {
        'name': 'Health Department',
        'description': 'Hospital facilities, medical services, ambulance',
        'icon': Icons.local_hospital,
        'color': const Color(0xFFEF5350),
        'gradient': [const Color(0xFFEF5350), const Color(0xFFF44336)],
      },
      {
        'name': 'Vigilance Department',
        'description': 'Corruption, bribery, misconduct, illegal activities',
        'icon': Icons.security,
        'color': const Color(0xFFFF7043),
        'gradient': [const Color(0xFFFF7043), const Color(0xFFFF5722)],
      },
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF667eea).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            elevation: 2,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Department',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose the relevant department for your complaint',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Department Cards
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: departments.length,
                  itemBuilder: (context, index) {
                    final dept = departments[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildDepartmentCard(
                        context,
                        dept['name'] as String,
                        dept['description'] as String,
                        dept['icon'] as IconData,
                        dept['gradient'] as List<Color>,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(
    BuildContext context,
    String name,
    String description,
    IconData icon,
    List<Color> gradient,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ComplaintFormScreen(department: name),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon with gradient
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 20),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: gradient[0].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: gradient[0],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}