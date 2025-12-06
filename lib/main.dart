// =============================================================================
// FILE: lib/main.dart
// DESCRIPTION: Main entry point for Noor Al-Tariq mobile app
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// =============================================================================
// IMPORTANT: After running "flutterfire configure", uncomment this line:
// =============================================================================
// import 'firebase_options.dart';

import 'role_selection_page.dart';
import 'home_pages.dart';
import 'volunteer_application_page.dart';
import 'pending_approval_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  
  await Firebase.initializeApp();
  // =============================================================================
  
  runApp(const NoorAlTariqApp());
}

class NoorAlTariqApp extends StatelessWidget {
  const NoorAlTariqApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF050509); // very dark
    const cardColor = Color(0xFF17171F); // dark grey
    const accent = Color(0xFFF6B645); // warm gold

    return MaterialApp(
      title: 'Noor Al-Tariq',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accent,
          surface: cardColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: accent, width: 1.2),
            foregroundColor: accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// =============================================================================
// AuthWrapper - Handles automatic routing based on auth state
// =============================================================================
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is not logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const RoleSelectionPage();
        }

        // User is logged in - determine where to route them
        return FutureBuilder<Widget>(
          future: _determineHomePage(snapshot.data!),
          builder: (context, homeSnapshot) {
            if (homeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading your profile...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (homeSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${homeSnapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return homeSnapshot.data ?? const RoleSelectionPage();
          },
        );
      },
    );
  }

  /// Determines which page to show based on user's role and volunteer status
  Future<Widget> _determineHomePage(User user) async {
    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;

    // Get user document
    final userDoc = await firestore.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      // User exists in Auth but not in Firestore - unusual state
      // Sign them out and let them re-register
      await FirebaseAuth.instance.signOut();
      return const RoleSelectionPage();
    }

    final userData = userDoc.data()!;
    final role = userData['role'] as String?;

    // HAJJ PERFORMER - go directly to home
    if (role == 'hajj_performer') {
      return const HajjHomePage();
    }

    // VOLUNTEER - check application status
    if (role == 'volunteer') {
      // Check if they have an approved volunteer application
      final isVolunteer = userData['isVolunteer'] as bool? ?? false;

      if (isVolunteer) {
        // Approved volunteer - go to volunteer home
        return const VolunteerHomePage();
      }

      // Check for existing application
      final appDoc = await firestore
          .collection('volunteer_applications')
          .doc(uid)
          .get();

      if (!appDoc.exists) {
        // No application yet - redirect to application form
        return const VolunteerApplicationPage();
      }

      final appData = appDoc.data()!;
      final status = appData['status'] as String?;

      switch (status) {
        case 'approved':
          // This shouldn't happen if isVolunteer is properly set, but handle it
          await firestore.collection('users').doc(uid).update({
            'isVolunteer': true,
          });
          return const VolunteerHomePage();

        case 'declined':
          // Show declined page with option to reapply
          return PendingApprovalPage(
            status: 'declined',
            declineReason: appData['declineReason'] as String?,
          );

        case 'pending':
        default:
          // Show pending page
          return const PendingApprovalPage(status: 'pending');
      }
    }

    // Unknown role - go to role selection
    return const RoleSelectionPage();
  }
}
