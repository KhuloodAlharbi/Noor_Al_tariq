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

import 'role_selection_page.dart';
import 'home_pages.dart';
import 'volunteer_application_page.dart';

class PendingApprovalPage extends StatefulWidget {
  final String status; // 'pending' or 'declined'
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
      final newStatus = data['status'] as String?;

      if (newStatus == 'approved') {
        // Application approved! Update user doc and redirect
        _handleApproval(user.uid);
      } else if (newStatus == 'declined' && _currentStatus != 'declined') {
        setState(() {
          _currentStatus = 'declined';
          _declineReason = data['declineReason'] as String?;
        });
      }
    });
  }

  Future<void> _handleApproval(String uid) async {
    // Update user document to mark as approved volunteer
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isVolunteer': true,
      'volunteerApplicationStatus': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    // Show success message and redirect
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Your volunteer application has been approved!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
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
    final accent = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Status'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: _currentStatus == 'pending'
                ? _buildPendingContent(accent, cardColor)
                : _buildDeclinedContent(accent, cardColor),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingContent(Color accent, Color cardColor) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated waiting icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                size: 64,
                color: accent,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Application Pending',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'Your volunteer application has been submitted successfully and is currently under review.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),

            // Status info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accent.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: accent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Typical review time: 24-48 hours',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: accent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This page will automatically update when your application is reviewed.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // What happens next
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What happens next?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStep('1', 'Admin reviews your application'),
                  const SizedBox(height: 8),
                  _buildStep('2', 'You\'ll be notified of the decision'),
                  const SizedBox(height: 8),
                  _buildStep('3', 'If approved, you\'ll get full volunteer access'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Sign out button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeclinedContent(Color accent, Color cardColor) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Declined icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_outlined,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Application Declined',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'Unfortunately, your volunteer application was not approved at this time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15,
              ),
            ),

            // Decline reason if provided
            if (_declineReason != null && _declineReason!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Reason:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _declineReason!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Reapply button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _reapply,
                icon: const Icon(Icons.refresh),
                label: const Text('Submit New Application'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sign out button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
