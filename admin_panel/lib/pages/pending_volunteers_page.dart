// =============================================================================
// FILE: admin_panel/lib/pages/pending_volunteers_page.dart
// DESCRIPTION: Displays pending volunteer applications with approve/decline
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PendingVolunteersPage extends StatefulWidget {
  const PendingVolunteersPage({super.key});

  @override
  State<PendingVolunteersPage> createState() => _PendingVolunteersPageState();
}

class _PendingVolunteersPageState extends State<PendingVolunteersPage> {
  String? _selectedApplicationId;
  Map<String, dynamic>? _selectedApplicationData;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        // Left side - List of applications
        Expanded(
          flex: 2,
          child: Container(
            color: const Color(0xFF050509),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pending Volunteer Requests',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review and process volunteer applications',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Applications list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('volunteer_applications')
                        .where('status', isEqualTo: 'pending')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: Colors.green.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'All caught up!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No pending volunteer requests',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final isSelected = _selectedApplicationId == doc.id;

                          return _ApplicationCard(
                            data: data,
                            isSelected: isSelected,
                            accent: accent,
                            onTap: () {
                              setState(() {
                                _selectedApplicationId = doc.id;
                                _selectedApplicationData = data;
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right side - Application details
        Expanded(
          flex: 3,
          child: Container(
            color: const Color(0xFF0A0A10),
            child: _selectedApplicationData == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 64,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select an application to view details',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _ApplicationDetails(
                    applicationId: _selectedApplicationId!,
                    data: _selectedApplicationData!,
                    accent: accent,
                    onActionComplete: () {
                      setState(() {
                        _selectedApplicationId = null;
                        _selectedApplicationData = null;
                      });
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  const _ApplicationCard({
    required this.data,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['fullName'] as String? ?? 'Unknown';
    final email = data['email'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat('MMM d, yyyy').format(createdAt.toDate())
        : 'Unknown date';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? accent.withOpacity(0.15)
            : const Color(0xFF17171F),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? accent : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: accent.withOpacity(0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplicationDetails extends StatefulWidget {
  final String applicationId;
  final Map<String, dynamic> data;
  final Color accent;
  final VoidCallback onActionComplete;

  const _ApplicationDetails({
    required this.applicationId,
    required this.data,
    required this.accent,
    required this.onActionComplete,
  });

  @override
  State<_ApplicationDetails> createState() => _ApplicationDetailsState();
}

class _ApplicationDetailsState extends State<_ApplicationDetails> {
  bool _isProcessing = false;
  final _declineReasonController = TextEditingController();

  @override
  void dispose() {
    _declineReasonController.dispose();
    super.dispose();
  }

  Future<void> _approveApplication() async {
    setState(() => _isProcessing = true);

    try {
      final uid = widget.data['uid'] as String?;
      if (uid == null) throw Exception('User ID not found');

      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // Update volunteer_applications document
      final appRef = firestore.collection('volunteer_applications').doc(uid);
      batch.update(appRef, {
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminUid,
      });

      // Update users document
      final userRef = firestore.collection('users').doc(uid);
      batch.update(userRef, {
        'isVolunteer': true,
        'volunteerApplicationStatus': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Volunteer approved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onActionComplete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _declineApplication() async {
    // Show decline reason dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF17171F),
        title: const Text('Decline Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Optionally provide a reason for declining:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _declineReasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              _declineReasonController.text.trim(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Decline',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (reason == null) return; // User cancelled

    setState(() => _isProcessing = true);

    try {
      final uid = widget.data['uid'] as String?;
      if (uid == null) throw Exception('User ID not found');

      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // Update volunteer_applications document
      final appRef = firestore.collection('volunteer_applications').doc(uid);
      batch.update(appRef, {
        'status': 'declined',
        'declineReason': reason.isNotEmpty ? reason : null,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminUid,
      });

      // Update users document
      final userRef = firestore.collection('users').doc(uid);
      batch.update(userRef, {
        'volunteerApplicationStatus': 'declined',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application declined.'),
          backgroundColor: Colors.orange,
        ),
      );

      widget.onActionComplete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        _declineReasonController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final accent = widget.accent;

    final name = data['fullName'] as String? ?? 'Unknown';
    final email = data['email'] as String? ?? 'N/A';
    final phone = data['phone'] as String? ?? 'N/A';
    final age = data['age']?.toString() ?? 'N/A';
    final expertise = (data['expertiseAreas'] as List?)?.cast<String>() ?? [];
    final languages = (data['languages'] as List?)?.cast<String>() ?? [];
    final availability = data['availabilityStatus'] as String? ?? 'N/A';
    final motivation = data['motivation'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar and name
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: accent.withOpacity(0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        'Applied ${DateFormat('MMMM d, yyyy \'at\' h:mm a').format(createdAt.toDate())}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(color: Colors.white12),
          const SizedBox(height: 24),

          // Details sections
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailSection(
                      title: 'Contact Information',
                      icon: Icons.contact_mail_outlined,
                      accent: accent,
                      children: [
                        _DetailRow(label: 'Email', value: email),
                        _DetailRow(label: 'Phone', value: phone),
                        _DetailRow(label: 'Age', value: age),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _DetailSection(
                      title: 'Availability',
                      icon: Icons.schedule_outlined,
                      accent: accent,
                      children: [
                        _DetailRow(
                          label: 'Status',
                          value: availability.toUpperCase(),
                          valueColor: availability == 'available'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Right column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailSection(
                      title: 'Expertise Areas',
                      icon: Icons.work_outline,
                      accent: accent,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: expertise.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: accent.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                e.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _DetailSection(
                      title: 'Languages',
                      icon: Icons.language,
                      accent: accent,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: languages.map((l) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                l,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Motivation section
          if (motivation.isNotEmpty) ...[
            const SizedBox(height: 24),
            _DetailSection(
              title: 'Motivation',
              icon: Icons.edit_note,
              accent: accent,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    motivation,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 40),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _declineApplication,
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text(
                      'Decline',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _approveApplication,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isProcessing ? 'Processing...' : 'Approve Volunteer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
