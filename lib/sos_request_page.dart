// =============================================================================
// FILE: lib/sos_request_page.dart
// DESCRIPTION: SOS Help Request page - smaller text input + live request list
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'services/sos_classification_service.dart';
import 'chat_page.dart';

class SOSRequestPage extends StatefulWidget {
  const SOSRequestPage({super.key});

  @override
  State<SOSRequestPage> createState() => _SOSRequestPageState();
}

class _SOSRequestPageState extends State<SOSRequestPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _isSubmitting = false;
  bool _speechAvailable = false;
  String _selectedLanguage = 'ar-SA';
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'notListening') setState(() => _isListening = false);
      },
    );
    setState(() {});
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    if (!_speechAvailable) {
      setState(() => _errorMessage = 'Speech recognition not available');
      return;
    }
    setState(() {
      _isListening = true;
      _errorMessage = null;
    });
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        });
      },
      localeId: _selectedLanguage,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
    );
  }

  Future<void> _submitRequest() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Please describe your problem');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_isListening) {
        await _speech.stop();
        setState(() => _isListening = false);
      }

      // Get GPS (continue even if it fails)
      Position? position;
      try {
        position = await _getCurrentLocation();
      } catch (_) {}

      // Classify
      final classification = await SOSClassificationService.classify(text);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _errorMessage = 'You must be logged in');
        return;
      }

      // Get pilgrim name from Firestore
      String pilgrimName = 'Pilgrim';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          pilgrimName =
              userDoc.data()?['name'] as String? ??
              user.email?.split('@').first ??
              'Pilgrim';
        }
      } catch (_) {}

      // Write to Firestore
      await FirebaseFirestore.instance.collection('helpRequests').add({
        'pilgrimId': user.uid,
        'pilgrimName': pilgrimName,
        'description': text,
        'requestType': classification['request_type'] ?? 'general_guidance',
        'priority': classification['priority'] ?? 3,
        'confidence': classification['confidence'] ?? 0.0,
        'needsAmbulance': classification['needs_ambulance'] ?? false,
        'language': classification['language'] ?? 'ar',
        'source': classification['source'] ?? 'unknown',
        'pilgrimLocation': position != null
            ? GeoPoint(position.latitude, position.longitude)
            : null,
        'status': 'pending',
        'assignedVolunteer': null,
        'volunteerName': null,
        'chatId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
      });

      if (!mounted) return;

      // Clear text and show snackbar
      _textController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Text(
                'Request sent! Type: ${_typeLabel(classification['request_type'])}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF6B645),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  String _typeLabel(String? type) {
    const labels = {
      'medical': 'Medical',
      'navigation': 'Navigation',
      'translation': 'Translation',
      'general_guidance': 'General Help',
      'emergency_response': 'Emergency',
      'crowd_management': 'Crowd Safety',
    };
    return labels[type] ?? type ?? 'General';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'accepted':
        return const Color(0xFFF6B645);
      case 'in_progress':
        return const Color(0xFFF6B645);
      case 'resolved':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.white54;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Looking for volunteer...';
      case 'assigned':
        return 'Volunteer found, waiting...';
      case 'accepted':
        return 'Volunteer on the way!';
      case 'in_progress':
        return 'Help in progress';
      case 'resolved':
        return 'Resolved';
      case 'declined':
        return 'Finding another...';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
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

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF050509);
    const cardColor = Color(0xFF17171F);
    const accent = Color(0xFFF6B645);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Help',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ═══════════ TOP: Input + Send ═══════════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 4),

                  // Language toggle
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _languageButton(
                          '\u0627\u0644\u0639\u0631\u0628\u064A\u0629',
                          'ar-SA',
                          accent,
                        ),
                        const SizedBox(width: 4),
                        _languageButton('English', 'en-US', accent),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Text input (3-4 lines)
                  Container(
                    height: 100,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _textController,
                      maxLines: 4,
                      textDirection: _selectedLanguage == 'ar-SA'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: _selectedLanguage == 'ar-SA'
                            ? '\u0627\u0643\u062A\u0628 \u0645\u0634\u0643\u0644\u062A\u0643 \u0647\u0646\u0627...'
                            : 'Describe your problem...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Error
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Listening indicator
                  if (_isListening)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedLanguage == 'ar-SA'
                                ? '\u062C\u0627\u0631\u064A \u0627\u0644\u0627\u0633\u062A\u0645\u0627\u0639...'
                                : 'Listening...',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Mic + Send row
                  Row(
                    children: [
                      ScaleTransition(
                        scale: _isListening
                            ? _pulseAnimation
                            : const AlwaysStoppedAnimation(1.0),
                        child: GestureDetector(
                          onTap: _isSubmitting ? null : _toggleListening,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _isListening ? Colors.red : cardColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isListening
                                    ? Colors.red
                                    : accent.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _isListening ? Icons.stop : Icons.mic,
                              color: _isListening ? Colors.white : accent,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSubmitting ? null : _submitRequest,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: _isSubmitting
                                  ? accent.withOpacity(0.5)
                                  : accent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.send_rounded,
                                          color: Colors.black,
                                          size: 20,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Send SOS Request',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ═══════════ DIVIDER ═══════════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(height: 0.5, color: Colors.white12),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'My Requests',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(height: 0.5, color: Colors.white12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ═══════════ BOTTOM: Live Request List ═══════════
            Expanded(
              child: currentUser == null
                  ? const Center(
                      child: Text(
                        'Please log in',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('helpRequests')
                          .where('pilgrimId', isEqualTo: currentUser.uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: accent),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_rounded,
                                  size: 48,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No requests yet',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your help requests will appear here',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.25),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;
                            final status =
                                data['status'] as String? ?? 'pending';
                            final type =
                                data['requestType'] as String? ??
                                'general_guidance';
                            final desc = data['description'] as String? ?? '';
                            final volunteerName =
                                data['volunteerName'] as String?;
                            final createdAt = data['createdAt'] as Timestamp?;
                            final timeStr = createdAt != null
                                ? '${createdAt.toDate().hour.toString().padLeft(2, '0')}:${createdAt.toDate().minute.toString().padLeft(2, '0')}'
                                : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: icon + type + time
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            status,
                                          ).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          _typeIcon(type),
                                          color: _statusColor(status),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _typeLabel(type),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              desc,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.5,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // Status badge + action buttons
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            status,
                                          ).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: _statusColor(status),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _statusLabel(status),
                                              style: TextStyle(
                                                color: _statusColor(status),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      // ── OPEN CHAT button when accepted ──────
                                      if (status == 'accepted' ||
                                          status == 'in_progress')
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ChatPage(
                                                  requestId: docs[index].id,
                                                  myRole: 'pilgrim',
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFF6B733,
                                              ).withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFFF6B733,
                                                ).withOpacity(0.5),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.chat_bubble_outline,
                                                  color: Color(0xFFF6B733),
                                                  size: 13,
                                                ),
                                                SizedBox(width: 5),
                                                Text(
                                                  'Open Chat',
                                                  style: TextStyle(
                                                    color: Color(0xFFF6B733),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      if (volunteerName != null &&
                                          status != 'accepted' &&
                                          status != 'in_progress')
                                        Text(
                                          'Volunteer: $volunteerName',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.4,
                                            ),
                                            fontSize: 11,
                                          ),
                                        ),
                                      if (status == 'pending')
                                        GestureDetector(
                                          onTap: () {
                                            docs[index].reference.update({
                                              'status': 'cancelled',
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 11,
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
          ],
        ),
      ),
    );
  }

  Widget _languageButton(String label, String localeId, Color accent) {
    final isSelected = _selectedLanguage == localeId;
    return GestureDetector(
      onTap: () => setState(() => _selectedLanguage = localeId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.5),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
