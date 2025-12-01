import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDoev2MUQabMTBFYH4M9n9s7sTJEcISARA",
      authDomain: "noor-al-tariq-fdc14.firebaseapp.com",
      projectId: "noor-al-tariq-fdc14",
      storageBucket: "noor-al-tariq-fdc14.firebasestorage.app",
      messagingSenderId: "722364756276",
      appId: "1:722364756276:web:c5fb13f6f1c69e7e213561",
    ),
  );

  runApp(const AdminPanelApp());
}

class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noor Al-Tariq Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050509),
        primaryColor: const Color(0xFFF6B645),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF6B645),
          secondary: Color(0xFFF6B645),
          surface: Color(0xFF17171F),
        ),
        cardColor: const Color(0xFF17171F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF17171F),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF6B645),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D0D14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const AdminLoginPage();
        }

        return const DashboardPage();
      },
    );
  }
}
