import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_login_page.dart';
import 'admin_control_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safe Firebase Initialization for Project 793207191715 (global-ai-train-tracker)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyC8PteupdXqGNNfPYkEYVGB5WwiueRMDOg',
          appId: '1:793207191715:android:a7f7e788220ebb3c26a716',
          messagingSenderId: '793207191715',
          projectId: 'global-ai-train-tracker',
          storageBucket: 'global-ai-train-tracker.firebasestorage.app',
          databaseURL:
              'https://global-ai-train-tracker-default-rtdb.firebaseio.com',
        ),
      );
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  bool isAlreadyLoggedIn = false;
  try {
    isAlreadyLoggedIn = FirebaseAuth.instance.currentUser != null;
  } catch (_) {}

  runApp(
    GlobalAITrainTrackerAdminApp(isLoggedIn: isAlreadyLoggedIn),
  );
}

class GlobalAITrainTrackerAdminApp extends StatelessWidget {
  final bool isLoggedIn;

  const GlobalAITrainTrackerAdminApp({
    super.key,
    this.isLoggedIn = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global AI Train Tracker - Admin System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF000B1E),
        useMaterial3: true,
      ),
      home: isLoggedIn
          ? const AdminControlDashboard()
          : const AdminLoginPage(),
      routes: {
        '/login': (context) => const AdminLoginPage(),
        '/dashboard': (context) => const AdminControlDashboard(),
        '/admin_dashboard': (context) => const AdminControlDashboard(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const AdminLoginPage(),
      ),
    );
  }
}