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

// ── Noor Al-Tariq colour palette (matches the mobile app) ──────────────────
class AppColors {
  static const background   = Color(0xFFF5F0E8); // warm cream
  static const surface      = Color(0xFFFFFFFF); // white cards
  static const sidebar      = Color(0xFFFFFFFF); // white sidebar
  static const accent       = Color(0xFFF6B645); // golden amber
  static const accentDark   = Color(0xFFD9961A); // darker amber
  static const textPrimary  = Color(0xFF1A1A2E); // near-black
  static const textSecondary= Color(0xFF6B7280); // muted grey
  static const divider      = Color(0xFFE8E0D0); // warm divider
  static const cardBorder   = Color(0xFFEDE8DC); // subtle border
}

class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Noor Al-Tariq Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.accent,
        colorScheme: const ColorScheme.light(
          primary: AppColors.accent,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          onPrimary: Colors.white,
        ),
        cardColor: AppColors.surface,
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
        ),
        dividerColor: AppColors.divider,
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.textPrimary),
          bodySmall: TextStyle(color: AppColors.textSecondary),
        ),
        dataTableTheme: const DataTableThemeData(
          headingTextStyle: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          dataTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 14),
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
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
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