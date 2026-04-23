// =============================================================================
// FILE: lib/sos_request_page.dart
// DESCRIPTION: SOS Help Request page - one input box, translation follows app
//              language for both voice and typed text.
//              Voice input language can be selected independently.
//              Responsive layout for different screen sizes.
// =============================================================================

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:easy_localization/easy_localization.dart' hide TextDirection;

import 'services/sos_classification_service.dart';
import 'services/translation_service.dart';
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
  bool _isTranslating = false;
  bool _speechAvailable = false;
  bool _speechLanguageInitialized = false;
  String? _errorMessage;

  String _speechInputLanguage = 'en';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool get _appIsArabic => context.locale.languageCode == 'ar';
  String get _targetLanguage => _appIsArabic ? 'ar' : 'en';
  String get _micLocale => _speechInputLanguage == 'ar' ? 'ar-SA' : 'en-US';
  bool get _inputIsRTL => _appIsArabic;

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
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_speechLanguageInitialized) {
      _speechInputLanguage = context.locale.languageCode == 'ar' ? 'ar' : 'en';
      _speechLanguageInitialized = true;
    }
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
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _errorMessage = error.errorMsg;
        });
      },
      onStatus: (status) async {
        if (!mounted) return;

        if (status == 'notListening' || status == 'done') {
          setState(() => _isListening = false);
          await _translateCurrentText();
        }
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      await _translateCurrentText();
      return;
    }

    if (!_speechAvailable) {
      setState(() => _errorMessage = 'Speech recognition not available');
      return;
    }

    _textController.clear();

    setState(() {
      _isListening = true;
      _errorMessage = null;
    });

    await _speech.listen(
      localeId: _micLocale,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      onResult: (result) {
        final spokenText = result.recognizedWords.trim();
        if (!mounted) return;

        setState(() {
          _textController.text = spokenText;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        });
      },
    );
  }

  Future<void> _translateCurrentText() async {
    final raw = _textController.text.trim();
    if (raw.isEmpty) return;

    if (mounted) {
      setState(() => _isTranslating = true);
    }

    try {
      final detectedLang = await TranslationService.instance.identifyLanguage(
        raw,
      );

      if (detectedLang.isEmpty || detectedLang == 'und') {
        return;
      }

      if (detectedLang != _targetLanguage) {
        final translated = await TranslationService.instance.translate(
          raw,
          detectedLang,
          _targetLanguage,
        );

        if (!mounted) return;

        if (translated != null && translated.trim().isNotEmpty) {
          setState(() {
            _textController.text = translated;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: translated.length),
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Translation failed, keeping original text: $e');
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  Future<void> _submitRequest() async {
    FocusScope.of(context).unfocus();

    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
    }

    await _translateCurrentText();

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
      Position? position;
      try {
        position = await _getCurrentLocation();
      } catch (_) {}

      final classification = await SOSClassificationService.classify(text);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _errorMessage = 'You must be logged in');
        return;
      }

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

      await FirebaseFirestore.instance.collection('helpRequests').add({
        'pilgrimId': user.uid,
        'pilgrimName': pilgrimName,
        'description': text,
        'requestType': classification['request_type'] ?? 'general_guidance',
        'priority': classification['priority'] ?? 3,
        'confidence': classification['confidence'] ?? 0.0,
        'needsAmbulance': classification['needs_ambulance'] ?? false,
        'language': _targetLanguage,
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

      _textController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _appIsArabic
                      ? 'تم إرسال الطلب، النوع: ${_typeLabel(classification['request_type'])}'
                      : 'Request sent! Type: ${_typeLabel(classification['request_type'])}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
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
        return const Color(0xFF9999AA);
    }
  }

  String _statusLabel(String status) {
    if (_appIsArabic) {
      switch (status) {
        case 'pending':
          return 'جاري البحث عن متطوع...';
        case 'assigned':
          return 'تم العثور على متطوع، بانتظار الرد...';
        case 'accepted':
          return 'المتطوع في الطريق!';
        case 'in_progress':
          return 'جاري تقديم المساعدة';
        case 'resolved':
          return 'تم الحل';
        case 'declined':
          return 'جاري البحث عن شخص آخر...';
        case 'cancelled':
          return 'تم الإلغاء';
        default:
          return status;
      }
    }

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

  Widget _speechLanguageButton({
    required String label,
    required String value,
    required Color accent,
    required Color cardColor,
  }) {
    final isSelected = _speechInputLanguage == value;

    return GestureDetector(
      onTap: (_isListening || _isSubmitting || _isTranslating)
          ? null
          : () {
              setState(() {
                _speechInputLanguage = value;
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? accent : cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accent : accent.withOpacity(0.25),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF1A1A2E),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF7F4EF);
    const cardColor = Color(0xFFFFFFFF);
    const accent = Color(0xFFC9973A);

    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1A1A2E),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _appIsArabic ? 'طلب مساعدة' : 'Request Help',
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),

                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _appIsArabic
                                    ? 'لغة التحدث:'
                                    : 'Speaking language:',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF6B6B80),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _speechLanguageButton(
                              label: _appIsArabic ? 'العربية' : 'Arabic',
                              value: 'ar',
                              accent: accent,
                              cardColor: cardColor,
                            ),
                            _speechLanguageButton(
                              label: _appIsArabic ? 'الإنجليزية' : 'English',
                              value: 'en',
                              accent: accent,
                              cardColor: cardColor,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 90,
                          maxHeight: 140,
                        ),
                        child: Container(
                          width: double.infinity,
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
                            maxLines: null,
                            autofocus: false,
                            cursorColor: accent,
                            textDirection: _inputIsRTL
                                ? ui.TextDirection.rtl
                                : ui.TextDirection.ltr,
                            onEditingComplete: _translateCurrentText,
                            onSubmitted: (_) => _translateCurrentText(),
                            style: const TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: _appIsArabic
                                  ? 'اكتب أو تحدث هنا...'
                                  : 'Type or speak here...',
                              hintStyle: const TextStyle(
                                color: Color(0xFFAAAAAA),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      if (_isListening || _isTranslating)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isTranslating ? accent : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _isTranslating
                                      ? (_appIsArabic
                                            ? 'جاري الترجمة...'
                                            : 'Translating...')
                                      : (_speechInputLanguage == 'ar'
                                            ? (_appIsArabic
                                                  ? 'جاري الاستماع بالعربية...'
                                                  : 'Listening in Arabic...')
                                            : (_appIsArabic
                                                  ? 'جاري الاستماع بالإنجليزية...'
                                                  : 'Listening in English...')),
                                  style: TextStyle(
                                    color: _isTranslating ? accent : Colors.red,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),

                      Row(
                        children: [
                          ScaleTransition(
                            scale: _isListening
                                ? _pulseAnimation
                                : const AlwaysStoppedAnimation(1.0),
                            child: GestureDetector(
                              onTap: (_isSubmitting || _isTranslating)
                                  ? null
                                  : _toggleListening,
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
                              onTap: (_isSubmitting || _isTranslating)
                                  ? null
                                  : _submitRequest,
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: (_isSubmitting || _isTranslating)
                                      ? accent.withOpacity(0.5)
                                      : accent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: (_isSubmitting || _isTranslating)
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.send_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _appIsArabic
                                                    ? 'إرسال طلب استغاثة'
                                                    : 'Send SOS Request',
                                                style: const TextStyle(
                                                  color: Colors.white,
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
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: Color(0xFFE0DBD3)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              _appIsArabic ? 'طلباتي' : 'My Requests',
                              style: const TextStyle(
                                color: Color(0xFF9999AA),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: Color(0xFFE0DBD3)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.45,
                        child: currentUser == null
                            ? Center(
                                child: Text(
                                  _appIsArabic
                                      ? 'الرجاء تسجيل الدخول'
                                      : 'Please log in',
                                  style: const TextStyle(
                                    color: Color(0xFF6B6B80),
                                  ),
                                ),
                              )
                            : StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('helpRequests')
                                    .where(
                                      'pilgrimId',
                                      isEqualTo: currentUser.uid,
                                    )
                                    .orderBy('createdAt', descending: true)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: accent,
                                      ),
                                    );
                                  }

                                  if (!snapshot.hasData ||
                                      snapshot.data!.docs.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.inbox_rounded,
                                            size: 48,
                                            color: Color(0xFFCCCCDD),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _appIsArabic
                                                ? 'لا توجد طلبات بعد'
                                                : 'No requests yet',
                                            style: const TextStyle(
                                              color: Color(0xFF6B6B80),
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _appIsArabic
                                                ? 'ستظهر طلبات المساعدة هنا'
                                                : 'Your help requests will appear here',
                                            style: const TextStyle(
                                              color: Color(0xFF9999AA),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final docs = snapshot.data!.docs;

                                  return ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                    ),
                                    itemCount: docs.length,
                                    itemBuilder: (context, index) {
                                      final data =
                                          docs[index].data()
                                              as Map<String, dynamic>;
                                      final status =
                                          data['status'] as String? ??
                                          'pending';
                                      final type =
                                          data['requestType'] as String? ??
                                          'general_guidance';
                                      final desc =
                                          data['description'] as String? ?? '';
                                      final volunteerName =
                                          data['volunteerName'] as String?;
                                      final createdAt =
                                          data['createdAt'] as Timestamp?;
                                      final timeStr = createdAt != null
                                          ? '${createdAt.toDate().hour.toString().padLeft(2, '0')}:${createdAt.toDate().minute.toString().padLeft(2, '0')}'
                                          : '';

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x0D000000),
                                              blurRadius: 16,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _statusColor(
                                                      status,
                                                    ).withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        _typeLabel(type),
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF1A1A2E,
                                                          ),
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        desc,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF9999AA,
                                                          ),
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  timeStr,
                                                  style: const TextStyle(
                                                    color: Color(0xFF9999AA),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _statusColor(
                                                      status,
                                                    ).withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration:
                                                            BoxDecoration(
                                                              color:
                                                                  _statusColor(
                                                                    status,
                                                                  ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        _statusLabel(status),
                                                        style: TextStyle(
                                                          color: _statusColor(
                                                            status,
                                                          ),
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (status == 'accepted' ||
                                                    status == 'in_progress')
                                                  GestureDetector(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              ChatPage(
                                                                requestId:
                                                                    docs[index]
                                                                        .id,
                                                                myRole:
                                                                    'pilgrim',
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFC9973A,
                                                        ).withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFFC9973A,
                                                          ).withOpacity(0.5),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .chat_bubble_outline,
                                                            color: Color(
                                                              0xFFC9973A,
                                                            ),
                                                            size: 13,
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Text(
                                                            _appIsArabic
                                                                ? 'فتح المحادثة'
                                                                : 'Open Chat',
                                                            style:
                                                                const TextStyle(
                                                                  color: Color(
                                                                    0xFFC9973A,
                                                                  ),
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                if (volunteerName != null &&
                                                    status != 'accepted' &&
                                                    status != 'in_progress')
                                                  Flexible(
                                                    child: Text(
                                                      _appIsArabic
                                                          ? 'المتطوع: $volunteerName'
                                                          : 'Volunteer: $volunteerName',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF9999AA,
                                                        ),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                if (status == 'pending')
                                                  GestureDetector(
                                                    onTap: () {
                                                      docs[index].reference
                                                          .update({
                                                            'status':
                                                                'cancelled',
                                                          });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        _appIsArabic
                                                            ? 'إلغاء'
                                                            : 'Cancel',
                                                        style: const TextStyle(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
