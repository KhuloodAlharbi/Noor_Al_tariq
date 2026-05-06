// =============================================================================
// FILE: lib/app_settings_provider.dart
// DESCRIPTION: Global app settings - Language (FR2.2) & Font Size (FR2.6)
//              Uses easy_localization for language switching.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettingsProvider extends ChangeNotifier {
  double _fontSize = 14.0;

  static const double minFontSize = 12.0;
  static const double maxFontSize = 22.0;

  double get fontSize => _fontSize;

  // ---------------------------------------------------------------------------
  // Load font size from Firestore (language is handled by easy_localization)
  // ---------------------------------------------------------------------------
  Future<void> loadFromFirestore(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        // Font size
        _fontSize = (data['fontSize'] as num?)?.toDouble() ?? 14.0;

        // Language — delegate to easy_localization
        final lang = data['language'] as String? ?? 'English';

        Locale locale;
        if (lang == 'Arabic') {
          locale = const Locale('ar');
        } else if (lang == 'Urdu') {
          locale = const Locale('ur');
        } else {
          locale = const Locale('en');
        }

        if (context.locale != locale) {
          await context.setLocale(locale);
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Font size
  // ---------------------------------------------------------------------------
  Future<void> setFontSize(double size) async {
    final clamped = size.clamp(minFontSize, maxFontSize);
    if (_fontSize == clamped) return;
    _fontSize = clamped;
    notifyListeners();
    await _persistFontSize(clamped);
  }

  void increaseFontSize() => setFontSize(_fontSize + 2.0);
  void decreaseFontSize() => setFontSize(_fontSize - 2.0);

  Future<void> _persistFontSize(double size) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fontSize': size});
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Language — save to Firestore then apply via easy_localization
  // ---------------------------------------------------------------------------
Future<void> setLanguage(String lang) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'language': lang});
  } catch (_) {}
}
  // ---------------------------------------------------------------------------
  // Reset on logout
  // ---------------------------------------------------------------------------
  void reset(BuildContext context) {
    _fontSize = 14.0;
    context.resetLocale();
    notifyListeners();
  }
}
