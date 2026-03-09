import 'package:flutter/material.dart';

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints Management'),
        backgroundColor: const Color(0xFF2c3e50),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Complaints Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DataTable(
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Priority')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Action')),
              ],
              rows: [
                DataRow(cells: [
                  const DataCell(Text('#001')),
                  const DataCell(Text('Water Supply')),
                  const DataCell(Text('Pending')),
                  const DataCell(Text('High')),
                  const DataCell(Text('2024-01-15')),
                  DataCell(ElevatedButton(
                    onPressed: () {},
                    child: const Text('View'),
                  )),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
