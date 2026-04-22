// =============================================================================
// FILE: lib/chat_page.dart
// DESCRIPTION: Live chat between pilgrim and volunteer after request is accepted.
//              Volunteer sees a sticky Mission Info card with the pilgrim's
//              location, request details, priority, and pilgrim info.
//              Both sides can send real-time messages.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'services/translation_service.dart';

class ChatPage extends StatefulWidget {
  /// The Firestore doc ID under 'helpRequests'
  final String requestId;

  /// 'pilgrim' or 'volunteer'
  final String myRole;

  const ChatPage({super.key, required this.requestId, required this.myRole});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _missionExpanded = true; // volunteer sees full card by default

  // ── colours ────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF050608);
  static const _card = Color(0xFF17191E);
  static const _accent = Color(0xFFF6B733);

  // ── helpers ─────────────────────────────────────────────────────────────────
  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _priorityColor(int p) {
    switch (p) {
      case 5:
        return Colors.red;
      case 4:
        return Colors.deepOrange;
      case 3:
        return Colors.orange;
      case 2:
        return Colors.lightGreen;
      default:
        return Colors.green;
    }
  }

  String _priorityLabel(int p) {
    switch (p) {
      case 5:
        return 'Life-Threatening';
      case 4:
        return 'Urgent';
      case 3:
        return 'Moderate';
      case 2:
        return 'Mild';
      default:
        return 'Low';
    }
  }

  IconData _typeIcon(String? t) {
    switch (t) {
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

  String _typeLabel(String? t) {
    const m = {
      'medical': 'Medical Assistance',
      'navigation': 'Navigation Help',
      'translation': 'Translation Help',
      'general_guidance': 'General Help',
      'emergency_response': 'Emergency Response',
      'crowd_management': 'Crowd Safety',
    };
    return m[t] ?? t ?? 'Help Request';
  }

  // ── send message ────────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _messageController.text.trim();
    if (user == null || text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final chatRef = FirebaseFirestore.instance
          .collection('helpRequests')
          .doc(widget.requestId)
          .collection('messages');

      await chatRef.add({
        'senderId': user.uid,
        'senderRole': widget.myRole,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update last-message metadata on the parent helpRequest doc
      await FirebaseFirestore.instance
          .collection('helpRequests')
          .doc(widget.requestId)
          .update({
            'lastMessage': text,
            'lastMessageSender': widget.myRole,
            'lastMessageTime': FieldValue.serverTimestamp(),
          });

      _messageController.clear();

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── mark request resolved ───────────────────────────────────────────────────
  Future<void> _markResolved() async {
    await FirebaseFirestore.instance
        .collection('helpRequests')
        .doc(widget.requestId)
        .update({
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
        });
    if (!mounted) return;
    Navigator.pop(context);
  }

  // ── build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('helpRequests')
          .doc(widget.requestId)
          .snapshots(),
      builder: (context, reqSnap) {
        final reqData = Map<String, dynamic>.from(
          (reqSnap.data?.data() as Map?) ?? {},
        );
        final status = reqData['status'] as String? ?? 'accepted';
        final type = reqData['requestType'] as String? ?? 'general_guidance';
        final description = reqData['description'] as String? ?? '';
        final priority = reqData['priority'] as int? ?? 3;
        final pilgrimName = reqData['pilgrimName'] as String? ?? 'Pilgrim';
        final volunteerName =
            reqData['volunteerName'] as String? ?? 'Volunteer';
        final needsAmb = reqData['needsAmbulance'] as bool? ?? false;
        final language = reqData['language'] as String? ?? 'en';
        final location = reqData['pilgrimLocation'] as GeoPoint?;
        final isResolved = status == 'resolved';

        final isVolunteer = widget.myRole == 'volunteer';
        final appBarTitle = isVolunteer
            ? 'Chat with $pilgrimName'
            : 'Chat with $volunteerName';

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appBarTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  isResolved ? '✓ Resolved' : '● Live',
                  style: TextStyle(
                    color: isResolved ? Colors.green : _accent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              if (isVolunteer && !isResolved)
                TextButton.icon(
                  onPressed: _showResolveDialog,
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 18,
                  ),
                  label: const Text(
                    'Resolve',
                    style: TextStyle(color: Colors.green, fontSize: 13),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // ── MISSION INFO CARD (volunteer only) ──────────────────────────
              if (isVolunteer)
                _MissionInfoCard(
                  type: type,
                  description: description,
                  priority: priority,
                  pilgrimName: pilgrimName,
                  language: language,
                  needsAmbulance: needsAmb,
                  location: location,
                  expanded: _missionExpanded,
                  onToggle: () =>
                      setState(() => _missionExpanded = !_missionExpanded),
                  priorityColor: _priorityColor(priority),
                  priorityLabel: _priorityLabel(priority),
                  typeIcon: _typeIcon(type),
                  typeLabel: _typeLabel(type),
                  onOpenMap: null,
                ),

              // ── MESSAGES ────────────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('helpRequests')
                      .doc(widget.requestId)
                      .collection('messages')
                      .orderBy('sentAt', descending: false)
                      .snapshots(),
                  builder: (context, msgSnap) {
                    if (msgSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _accent),
                      );
                    }

                    final docs = msgSnap.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Colors.white.withOpacity(0.15),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isVolunteer
                                  ? 'Send a message to let the pilgrim know you\'re on the way!'
                                  : 'Your volunteer will be in touch shortly.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final currentUid =
                        FirebaseAuth.instance.currentUser?.uid ?? '';

                    // Scroll to bottom when new messages arrive
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = Map<String, dynamic>.from(
                          docs[i].data() as Map? ?? {},
                        );
                        final senderId = d['senderId'] as String? ?? '';
                        final text = d['text'] as String? ?? '';
                        final sentAt = d['sentAt'] as Timestamp?;
                        final role = d['senderRole'] as String? ?? '';
                        final isMine = senderId == currentUid;

                        return _MessageBubble(
                          text: text,
                          time: _formatTime(sentAt),
                          isMine: isMine,
                          role: role,
                        );
                      },
                    );
                  },
                ),
              ),

              // ── INPUT ────────────────────────────────────────────────────────
              if (!isResolved)
                _ChatInput(
                  controller: _messageController,
                  isSending: _isSending,
                  onSend: _sendMessage,
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'This request has been resolved.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showResolveDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          'Mark as Resolved',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Has the pilgrim been helped? This will close the chat.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _markResolved();
            },
            child: const Text(
              'Yes, Resolved',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MISSION INFO CARD — shown only to the volunteer
// =============================================================================
class _MissionInfoCard extends StatelessWidget {
  final String type;
  final String description;
  final int priority;
  final String pilgrimName;
  final String language;
  final bool needsAmbulance;
  final GeoPoint? location;
  final bool expanded;
  final VoidCallback onToggle;
  final Color priorityColor;
  final String priorityLabel;
  final IconData typeIcon;
  final String typeLabel;
  final VoidCallback? onOpenMap;

  const _MissionInfoCard({
    required this.type,
    required this.description,
    required this.priority,
    required this.pilgrimName,
    required this.language,
    required this.needsAmbulance,
    required this.location,
    required this.expanded,
    required this.onToggle,
    required this.priorityColor,
    required this.priorityLabel,
    required this.typeIcon,
    required this.typeLabel,
    required this.onOpenMap,
  });

  static const _card = Color(0xFF17191E);
  static const _accent = Color(0xFFF6B733);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: priorityColor.withOpacity(0.45), width: 1.2),
      ),
      child: Column(
        children: [
          // ── Header row (always visible) ─────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(typeIcon, color: priorityColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _Chip(priorityLabel, priorityColor),
                            if (needsAmbulance) ...[
                              const SizedBox(width: 6),
                              _Chip('🚑 Ambulance', Colors.red),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded details ─────────────────────────────────────────────────
          if (expanded) ...[
            Divider(color: Colors.white.withOpacity(0.08), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  _InfoRow(
                    icon: Icons.description_outlined,
                    label: 'Description',
                    child: Text(
                      description.isEmpty ? '—' : description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                      textDirection: language == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Pilgrim name + language
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Pilgrim',
                    child: Text(
                      '$pilgrimName  •  ${language == 'ar' ? 'Arabic' : 'English'}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Location
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    child: location != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _accent.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: _accent,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${location!.latitude.toStringAsFixed(5)}, '
                                  '${location!.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    color: _accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            'Location not shared',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13,
                            ),
                          ),
                  ),

                  // Copy coords button
                  if (location != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(
                            text:
                                '${location!.latitude}, ${location!.longitude}',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Coordinates copied!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Text(
                        'Copy coordinates',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── tiny helper widgets ───────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Colors.white38, size: 15),
      const SizedBox(width: 6),
      Text(
        '$label: ',
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      Expanded(child: child),
    ],
  );
}

// =============================================================================
// MESSAGE BUBBLE
// =============================================================================
class _MessageBubble extends StatefulWidget {
  final String text;
  final String time;
  final bool isMine;
  final String role;

  const _MessageBubble({
    required this.text,
    required this.time,
    required this.isMine,
    required this.role,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  static const _accent = Color(0xFFF6B733);
  static const _card = Color(0xFF17191E);

  String? _translated;
  bool _showOriginal = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _autoTranslate();
  }

  Future<void> _autoTranslate() async {
    final myLang = context.locale.languageCode;
    final msgLang = await TranslationService.instance.identifyLanguage(widget.text);
    if (msgLang == myLang) return;
    final result = await TranslationService.instance.translate(
      widget.text,
      msgLang,
      myLang,
    );
    if (mounted && result != null) setState(() => _translated = result);
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _translated ?? widget.text;
    final hasTranslation = _translated != null;

    return Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: widget.isMine ? _accent : _card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.isMine ? 16 : 4),
            bottomRight: Radius.circular(widget.isMine ? 4 : 16),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Column(
          crossAxisAlignment: widget.isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Role label for the other person's messages
            if (!widget.isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  widget.role == 'volunteer' ? 'Volunteer' : 'Pilgrim',
                  style: TextStyle(
                    color: _accent.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            // Main text (translated if available)
            Text(
              displayText,
              style: TextStyle(
                color: widget.isMine ? Colors.black : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Original text section
            if (hasTranslation) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _showOriginal = !_showOriginal),
                child: Text(
                  _showOriginal ? 'Hide original' : 'See original',
                  style: TextStyle(
                    color: widget.isMine
                        ? Colors.black45
                        : Colors.white38,
                    fontSize: 10,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              if (_showOriginal)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: widget.isMine
                          ? Colors.black45
                          : Colors.white38,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 3),
            Text(
              widget.time,
              style: TextStyle(
                color: widget.isMine
                    ? Colors.black.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CHAT INPUT BAR
// =============================================================================
class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _ChatInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  static const _bg = Color(0xFF050608);
  static const _card = Color(0xFF17191E);
  static const _accent = Color(0xFFF6B733);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: isSending ? null : onSend,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
                child: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
