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
import 'package:provider/provider.dart';

import 'app_settings_provider.dart';
import 'services/translation_service.dart';

class ChatPage extends StatefulWidget {
  /// The Firestore doc ID under 'helpRequests'
  final String requestId;
  final String myRole; // 'pilgrim' or 'volunteer'

  const ChatPage({
    super.key,
    required this.requestId,
    required this.myRole,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  bool _missionExpanded = true; // volunteer sees full card by default

  // ── colours ────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF7F4EF);
  static const _card = Color(0xFFFFFFFF);
  static const _accent = Color(0xFFC9973A);

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
        return 'chat.priority_life_threatening'.tr();
      case 4:
        return 'chat.priority_urgent'.tr();
      case 3:
        return 'chat.priority_moderate'.tr();
      case 2:
        return 'chat.priority_mild'.tr();
      default:
        return 'chat.priority_low'.tr();
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
    switch (t) {
      case 'medical':
        return 'volunteer_application.expertise.medical'.tr();
      case 'navigation':
        return 'volunteer_application.expertise.navigation'.tr();
      case 'translation':
        return 'volunteer_application.expertise.translation'.tr();
      case 'general_guidance':
        return 'volunteer_application.expertise.general_guidance'.tr();
      case 'emergency_response':
        return 'volunteer_application.expertise.emergency_response'.tr();
      case 'crowd_management':
        return 'volunteer_application.expertise.crowd_management'.tr();
      default:
        return t ?? 'chat.help_request'.tr();
    }
  }

  String _languageLabel(String lang) {
    return lang == 'ar' ? 'languages.arabic'.tr() : 'languages.english'.tr();
  }

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
          content: Text(
            'chat.failed_send'.tr(namedArgs: {'error': '$e'}),
          ),
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
    final fs = context.watch<AppSettingsProvider>().fontSize;

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
        final pilgrimName = reqData['pilgrimName'] as String? ?? 'chat.pilgrim'.tr();
        final volunteerName =
            reqData['volunteerName'] as String? ?? 'chat.volunteer'.tr();
        final needsAmb = reqData['needsAmbulance'] as bool? ?? false;
        final language = reqData['language'] as String? ?? 'en';
        final location = reqData['pilgrimLocation'] as GeoPoint?;
        final isResolved = status == 'resolved';

        final isVolunteer = widget.myRole == 'volunteer';
        final appBarTitle = isVolunteer
            ? 'chat.chat_with'.tr(namedArgs: {'name': pilgrimName})
            : 'chat.chat_with'.tr(namedArgs: {'name': volunteerName});

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
                  style: TextStyle(
                    color: const Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w700,
                    fontSize: fs + 2,
                  ),
                ),
                Text(
                  isResolved ? 'chat.resolved_status'.tr() : 'chat.live_status'.tr(),
                  style: TextStyle(
                    color: isResolved ? Colors.green : _accent,
                    fontSize: fs - 2,
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
                  label: Text(
                    'chat.resolve'.tr(),
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: fs - 1,
                    ),
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
                  languageLabel: _languageLabel(language),
                  needsAmbulance: needsAmb,
                  location: location,
                  expanded: _missionExpanded,
                  onToggle: () =>
                      setState(() => _missionExpanded = !_missionExpanded),
                  priorityColor: _priorityColor(priority),
                  priorityLabel: _priorityLabel(priority),
                  typeIcon: _typeIcon(type),
                  typeLabel: _typeLabel(type),
                  fs: fs,
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: Color(0xFFCCCCDD),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isVolunteer
                                    ? 'chat.empty_volunteer'.tr()
                                    : 'chat.empty_pilgrim'.tr(),
                                style: TextStyle(
                                  color: const Color(0xFF6B6B80),
                                  fontSize: fs - 1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
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
                          fs: fs,
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
                  fs: fs,
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'chat.request_resolved'.tr(),
                    style: TextStyle(
                      color: const Color(0xFF6B6B80),
                      fontSize: fs - 1,
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
    final fs = context.read<AppSettingsProvider>().fontSize;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: Text(
          'chat.mark_resolved_title'.tr(),
          style: TextStyle(
            color: const Color(0xFF1A1A2E),
            fontSize: fs + 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'chat.mark_resolved_body'.tr(),
          style: TextStyle(
            color: const Color(0xFF6B6B80),
            fontSize: fs,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.cancel'.tr(),
              style: TextStyle(
                color: const Color(0xFF9999AA),
                fontSize: fs,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _markResolved();
            },
            child: Text(
              'chat.yes_resolved'.tr(),
              style: TextStyle(
                color: Colors.white,
                fontSize: fs,
              ),
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
  final String languageLabel;
  final bool needsAmbulance;
  final GeoPoint? location;
  final bool expanded;
  final VoidCallback onToggle;
  final Color priorityColor;
  final String priorityLabel;
  final IconData typeIcon;
  final String typeLabel;
  final VoidCallback? onOpenMap;
  final double fs;

  const _MissionInfoCard({
    required this.type,
    required this.description,
    required this.priority,
    required this.pilgrimName,
    required this.language,
    required this.languageLabel,
    required this.needsAmbulance,
    required this.location,
    required this.expanded,
    required this.onToggle,
    required this.priorityColor,
    required this.priorityLabel,
    required this.typeIcon,
    required this.typeLabel,
    required this.onOpenMap,
    required this.fs,
  });

  static const _card = Color(0xFFFFFFFF);
  static const _accent = Color(0xFFC9973A);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: priorityColor.withOpacity(0.45),
          width: 1.2,
        ),
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
                    child: Icon(typeIcon, color: priorityColor, size: fs + 6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          style: TextStyle(
                            color: const Color(0xFF1A1A2E),
                            fontWeight: FontWeight.w700,
                            fontSize: fs,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _Chip(priorityLabel, priorityColor, fs),
                            if (needsAmbulance) ...[
                              const SizedBox(width: 6),
                              _Chip('chat.ambulance'.tr(), Colors.red, fs),
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
                    color: const Color(0xFF9999AA),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded details ─────────────────────────────────────────────────
          if (expanded) ...[
            const Divider(color: Color(0xFFE0DBD3), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  _InfoRow(
                    icon: Icons.description_outlined,
                    label: 'chat.description'.tr(),
                    fs: fs,
                    child: Text(
                      description.isEmpty ? '—' : description,
                      style: TextStyle(
                        color: const Color(0xFF1A1A2E),
                        fontSize: fs - 1,
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
                    label: 'chat.pilgrim'.tr(),
                    fs: fs,
                    child: Text(
                      '$pilgrimName  •  $languageLabel',
                      style: TextStyle(
                        color: const Color(0xFF1A1A2E),
                        fontSize: fs - 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Location
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'chat.location'.tr(),
                    fs: fs,
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
                                Flexible(
                                  child: Text(
                                    '${location!.latitude.toStringAsFixed(5)}, '
                                    '${location!.longitude.toStringAsFixed(5)}',
                                    style: TextStyle(
                                      color: _accent,
                                      fontSize: fs - 2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            'chat.location_not_shared'.tr(),
                            style: TextStyle(
                              color: const Color(0xFF9999AA),
                              fontSize: fs - 1,
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
                            text: '${location!.latitude}, ${location!.longitude}',
                          ),
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'chat.coordinates_copied'.tr(),
                              style: TextStyle(fontSize: fs),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Text(
                        'chat.copy_coordinates'.tr(),
                        style: TextStyle(
                          color: const Color(0xFF9999AA),
                          fontSize: fs - 3,
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
  final double fs;

  const _Chip(this.text, this.color, this.fs);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fs - 3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  final double fs;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.child,
    required this.fs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF9999AA), size: fs + 1),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            color: const Color(0xFF9999AA),
            fontSize: fs - 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

// =============================================================================
// MESSAGE BUBBLE
// =============================================================================

class _MessageBubble extends StatefulWidget {
  final String text;
  final String time;
  final bool isMine;
  final String role;
  final double fs;

  const _MessageBubble({
    required this.text,
    required this.time,
    required this.isMine,
    required this.role,
    required this.fs,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  static const _accent = Color(0xFFC9973A);
  static const _card = Color(0xFFFFFFFF);

  String? _translated;
  bool _showOriginal = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _autoTranslate();
  }

  Future<void> _autoTranslate() async {
    final myLang = context.locale.languageCode;

    try {
      final msgLang =
          await TranslationService.instance.identifyLanguage(widget.text);

      if (msgLang.isEmpty || msgLang == 'und' || msgLang == myLang) return;

      final result = await TranslationService.instance.translate(
        widget.text,
        msgLang,
        myLang,
      );

      if (mounted && result != null && result.trim().isNotEmpty) {
        setState(() => _translated = result);
      }
    } catch (_) {
      // Keep original message if translation fails.
    }
  }

  String _roleLabel() {
    if (widget.role == 'volunteer') return 'chat.volunteer'.tr();
    if (widget.role == 'pilgrim') return 'chat.pilgrim'.tr();
    return widget.role;
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
          boxShadow: widget.isMine
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
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
                  _roleLabel(),
                  style: TextStyle(
                    color: _accent.withOpacity(0.8),
                    fontSize: widget.fs - 4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            // Main text (translated if available)
            Text(
              displayText,
              style: TextStyle(
                color: widget.isMine ? Colors.white : const Color(0xFF1A1A2E),
                fontSize: widget.fs,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Original text section
            if (hasTranslation) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _showOriginal = !_showOriginal),
                child: Text(
                  _showOriginal
                      ? 'chat.hide_original'.tr()
                      : 'chat.see_original'.tr(),
                  style: TextStyle(
                    color: widget.isMine
                        ? Colors.white70
                        : const Color(0xFF9999AA),
                    fontSize: widget.fs - 4,
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
                          ? Colors.white70
                          : const Color(0xFF9999AA),
                      fontSize: widget.fs - 3,
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
                    ? Colors.black.withOpacity(0.55)
                    : Colors.black.withOpacity(0.45),
                fontSize: widget.fs - 4,
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
  final double fs;

  const _ChatInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.fs,
  });

  static const _bg = Color(0xFFF7F4EF);
  static const _card = Color(0xFFFFFFFF);
  static const _accent = Color(0xFFC9973A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(
          top: BorderSide(color: Color(0xFFE8E4DE), width: 0.5),
        ),
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
                  style: TextStyle(
                    color: const Color(0xFF1A1A2E),
                    fontSize: fs,
                  ),
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'chat.type_message'.tr(),
                    hintStyle: TextStyle(
                      color: const Color(0xFFAAAAAA),
                      fontSize: fs - 1,
                    ),
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
                decoration: BoxDecoration(
                  color: isSending ? _accent.withOpacity(0.65) : _accent,
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
