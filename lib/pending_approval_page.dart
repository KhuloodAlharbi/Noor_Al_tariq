// =============================================================================
// FILE: pending_approval_page.dart
// DESCRIPTION: NEW - Shows volunteer their application status
// PURPOSE: Displays pending/declined status with appropriate messaging
// FEATURES:
//   - Real-time status updates via Firestore stream
//   - Shows decline reason if applicable
//   - Option to reapply after decline
//   - Auto-redirects to VolunteerHomePage on approval
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'app_settings_provider.dart';
import 'role_selection_page.dart';
import 'home_pages.dart';
import 'volunteer_application_page.dart';

class PendingApprovalPage extends StatefulWidget {
  final String status;
  final String? declineReason;

  const PendingApprovalPage({
    super.key,
    required this.status,
    this.declineReason,
  });

  @override
  State<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends State<PendingApprovalPage> {
  StreamSubscription? _statusSubscription;
  String _currentStatus = 'pending';
  String? _declineReason;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _declineReason = widget.declineReason;
    _listenToStatusChanges();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  // Listen for real-time status updates
  void _listenToStatusChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _statusSubscription = FirebaseFirestore.instance
        .collection('volunteer_applications')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final newStatus = data['status'];

      if (newStatus == 'approved') {
        // Application approved! Update user doc and redirect
        _handleApproval(user.uid);
      } else if (newStatus == 'declined') {
        setState(() {
          _currentStatus = 'declined';
          _declineReason = data['declineReason'];
        });
      }
    });
  }

  Future<void> _handleApproval(String uid) async {
    // Update user document to mark as approved volunteer
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isVolunteer': true,
      'volunteerApplicationStatus': 'approved',
    });

    if (!mounted) return;
    // Show success message and redirect
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('pending_approval.approved_snackbar'.tr()),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const VolunteerHomePage()),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
    );
  }

  Future<void> _reapply() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Delete the old application
    await FirebaseFirestore.instance
        .collection('volunteer_applications')
        .doc(user.uid)
        .delete();

    if (!mounted) return;

    // Go to application form
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const VolunteerApplicationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;
    final accent = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'pending_approval.title'.tr(),
          style: TextStyle(fontSize: fs + 2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Center(
        child: _currentStatus == 'pending'
            ? _pendingUI(fs, accent, cardColor)
            : _declinedUI(fs, accent, cardColor),
      ),
    );
  }

  Widget _pendingUI(double fs, Color accent, Color cardColor) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, size: fs + 40, color: accent),
            const SizedBox(height: 16),
            Text(
              'pending_approval.pending_title'.tr(),
              style: TextStyle(fontSize: fs + 4, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'pending_approval.pending_body'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fs),
            ),
            const SizedBox(height: 16),
            Text(
              'pending_approval.review_time'.tr(),
              style: TextStyle(fontSize: fs - 1),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signOut,
              child: Text(
                'common.sign_out'.tr(),
                style: TextStyle(fontSize: fs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _declinedUI(double fs, Color accent, Color cardColor) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, size: fs + 40, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'pending_approval.declined_title'.tr(),
              style: TextStyle(fontSize: fs + 4, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'pending_approval.declined_body'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fs),
            ),
            if (_declineReason != null) ...[
              const SizedBox(height: 12),
              Text(
                '${'pending_approval.decline_reason_label'.tr()} $_declineReason',
                style: TextStyle(fontSize: fs - 1, color: Colors.red),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _reapply,
              child: Text(
                'pending_approval.reapply'.tr(),
                style: TextStyle(fontSize: fs),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _signOut,
              child: Text(
                'common.sign_out'.tr(),
                style: TextStyle(fontSize: fs),
              ),
            ),
          ],
        ),
      ),
    );
  }
}