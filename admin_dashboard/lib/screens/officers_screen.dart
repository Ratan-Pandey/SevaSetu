import 'package:flutter/material.dart';

class OfficersScreen extends StatelessWidget {
  const OfficersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final officers = List.generate(8, (i) => {
      'id': i + 1,
      'name': 'Officer ${i + 1}',
      'email': 'officer${i + 1}@gov.in',
      'department': ['Power', 'Water', 'Municipal', 'Health', 'Vigilance'][i % 5],
      'assigned': (i * 3) + 5,
      'resolved': (i * 2) + 3,
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Officers'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: officers.length,
        itemBuilder: (context, index) {
          final officer = officers[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF059669),
                      child: Text(
                        officer['name'].toString()[8],
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(officer['name'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(officer['email'].toString(), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3b82f6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    officer['department'].toString(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3b82f6)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('Assigned', officer['assigned'].toString(), Colors.orange),
                    ),
                    Expanded(
                      child: _buildStatItem('Resolved', officer['resolved'].toString(), Colors.green),
                    ),
                    Expanded(
                      child: _buildStatItem('Rate', '${((officer['resolved'] as int) / (officer['assigned'] as int) * 100).round()}%', const Color(0xFF059669)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}