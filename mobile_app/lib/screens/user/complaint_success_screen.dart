import 'package:flutter/material.dart';

class ComplaintSuccessScreen extends StatelessWidget {
  const ComplaintSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Success')),
      body: const Center(child: Text('Complaint Submitted Successfully')),
    );
  }
}
