// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:illumi_home/screens/dashboard_screen.dart';
import 'package:illumi_home/screens/login_screen.dart'; 
import 'package:illumi_home/screens/splash_screen.dart';
import 'package:illumi_home/screens/room_detail_screen.dart';
import 'package:illumi_home/screens/email_login_screen.dart';
import 'package:illumi_home/screens/email_signup_screen.dart';
import 'package:illumi_home/screens/admin_login_screen.dart';
import 'package:illumi_home/screens/admin_logs_screen.dart';
import 'package:illumi_home/screens/help_support_screen.dart';
import 'package:illumi_home/firebase_options.dart';
import 'package:illumi_home/models/room.dart';
import 'package:illumi_home/services/theme_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'IllumiHome',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
        colorSchemeSeed: Colors.amber,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/email_login': (context) => const EmailLoginScreen(),
        '/email_signup': (context) => const EmailSignupScreen(),
        '/admin_login': (context) => const AdminLoginScreen(),
        '/admin_logs': (context) => const AdminLogsScreen(),
        '/help': (context) => const HelpSupportScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle dynamic routes like /room/:id
        if (settings.name?.startsWith('/room/') ?? false) {
          final roomId = settings.name!.split('/').last;
          
          // If room data is passed as an argument, use it
          if (settings.arguments is Room) {
            final room = settings.arguments as Room;
            return MaterialPageRoute(
              builder: (context) => RoomDetailScreen(room: room),
            );
          }
          
          // Otherwise, show a loading screen (in a real app, you'd fetch the room by ID)
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Loading...')),
              body: const Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return null;
      },
    );
  }
}