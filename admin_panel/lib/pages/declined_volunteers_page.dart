// =============================================================================
// FILE: admin_panel/lib/pages/declined_volunteers_page.dart
// DESCRIPTION: Displays declined volunteer applications
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DeclinedVolunteersPage extends StatelessWidget {
  const DeclinedVolunteersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Declined Applications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Previously declined volunteer requests',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              // Stats badge
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('volunteer_applications')
                    .where('status', isEqualTo: 'declined')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cancel_outlined,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$count Declined',
                          style: const TextStyle(
                            color: Colors.red,
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

          // Data table
          Card(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('volunteer_applications')
                  .where('status', isEqualTo: 'declined')
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
                    child: Center(child: CircularProgressIndicator()),
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
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.green.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No declined applications',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
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
                    headingRowHeight: 56,
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 80,
                    columns: const [
                      DataColumn(label: Text('Applicant')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Applied On')),
                      DataColumn(label: Text('Declined On')),
                      DataColumn(label: Text('Reason')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['fullName'] as String? ?? 'Unknown';
                      final email = data['email'] as String? ?? '';
                      final createdAt = data['createdAt'] as Timestamp?;
                      final reviewedAt = data['reviewedAt'] as Timestamp?;
                      final declineReason = data['declineReason'] as String?;

                      final appliedDate = createdAt != null
                          ? DateFormat('MMM d, yyyy').format(createdAt.toDate())
                          : 'N/A';
                      final declinedDate = reviewedAt != null
                          ? DateFormat('MMM d, yyyy').format(reviewedAt.toDate())
                          : 'N/A';

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.red.withOpacity(0.2),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(email)),
                          DataCell(Text(appliedDate)),
                          DataCell(Text(declinedDate)),
                          DataCell(
                            Container(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                declineReason ?? 'No reason provided',
                                style: TextStyle(
                                  color: declineReason != null
                                      ? Colors.white70
                                      : Colors.white38,
                                  fontStyle: declineReason == null
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Declined',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
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
