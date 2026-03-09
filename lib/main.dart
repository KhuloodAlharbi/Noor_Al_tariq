// =============================================================================
// FILE: lib/main.dart
// DESCRIPTION: Main entry point for Noor Al-Tariq mobile app
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

// =============================================================================
// IMPORTANT: After running "flutterfire configure", uncomment this line:
// =============================================================================
// import 'firebase_options.dart';

import 'app_settings_provider.dart';
import 'role_selection_page.dart';
import 'home_pages.dart';
import 'volunteer_application_page.dart';
import 'pending_approval_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  
  await Firebase.initializeApp();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations', 
      fallbackLocale: const Locale('en'),
      child: ChangeNotifierProvider(
        create: (_) => AppSettingsProvider(),
        child: const NoorAlTariqApp(),
      ),
    ),
  );
}

class NoorAlTariqApp extends StatelessWidget {
  const NoorAlTariqApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to settings changes (Font Size)
    final settings = context.watch<AppSettingsProvider>();
    final isArabic = context.locale == const Locale('ar');

    const background = Color(0xFF050509);
    const cardColor  = Color(0xFF17171F);
    const accent     = Color(0xFFF6B645);

    return MaterialApp(
      title: 'app_name'.tr(),
      debugShowCheckedModeBanner: false,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        fontFamily: isArabic ? null : 'Roboto', 
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accent,
          surface: cardColor,
        ),
        
        // Apply dynamic font size to global text theme
        textTheme: _buildTextTheme(settings.fontSize),
        
        appBarTheme: AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: settings.fontSize + 6,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: TextStyle(
              fontWeight: FontWeight.w600, 
              fontSize: settings.fontSize + 2,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: accent, width: 1.5)),
          labelStyle: TextStyle(color: Colors.white70, fontSize: settings.fontSize),
          hintStyle: TextStyle(color: Colors.white38, fontSize: settings.fontSize),
        ),
      ),
      home: const AuthWrapper(),
    );
  }

  // Build text sizes based on the base font size selected
  TextTheme _buildTextTheme(double base) => TextTheme(
    displayLarge:   TextStyle(fontSize: base + 22, color: Colors.white),
    headlineMedium: TextStyle(fontSize: base + 8,  color: Colors.white, fontWeight: FontWeight.w600),
    titleLarge:     TextStyle(fontSize: base + 4,  color: Colors.white, fontWeight: FontWeight.w600),
    bodyLarge:      TextStyle(fontSize: base + 2,  color: Colors.white),
    bodyMedium:     TextStyle(fontSize: base,       color: Colors.white),
    bodySmall:      TextStyle(fontSize: base - 2,  color: Colors.white70),
    labelLarge:     TextStyle(fontSize: base + 2,  color: Colors.white, fontWeight: FontWeight.w600),
  );
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _settingsLoaded = false;

  // Load user settings (Language & Font Size) from Firestore upon login
  Future<void> _loadUserSettings(User user) async {
    if (_settingsLoaded) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && mounted) {
      final data = doc.data()!;
      
      // Update font size in app
      final fontSize = (data['fontSize'] as num?)?.toDouble() ?? 14.0;
      await context.read<AppSettingsProvider>().setFontSize(fontSize);

      // Update language in app
      final lang = data['language'] as String? ?? 'English';
      final locale = lang == 'Arabic' ? const Locale('ar') : const Locale('en');
      if (context.locale != locale) {
        await context.setLocale(locale);
      }
    }
    _settingsLoaded = true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || snapshot.data == null) {
          _settingsLoaded = false;
          return const RoleSelectionPage();
        }

        final user = snapshot.data!;

        // Load settings first then determine the home page
        return FutureBuilder<void>(
          future: _loadUserSettings(user),
          builder: (context, settingsSnapshot) {
            if (settingsSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            return FutureBuilder<Widget>(
              future: _determineHomePage(user),
              builder: (context, homeSnapshot) {
                if (homeSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return homeSnapshot.data ?? const RoleSelectionPage();
              },
            );
          },
        );
      },
    );
  }

  Future<Widget> _determineHomePage(User user) async {
    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;
    final userDoc = await firestore.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      await FirebaseAuth.instance.signOut();
      return const RoleSelectionPage();
    }

    final userData = userDoc.data()!;
    final role = userData['role'] as String?;

    if (role == 'hajj_performer') {
      return const HajjHomePage();
    }

    if (role == 'volunteer') {
      final isVolunteer = userData['isVolunteer'] as bool? ?? false;
      if (isVolunteer) return const VolunteerHomePage();

      final appDoc = await firestore.collection('volunteer_applications').doc(uid).get();
      if (!appDoc.exists) return const VolunteerApplicationPage();

      final status = appDoc.data()?['status'] as String?;
      switch (status) {
        case 'approved':
          await firestore.collection('users').doc(uid).update({'isVolunteer': true});
          return const VolunteerHomePage();
        case 'declined':
          return PendingApprovalPage(
            status: 'declined',
            declineReason: appDoc.data()?['declineReason'] as String?,
          );
        default:
          return const PendingApprovalPage(status: 'pending');
      }
    }
    return const RoleSelectionPage();
  }
}
