import 'package:flutter/material.dart';

class DepartmentSelectionScreen extends StatelessWidget {
  const DepartmentSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Department')),
      body: const Center(child: Text('Department Selection Screen')),
    );
  }
}
