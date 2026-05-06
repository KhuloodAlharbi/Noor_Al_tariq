// =============================================================================
// FILE: volunteer_application_page.dart
// DESCRIPTION: NEW - Volunteer application form (post-authentication)
// PURPOSE: Collects volunteer details AFTER user has authenticated
// CHANGES FROM volunteer_request_page.dart:
//   - Removed email field (uses authenticated user's email)
//   - Added age field
//   - Added motivation/bio field
//   - Saves to volunteer_applications/{uid} instead of volunteer_requests
//   - Navigates to PendingApprovalPage after submission
//   - Uses authenticated user's UID as document ID
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'app_settings_provider.dart';
import 'pending_approval_page.dart';

class VolunteerApplicationPage extends StatefulWidget {
  const VolunteerApplicationPage({super.key});

  @override
  State<VolunteerApplicationPage> createState() =>
      _VolunteerApplicationPageState();
}

class _VolunteerApplicationPageState extends State<VolunteerApplicationPage> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _motivationController = TextEditingController();

  String _availability = 'available';

  // Expertise selections
  final Map<String, bool> _expertise = {
    'medical': false,
    'navigation': false,
    'translation': false,
    'general_guidance': false,
    'emergency_response': false,
    'crowd_management': false,
  };

  // Language selections
  final Map<String, bool> _languages = {
    'arabic': false,
    'english': false,
    'urdu': false,
    'turkish': false,
    'indonesian': false,
    'malay': false,
    'french': false,
    'other': false,
  };

  bool _isSubmitting = false;
  String? _error;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  // Load user data from auth and Firestore
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    _userEmail = user.email;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final name = data?['name'] as String?;
        if (name != null && name.isNotEmpty) {
          _fullNameController.text = name;
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }

    if (mounted) setState(() {});
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedExpertise = _expertise.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final selectedLanguages = _languages.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedExpertise.isEmpty) {
      setState(() {
        _error = 'errors.expertise_required'.tr();
      });
      return;
    }

    if (selectedLanguages.isEmpty) {
      setState(() {
        _error = 'errors.language_required'.tr();
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'errors.not_logged_in'.tr();
      });
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
        _error = null;
      });

      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;

      // Save application to volunteer_applications/{uid}
      await firestore.collection('volunteer_applications').doc(uid).set({
        'uid': uid,
        'fullName': _fullNameController.text.trim(),
        'email': _userEmail ?? user.email,
        'phone': _phoneController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'expertiseAreas': selectedExpertise,
        'languages': selectedLanguages,
        'availabilityStatus': _availability,
        'motivation': _motivationController.text.trim(),
        'status': 'pending',// pending | approved | declined
        'createdAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'declineReason': null,
      });

      // Update user document to indicate application submitted
      await firestore.collection('users').doc(uid).update({
        'hasVolunteerApplication': true,
        'volunteerApplicationStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('volunteer_application.submitted'.tr()),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to pending approval page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PendingApprovalPage(status: 'pending'),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'errors.submit_application'.tr(namedArgs: {'error': '$e'});
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _expertiseLabel(String key) {
    return 'volunteer_application.expertise.$key'.tr();
  }

  String _languageLabel(String key) {
    return 'languages.$key'.tr();
  }

  String _availabilityLabel(String value) {
    return 'volunteer_application.availability_$value'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;

    final accent = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).colorScheme.surface;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.7)
        : Colors.black.withOpacity(0.6);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'volunteer_application.title'.tr(),
          style: TextStyle(fontSize: fs + 2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () async {
            final shouldLeave = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: cardColor,
                title: Text(
                  'volunteer_application.cancel_title'.tr(),
                  style: TextStyle(fontSize: fs + 2),
                ),
                content: Text(
                  'volunteer_application.cancel_body'.tr(),
                  style: TextStyle(fontSize: fs),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'common.stay'.tr(),
                      style: TextStyle(fontSize: fs),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      'common.leave'.tr(),
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: fs,
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (shouldLeave == true && mounted) {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.volunteer_activism_rounded,
                          size: 48,
                          color: accent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'volunteer_application.header_title'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: fs + 6,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'volunteer_application.header_subtitle'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: fs,
                          ),
                        ),
                        if (_userEmail != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: fs + 2,
                                  color: accent,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _userEmail!,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: fs - 1,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Form card
                Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: fs + 6,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: fs - 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Section: Personal Information
                          _SectionHeader(
                            icon: Icons.person_outline,
                            title: 'volunteer_application.personal_section'.tr(),
                            accent: accent,
                            fs: fs,
                          ),
                          const SizedBox(height: 12),
                          // Full Name
                          TextFormField(
                            controller: _fullNameController,
                            style: TextStyle(fontSize: fs),
                            decoration: InputDecoration(
                              labelText: 'volunteer_application.full_name'.tr(),
                              prefixIcon: const Icon(Icons.person),
                              hintText:
                                  'volunteer_application.full_name_hint'.tr(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'common.required'.tr()
                                : null,
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(fontSize: fs),
                                  decoration: InputDecoration(
                                    labelText:
                                        'volunteer_application.phone'.tr(),
                                    prefixIcon: const Icon(Icons.phone),
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'common.required'.tr()
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(fontSize: fs),
                                  decoration: InputDecoration(
                                    labelText:
                                        'volunteer_application.age'.tr(),
                                    prefixIcon:
                                        const Icon(Icons.cake_outlined),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'common.required'.tr();
                                    }
                                    final age = int.tryParse(v.trim());
                                    if (age == null || age < 18 || age > 100) {
                                      return 'errors.age_range'.tr();
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          _SectionHeader(
                            icon: Icons.work_outline,
                            title:
                                'volunteer_application.expertise_section'.tr(),
                            accent: accent,
                            fs: fs,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'common.select_all'.tr(),
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: fs - 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _expertise.keys.map((key) {
                              return FilterChip(
                                label: Text(
                                  _expertiseLabel(key),
                                  style: TextStyle(fontSize: fs - 1),
                                ),
                                selected: _expertise[key]!,
                                selectedColor: accent.withOpacity(0.3),
                                checkmarkColor: accent,
                                onSelected: (value) {
                                  setState(() {
                                    _expertise[key] = value;
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 24),

                          _SectionHeader(
                            icon: Icons.language,
                            title:
                                'volunteer_application.languages_section'.tr(),
                            accent: accent,
                            fs: fs,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'common.select_all'.tr(),
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: fs - 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _languages.keys.map((key) {
                              return FilterChip(
                                label: Text(
                                  _languageLabel(key),
                                  style: TextStyle(fontSize: fs - 1),
                                ),
                                selected: _languages[key]!,
                                selectedColor: accent.withOpacity(0.3),
                                checkmarkColor: accent,
                                onSelected: (value) {
                                  setState(() {
                                    _languages[key] = value;
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 24),

                          _SectionHeader(
                            icon: Icons.schedule,
                            title:
                                'volunteer_application.availability_section'
                                    .tr(),
                            accent: accent,
                            fs: fs,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _availability,
                            style: TextStyle(
                              fontSize: fs,
                              color: onSurface,
                            ),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.event_available),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'available',
                                child: Text(_availabilityLabel('available')),
                              ),
                              DropdownMenuItem(
                                value: 'busy',
                                child: Text(_availabilityLabel('busy')),
                              ),
                              DropdownMenuItem(
                                value: 'offline',
                                child: Text(_availabilityLabel('offline')),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _availability = value;
                                });
                              }
                            },
                          ),

                          const SizedBox(height: 24),

                          _SectionHeader(
                            icon: Icons.edit_note,
                            title:
                                'volunteer_application.motivation_section'
                                    .tr(),
                            accent: accent,
                            fs: fs,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _motivationController,
                            maxLines: 4,
                            style: TextStyle(fontSize: fs),
                            decoration: InputDecoration(
                              hintText:
                                  'volunteer_application.motivation_hint'.tr(),
                              alignLabelWithHint: true,
                            ),
                          ),

                          const SizedBox(height: 32),

                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed:
                                  _isSubmitting ? null : _submitApplication,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.send_rounded),
                                        const SizedBox(width: 8),
                                        Text(
                                          'volunteer_application.submit'.tr(),
                                          style: TextStyle(
                                            fontSize: fs,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final double fs;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.accent,
    required this.fs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: accent, size: fs + 4),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
