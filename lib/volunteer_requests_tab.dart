// =============================================================================
// FILE: lib/volunteer_requests_tab.dart
// DESCRIPTION: Volunteer's incoming requests tab.
// CHANGES:
//   - _acceptRequest now creates the chat subcollection + stores chatId, then
//     immediately navigates the volunteer into ChatPage.
//   - Added "Open Chat" button on already-accepted requests.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'app_settings_provider.dart';
import 'chat_page.dart';

class VolunteerRequestsTab extends StatefulWidget {
  const VolunteerRequestsTab({super.key});

  @override
  State<VolunteerRequestsTab> createState() => _VolunteerRequestsTabState();
}

class _VolunteerRequestsTabState extends State<VolunteerRequestsTab> {
  List<String> _myExpertise = [];
  String? _volunteerName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVolunteerProfile();
  }

  Future<void> _loadVolunteerProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final appDoc = await FirebaseFirestore.instance
          .collection('volunteer_applications')
          .doc(user.uid)
          .get();

      if (appDoc.exists) {
        final data = appDoc.data()!;
        _myExpertise = List<String>.from(data['expertiseAreas'] ?? []);
        _volunteerName = data['fullName'] as String? ?? 'Volunteer';
      }

      if (_myExpertise.isEmpty) {
        _myExpertise = [
          'medical',
          'navigation',
          'translation',
          'general_guidance',
          'emergency_response',
          'crowd_management',
        ];
      }
    } catch (e) {
      debugPrint('Error loading volunteer profile: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ---------------------------------------------------------------------------
  // ACCEPT — creates chat + navigates into it
  // ---------------------------------------------------------------------------
  Future<void> _acceptRequest(DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if volunteer already has an active request
      final activeCheck = await FirebaseFirestore.instance
          .collection('helpRequests')
          .where('assignedVolunteer', isEqualTo: user.uid)
          .where('status', whereIn: ['accepted', 'in_progress'])
          .limit(1)
          .get();

      if (activeCheck.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('volunteer_requests.already_active'.tr()),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Transactional acceptance to prevent race conditions
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final fresh = await tx.get(doc.reference);
        final freshData = Map<String, dynamic>.from(fresh.data() as Map? ?? {});

        if (freshData['status'] != 'pending') {
          throw Exception('Request already taken');
        }

        tx.update(doc.reference, {
          'status': 'accepted',
          'assignedVolunteer': user.uid,
          'volunteerName': _volunteerName ?? 'Volunteer',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });
      // Post-transaction: add a system message so the chat isn't empty
      final messagesRef = FirebaseFirestore.instance
          .collection('helpRequests')
          .doc(doc.id)
          .collection('messages');

      await messagesRef.add({
        'senderId': 'system',
        'senderRole': 'system',
        'text': 'chat.accepted_message'.tr(
          namedArgs: {
            'name': _volunteerName ?? 'Volunteer',
          },
        ),
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (!mounted) return;
      // Open the chat immediately
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(requestId: doc.id, myRole: 'volunteer'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('errors.could_not_accept'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DECLINE — adds volunteer to declinedBy list
  // ---------------------------------------------------------------------------
  Future<void> _declineRequest(DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await doc.reference.update({
        'declinedBy': FieldValue.arrayUnion([user.uid]),
      });
    } catch (e) {
      debugPrint('Error declining: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // OPEN existing chat (for accepted requests this volunteer owns)
  // ---------------------------------------------------------------------------
  void _openChat(String requestId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(requestId: requestId, myRole: 'volunteer'),
      ),
    );
  }

  String _typeLabel(String? type) {
    if (type == null) return 'volunteer_requests.help_request'.tr();
    return 'volunteer_application.expertise.$type'.tr();
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'medical':
        return Icons.local_hospital_rounded;
      case 'navigation':
        return Icons.navigation_rounded;
      case 'translation':
        return Icons.translate_rounded;
      case 'emergency_response':
        return Icons.emergency_rounded;
      case 'crowd_management':
        return Icons.groups_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case 5:
        return Colors.red;
      case 4:
        return Colors.deepOrange;
      case 3:
        return Colors.orange;
      case 2:
        return Colors.lightGreen;
      case 1:
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _priorityLabel(int priority) {
    switch (priority) {
      case 5:
        return 'priority.life_threatening'.tr();
      case 4:
        return 'priority.urgent'.tr();
      case 3:
        return 'priority.moderate'.tr();
      case 2:
        return 'priority.mild'.tr();
      case 1:
        return 'priority.low'.tr();
      default:
        return 'priority.unknown'.tr();
    }
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final diff = DateTime.now().difference(timestamp.toDate());

    if (diff.inMinutes < 1) return 'time.just_now'.tr();
    if (diff.inMinutes < 60) {
      return 'time.minutes_ago'.tr(namedArgs: {'count': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'time.hours_ago'.tr(namedArgs: {'count': '${diff.inHours}'});
    }
    return 'time.days_ago'.tr(namedArgs: {'count': '${diff.inDays}'});
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;

    const background = Color(0xFFF7F4EF);
    const cardColor = Color(0xFFFFFFFF);
    const accent = Color(0xFFC9973A);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'volunteer_requests.title'.tr(),
                style: TextStyle(
                  color: const Color(0xFF1A1A2E),
                  fontSize: fs + 6,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'volunteer_requests.subtitle'.tr(),
                style: TextStyle(
                  color: const Color(0xFF6B6B80),
                  fontSize: fs - 2,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _myExpertise
                    .map(
                      (e) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _typeLabel(e),
                          style: TextStyle(
                            color: accent,
                            fontSize: fs - 3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE0DBD3), height: 1),
            const SizedBox(height: 8),

            // ── Stream of pending requests ─────────────────────────────────
            Expanded(
              child: currentUser == null
                  ? Center(
                      child: Text(
                        'errors.not_logged_in'.tr(),
                        style: const TextStyle(color: Color(0xFF6B6B80)),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('helpRequests')
                          .where('status', isEqualTo: 'pending')
                          .where(
                            'requestType',
                            whereIn: _myExpertise.isNotEmpty
                                ? _myExpertise
                                : ['general_guidance'],
                          )
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: accent),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'errors.index_required'.tr(),
                                    style: const TextStyle(
                                      color: Color(0xFF6B6B80),
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // Filter out declined requests
                        final docs =
                            snapshot.data?.docs.where((doc) {
                              final data = Map<String, dynamic>.from(
                                doc.data() as Map? ?? {},
                              );
                              final declinedBy = List<String>.from(
                                data['declinedBy'] ?? [],
                              );
                              return !declinedBy.contains(currentUser.uid);
                            }).toList() ??
                            [];

                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.inbox_rounded,
                                  size: 56,
                                  color: Color(0xFFCCCCDD),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'volunteer_requests.empty_title'.tr(),
                                  style: TextStyle(
                                    color: const Color(0xFF6B6B80),
                                    fontSize: fs,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'volunteer_requests.empty_subtitle'.tr(),
                                  style: TextStyle(
                                    color: const Color(0xFF9999AA),
                                    fontSize: fs - 2,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = Map<String, dynamic>.from(
                              doc.data() as Map? ?? {},
                            );

                            final type =
                                data['requestType'] as String? ??
                                'general_guidance';
                            final desc = data['description'] as String? ?? '';
                            final priority = data['priority'] as int? ?? 3;
                            final pilgrimName =
                                data['pilgrimName'] as String? ?? 'Pilgrim';
                            final needsAmbulance =
                                data['needsAmbulance'] as bool? ?? false;
                            final language =
                                data['language'] as String? ?? 'ar';
                            final createdAt = data['createdAt'] as Timestamp?;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0D000000),
                                    blurRadius: 16,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                                border: priority >= 4
                                    ? Border.all(
                                        color: _priorityColor(priority)
                                            .withValues(alpha: 0.4),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Type + Priority + Time
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _priorityColor(priority)
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                _typeIcon(type),
                                                color:
                                                    _priorityColor(priority),
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _typeLabel(type),
                                                    style: TextStyle(
                                                      color: const Color(
                                                          0xFF1A1A2E),
                                                      fontSize: fs,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              _priorityColor(
                                                            priority,
                                                          ).withValues(
                                                            alpha: 0.15,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: Text(
                                                          _priorityLabel(
                                                              priority),
                                                          style: TextStyle(
                                                            color:
                                                                _priorityColor(
                                                                    priority),
                                                            fontSize: fs - 4,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                          ),
                                                        ),
                                                      ),
                                                      if (needsAmbulance) ...[
                                                        const SizedBox(
                                                            width: 6),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.red
                                                                .withValues(
                                                              alpha: 0.15,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .local_hospital,
                                                                color:
                                                                    Colors.red,
                                                                size: fs - 4,
                                                              ),
                                                              const SizedBox(
                                                                  width: 3),
                                                              Text(
                                                                'volunteer_requests.ambulance'
                                                                    .tr(),
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .red,
                                                                  fontSize:
                                                                      fs - 4,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              _timeAgo(createdAt),
                                              style: TextStyle(
                                                color: const Color(0xFF9999AA),
                                                fontSize: fs - 3,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Description
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF7F4EF),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            desc,
                                            style: TextStyle(
                                              color: const Color(0xFF1A1A2E),
                                              fontSize: fs - 1,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),

                                        const SizedBox(height: 10),

                                        // Pilgrim info
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.person_outline,
                                              color: Color(0xFF9999AA),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              pilgrimName,
                                              style: TextStyle(
                                                color: const Color(0xFF6B6B80),
                                                fontSize: fs - 2,
                                              ),
                                            ),
                                            const Spacer(),
                                            const Icon(
                                              Icons.language,
                                              color: Color(0xFF9999AA),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              language == 'ar'
                                                  ? 'languages.arabic'.tr()
                                                  : 'languages.english'.tr(),
                                              style: TextStyle(
                                                color: const Color(0xFF6B6B80),
                                                fontSize: fs - 2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),
                                  const Divider(
                                    color: Color(0xFFE0DBD3),
                                    height: 1,
                                  ),

                                  // ── Accept / Decline buttons ─────────────
                                  Row(
                                    children: [
                                      // Decline
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _declineRequest(doc),
                                          borderRadius:
                                              const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.red.withValues(
                                                    alpha: 0.8,
                                                  ),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'volunteer_requests.decline'
                                                      .tr(),
                                                  style: TextStyle(
                                                    color: Colors.red
                                                        .withValues(alpha: 0.8),
                                                    fontSize: fs - 1,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const VerticalDivider(
                                        color: Color(0xFFE0DBD3),
                                        width: 1,
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _acceptRequest(doc),
                                          borderRadius:
                                              const BorderRadius.only(
                                            bottomRight: Radius.circular(16),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.check_rounded,
                                                  color: Color(0xFFC9973A),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'volunteer_requests.accept_chat'
                                                      .tr(),
                                                  style: TextStyle(
                                                    color:
                                                        const Color(0xFFC9973A),
                                                    fontSize: fs - 1,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),

            // ── Stream of this volunteer's active accepted chats ───────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Divider(color: Color(0xFFE0DBD3), height: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'volunteer_requests.active_chats'.tr(),
                      style: TextStyle(
                        color: const Color(0xFF9999AA),
                        fontSize: fs - 3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Divider(color: Color(0xFFE0DBD3), height: 1),
                  ),
                ],
              ),
            ),

            SizedBox(
              height: 90,
              child: currentUser == null
                  ? const SizedBox()
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('helpRequests')
                          .where(
                            'assignedVolunteer',
                            isEqualTo: currentUser.uid,
                          )
                          .snapshots(),
                      builder: (ctx, snap) {                       
                         // Client-side filter for accepted/in_progress only
                        final activeDocs = (snap.data?.docs ?? []).where((d) {
                          final s = (Map<String, dynamic>.from(
                            d.data() as Map? ?? {},
                          ))['status'] as String?;
                          return s == 'accepted' || s == 'in_progress';
                        }).toList();

                        if (activeDocs.isEmpty) {
                          return Center(
                            child: Text(
                              'volunteer_requests.no_active'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF9999AA),
                                fontSize: 12,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: activeDocs.length,
                          itemBuilder: (ctx, i) {
                            final d = Map<String, dynamic>.from(
                              activeDocs[i].data() as Map? ?? {},
                            );

                            final pName =
                                d['pilgrimName'] as String? ?? 'Pilgrim';
                            final type =
                                d['requestType'] as String? ??
                                'general_guidance';

                            return GestureDetector(
                              onTap: () => _openChat(activeDocs[i].id),
                              child: Container(
                                margin: const EdgeInsets.only(
                                  right: 10,
                                  bottom: 12,
                                  top: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFFFF),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0D000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: const Color(0xFFC9973A)
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline,
                                      color: Color(0xFFC9973A),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          pName,
                                          style: const TextStyle(
                                            color: Color(0xFF1A1A2E),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          _typeLabel(type),
                                          style: const TextStyle(
                                            color: Color(0xFF9999AA),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
