import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'admin_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 1)); // Reduced delay for faster testing
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.loadAdminData();
    if (!mounted) return;

    if (authService.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
      return;
    }

    // Auto-login for testing phase
    bool success = await authService.login('admin@test.com', 'admin123');
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF10b981)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.admin_panel_settings, size: 100, color: Colors.white),
              SizedBox(height: 24),
              Text('Admin Dashboard', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 8),
              Text('System Analytics & Management', style: TextStyle(fontSize: 16, color: Colors.white70)),
              SizedBox(height: 48),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}