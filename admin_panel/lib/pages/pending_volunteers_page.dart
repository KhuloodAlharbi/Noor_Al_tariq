// =============================================================================
// FILE: admin_panel/lib/pages/pending_volunteers_page.dart
// DESCRIPTION: Pending volunteer applications – light / warm theme
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../main.dart'; // AppColors

class PendingVolunteersPage extends StatefulWidget {
  const PendingVolunteersPage({super.key});

  @override
  State<PendingVolunteersPage> createState() => _PendingVolunteersPageState();
}

class _PendingVolunteersPageState extends State<PendingVolunteersPage> {
  String?              _selectedApplicationId;
  Map<String, dynamic>? _selectedApplicationData;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left: list ───────────────────────────────────────────────────
        Expanded(
          flex: 2,
          child: Container(
            color:  AppColors.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Pending Volunteer Requests',
                        style: TextStyle(
                          fontSize:   24,
                          fontWeight: FontWeight.bold,
                          color:      AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Review and process volunteer applications',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
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
                          child: CircularProgressIndicator(color: AppColors.accent),
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
                                size:  64,
                                color: const Color(0xFF10B981).withOpacity(0.4),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'All caught up!',
                                style: TextStyle(
                                  fontSize:   20,
                                  fontWeight: FontWeight.w600,
                                  color:      AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'No pending volunteer requests',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding:    const EdgeInsets.symmetric(horizontal: 24),
                        itemCount:  docs.length,
                        itemBuilder: (context, index) {
                          final doc        = docs[index];
                          final data       = doc.data() as Map<String, dynamic>;
                          final isSelected = _selectedApplicationId == doc.id;

                          return _ApplicationCard(
                            data:       data,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedApplicationId   = doc.id;
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

        // ── Right: detail panel ──────────────────────────────────────────
        Expanded(
          flex: 3,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(left: BorderSide(color: AppColors.divider)),
            ),
            child: _selectedApplicationData == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size:  64,
                          color: AppColors.textSecondary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Select an application to view details',
                          style: TextStyle(
                            color:    AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _ApplicationDetails(
                    applicationId:  _selectedApplicationId!,
                    data:           _selectedApplicationData!,
                    onActionComplete: () {
                      setState(() {
                        _selectedApplicationId   = null;
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

// ── Application card ──────────────────────────────────────────────────────────
class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool                 isSelected;
  final VoidCallback         onTap;

  const _ApplicationCard({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name      = data['fullName']  as String? ?? 'Unknown';
    final email     = data['email']     as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr   = createdAt != null
        ? DateFormat('MMM d, yyyy').format(createdAt.toDate())
        : 'Unknown date';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color:        isSelected ? AppColors.accent.withOpacity(0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:        onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius:          24,
                  backgroundColor: AppColors.accent.withOpacity(0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color:      AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize:   18,
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
                          color:      AppColors.textPrimary,
                          fontSize:   15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          color:    AppColors.textSecondary,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFF59E0B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(
                          color:      Color(0xFFD97706),
                          fontSize:   11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color:    AppColors.textSecondary,
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

// ── Application details panel ─────────────────────────────────────────────────
class _ApplicationDetails extends StatefulWidget {
  final String               applicationId;
  final Map<String, dynamic> data;
  final VoidCallback         onActionComplete;

  const _ApplicationDetails({
    required this.applicationId,
    required this.data,
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

      final adminUid  = FirebaseAuth.instance.currentUser?.uid;
      final firestore = FirebaseFirestore.instance;
      final batch     = firestore.batch();

      batch.update(firestore.collection('volunteer_applications').doc(uid), {
        'status':     'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': adminUid,
      });
      batch.update(firestore.collection('users').doc(uid), {
        'isVolunteer':                  true,
        'volunteerApplicationStatus':   'approved',
        'updatedAt':                    FieldValue.serverTimestamp(),
      });
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Volunteer approved successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      widget.onActionComplete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _declineApplication() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Decline Application',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Optionally provide a reason for declining:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _declineReasonController,
              maxLines:   3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText:  'Reason (optional)',
                hintStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _declineReasonController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (reason == null) return;
    setState(() => _isProcessing = true);

    try {
      final uid = widget.data['uid'] as String?;
      if (uid == null) throw Exception('User ID not found');

      final adminUid  = FirebaseAuth.instance.currentUser?.uid;
      final firestore = FirebaseFirestore.instance;
      final batch     = firestore.batch();

      batch.update(firestore.collection('volunteer_applications').doc(uid), {
        'status':        'declined',
        'declineReason': reason.isNotEmpty ? reason : null,
        'reviewedAt':    FieldValue.serverTimestamp(),
        'reviewedBy':    adminUid,
      });
      batch.update(firestore.collection('users').doc(uid), {
        'volunteerApplicationStatus': 'declined',
        'updatedAt':                  FieldValue.serverTimestamp(),
      });
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Application declined.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      widget.onActionComplete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
    final data         = widget.data;
    final name         = data['fullName']         as String? ?? 'Unknown';
    final email        = data['email']            as String? ?? 'N/A';
    final phone        = data['phone']            as String? ?? 'N/A';
    final age          = data['age']?.toString()  ?? 'N/A';
    final expertise    = (data['expertiseAreas']  as List?)?.cast<String>() ?? [];
    final languages    = (data['languages']       as List?)?.cast<String>() ?? [];
    final availability = data['availabilityStatus'] as String? ?? 'N/A';
    final motivation   = data['motivation']       as String? ?? '';
    final createdAt    = data['createdAt']        as Timestamp?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius:          40,
                backgroundColor: AppColors.accent.withOpacity(0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color:      AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize:   32,
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
                        fontSize:   26,
                        fontWeight: FontWeight.bold,
                        color:      AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        'Applied ${DateFormat("MMMM d, yyyy 'at' h:mm a").format(createdAt.toDate())}',
                        style: const TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 24),

          // Detail columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailSection(
                      title: 'Contact Information',
                      icon:  Icons.contact_mail_outlined,
                      children: [
                        _DetailRow(label: 'Email', value: email),
                        _DetailRow(label: 'Phone', value: phone),
                        _DetailRow(label: 'Age',   value: age),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _DetailSection(
                      title: 'Availability',
                      icon:  Icons.schedule_outlined,
                      children: [
                        _DetailRow(
                          label:      'Status',
                          value:      availability.toUpperCase(),
                          valueColor: availability == 'available'
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailSection(
                      title: 'Expertise Areas',
                      icon:  Icons.work_outline,
                      children: [
                        Wrap(
                          spacing:    8,
                          runSpacing: 8,
                          children: expertise.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:        AppColors.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border:       Border.all(color: AppColors.accent.withOpacity(0.3)),
                              ),
                              child: Text(
                                e.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                  color:      AppColors.accent,
                                  fontSize:   12,
                                  fontWeight: FontWeight.w600,
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
                      icon:  Icons.language,
                      children: [
                        Wrap(
                          spacing:    8,
                          runSpacing: 8,
                          children: languages.map((l) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:        const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border:       Border.all(
                                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                l,
                                style: const TextStyle(
                                  color:      Color(0xFF2563EB),
                                  fontSize:   12,
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

          // Motivation
          if (motivation.isNotEmpty) ...[
            const SizedBox(height: 24),
            _DetailSection(
              title: 'Motivation',
              icon:  Icons.edit_note,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:        AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    motivation,
                    style: const TextStyle(
                      color:    AppColors.textPrimary,
                      fontSize: 14,
                      height:   1.5,
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
                    icon:  const Icon(Icons.close, color: Color(0xFFEF4444)),
                    label: const Text(
                      'Decline',
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side:        const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, color: Colors.white),
                    label: Text(
                      _isProcessing ? 'Processing...' : 'Approve Volunteer',
                      style: const TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize:   15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// ── Section heading ───────────────────────────────────────────────────────────
class _DetailSection extends StatelessWidget {
  final String       title;
  final IconData     icon;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w600,
                color:      AppColors.textPrimary,
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

// ── Label + value row ─────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String  label;
  final String  value;
  final Color?  valueColor;

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
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color:      valueColor ?? AppColors.textPrimary,
                fontSize:   14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}