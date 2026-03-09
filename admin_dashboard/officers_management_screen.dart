import 'package:flutter/material.dart';

class OfficersManagementScreen extends StatelessWidget {
  const OfficersManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officers Management'),
        backgroundColor: const Color(0xFF2c3e50),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Officers Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DataTable(
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Department')),
                DataColumn(label: Text('Assigned Cases')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Action')),
              ],
              rows: [
                DataRow(cells: [
                  const DataCell(Text('#O001')),
                  const DataCell(Text('Officer Name')),
                  const DataCell(Text('Water Dept')),
                  const DataCell(Text('12')),
                  const DataCell(Text('Active')),
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
