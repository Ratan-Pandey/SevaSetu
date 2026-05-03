import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/officer_dashboard.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const OfficerDashboardApp());
}

class OfficerDashboardApp extends StatelessWidget {
  const OfficerDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => ApiService()),
        Provider(create: (_) => SocketService(serverUrl: 'http://127.0.0.1:8000')),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Officer Dashboard',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1e3a8a),
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: Color(0xFF1e3a8a),
            foregroundColor: Colors.white,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1e3a8a), width: 2),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    // Disabled auto-login as per request
    // final authService = Provider.of<AuthService>(context, listen: false);
    // await authService.loadOfficerData();
    
    if (mounted) {
      setState(() { 
        _isLoggedIn = false; // authService.isAuthenticated; 
        _isLoading = false; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _isLoggedIn
        ? const OfficerDashboard()   // ✅ logged in
        : const LoginScreen();       // ✅ not logged in
  }
}