// =============================================================================
// FILE: admin_panel/lib/pages/approved_volunteers_page.dart
// DESCRIPTION: Displays approved volunteers – light / warm theme
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../main.dart'; // AppColors

class ApprovedVolunteersPage extends StatelessWidget {
  const ApprovedVolunteersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Approved Volunteers',
                    style: TextStyle(
                      fontSize:   26,
                      fontWeight: FontWeight.bold,
                      color:      AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Active volunteers in the system',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('volunteer_applications')
                    .where('status', isEqualTo: 'approved')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:        const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$count Active',
                          style: const TextStyle(
                            color:      Color(0xFF059669),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Data table ──────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color:        AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: AppColors.cardBorder),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('volunteer_applications')
                  .where('status', isEqualTo: 'approved')
                  .orderBy('reviewedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(64),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size:  64,
                            color: AppColors.textSecondary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No approved volunteers yet',
                            style: TextStyle(
                              color:    AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight:  52,
                    dataRowMinHeight:  60,
                    dataRowMaxHeight:  60,
                    headingRowColor:   WidgetStateProperty.all(AppColors.background),
                    dividerThickness:  1,
                    columns: const [
                      DataColumn(label: Text('Volunteer')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Expertise')),
                      DataColumn(label: Text('Languages')),
                      DataColumn(label: Text('Approved On')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: docs.map((doc) {
                      final data      = doc.data() as Map<String, dynamic>;
                      final name      = data['fullName'] as String? ?? 'Unknown';
                      final email     = data['email']    as String? ?? '';
                      final phone     = data['phone']    as String? ?? '';
                      final expertise = (data['expertiseAreas'] as List?)
                              ?.take(2)
                              .map((e) => e.toString().replaceAll('_', ' '))
                              .join(', ') ?? '';
                      final languages = (data['languages'] as List?)
                              ?.take(2)
                              .join(', ') ?? '';
                      final reviewedAt = data['reviewedAt'] as Timestamp?;
                      final dateStr = reviewedAt != null
                          ? DateFormat('MMM d, yyyy').format(reviewedAt.toDate())
                          : 'N/A';

                      return DataRow(cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius:          16,
                                backgroundColor: AppColors.accent.withOpacity(0.15),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color:      AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize:   12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color:      AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(email, style: const TextStyle(color: AppColors.textPrimary))),
                        DataCell(Text(phone, style: const TextStyle(color: AppColors.textPrimary))),
                        DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              expertise,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                        DataCell(Text(languages, style: const TextStyle(color: AppColors.textPrimary))),
                        DataCell(Text(dateStr,   style: const TextStyle(color: AppColors.textSecondary))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color:        const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                color:      Color(0xFF059669),
                                fontSize:   12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}