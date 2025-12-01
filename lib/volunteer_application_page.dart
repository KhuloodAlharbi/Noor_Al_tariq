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
    'Arabic': false,
    'English': false,
    'Urdu': false,
    'Turkish': false,
    'Indonesian': false,
    'Malay': false,
    'French': false,
    'Other': false,
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
      // User not authenticated - this shouldn't happen, but handle it
      Navigator.pop(context);
      return;
    }

    _userEmail = user.email;

    // Try to get existing name from Firestore
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

    if (mounted) setState(() {});
  }

  // Submit the volunteer application
  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate selections
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
        _error = 'Please select at least one area of expertise.';
      });
      return;
    }

    if (selectedLanguages.isEmpty) {
      setState(() {
        _error = 'Please select at least one language.';
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'You must be logged in to submit an application.';
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
        'status': 'pending', // pending | approved | declined
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
        const SnackBar(
          content: Text(
            'Your application has been submitted successfully!',
          ),
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
        _error = 'Failed to submit application: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).colorScheme.surface;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Volunteer Application'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () async {
            // Sign out and go back since they're canceling the application
            final shouldLeave = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: cardColor,
                title: const Text('Cancel Application?'),
                content: const Text(
                  'If you leave now, you\'ll need to complete this application later to access volunteer features.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Stay'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Leave',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (shouldLeave == true && mounted) {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
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
                // Header card
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
                        const Text(
                          'Complete Your Application',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please provide the following information to apply as a volunteer. Your application will be reviewed by our admin team.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
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
                                  size: 16,
                                  color: accent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _userEmail!,
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w500,
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
                          // Error message
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
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(color: Colors.red),
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
                            title: 'Personal Information',
                            accent: accent,
                          ),
                          const SizedBox(height: 12),

                          // Full Name
                          TextFormField(
                            controller: _fullNameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person),
                              hintText: 'Enter your full name',
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),

                          // Phone and Age in a row
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number',
                                    prefixIcon: Icon(Icons.phone),
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Age',
                                    prefixIcon: Icon(Icons.cake_outlined),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    final age = int.tryParse(v.trim());
                                    if (age == null || age < 18 || age > 100) {
                                      return '18-100';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Section: Expertise Areas
                          _SectionHeader(
                            icon: Icons.work_outline,
                            title: 'Expertise Areas',
                            accent: accent,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select all that apply',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _expertise.keys.map((key) {
                              return FilterChip(
                                label: Text(_formatExpertise(key)),
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

                          // Section: Languages
                          _SectionHeader(
                            icon: Icons.language,
                            title: 'Languages Spoken',
                            accent: accent,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select all that apply',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _languages.keys.map((key) {
                              return FilterChip(
                                label: Text(key),
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

                          // Section: Availability
                          _SectionHeader(
                            icon: Icons.schedule,
                            title: 'Availability Status',
                            accent: accent,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _availability,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.event_available),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'available',
                                child: Text('Available'),
                              ),
                              DropdownMenuItem(
                                value: 'busy',
                                child: Text('Busy'),
                              ),
                              DropdownMenuItem(
                                value: 'offline',
                                child: Text('Offline'),
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

                          // Section: Motivation
                          _SectionHeader(
                            icon: Icons.edit_note,
                            title: 'Why do you want to volunteer?',
                            accent: accent,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _motivationController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText:
                                  'Tell us about your motivation and any relevant experience...',
                              alignLabelWithHint: true,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Submit button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitApplication,
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
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.send_rounded),
                                        SizedBox(width: 8),
                                        Text(
                                          'Submit Application',
                                          style: TextStyle(
                                            fontSize: 16,
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

  String _formatExpertise(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

// Section header widget
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
