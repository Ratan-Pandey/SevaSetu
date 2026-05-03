import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/socket_service.dart';
import 'screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiService()),
        Provider(create: (_) => SocketService(serverUrl: ApiService.baseUrl)),
        ChangeNotifierProxyProvider<SocketService, AuthService>(
          create: (_) => AuthService(),
          update: (_, socket, auth) => auth!..setSocketService(socket),
        ),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'SevaSetu',
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF667eea)),
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        home: const SplashScreen(),
      ),
    );
  }
}