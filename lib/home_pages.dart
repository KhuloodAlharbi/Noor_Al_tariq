// =============================================================================
// FILE: home_pages.dart
// DESCRIPTION: Home pages for both Hajj Performers and Volunteers
// MERGED: Original Hajj home UI + New Volunteer home with bottom nav
// CHANGES: + easy_localization (.tr()) + dynamic fontSize from AppSettingsProvider
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:noor_al_tariq/api/api_service.dart';

import 'role_selection_page.dart';
import 'app_settings_provider.dart';
import 'profile_page.dart';
import 'sos_request_page.dart';
import 'volunteer_requests_tab.dart';
import 'chat_page.dart';
import 'map_page.dart';

final api = ApiService();

// =============================================================================
// HAJJ PERFORMER HOME PAGE
// =============================================================================
class HajjHomePage extends StatefulWidget {
  const HajjHomePage({super.key});

  @override
  State<HajjHomePage> createState() => _HajjHomePageState();
}

class _HajjHomePageState extends State<HajjHomePage> {
  int _selectedIndex = 0;

  String? _userName;
  String? _userEmail;

  String? _nextPrayerName;
  DateTime? _nextPrayerTime;
  String? _timeRemainingText;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _calculatePrayerTimes();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // USER PROFILE
  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userEmail = user.email;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    setState(() {
      _userName = data?['name'] as String?;
    });
  }

  // PRAYER TIMES (adhan_dart)
  void _calculatePrayerTimes() {
    // Makkah coordinates
    const coordinates = Coordinates(21.3891, 39.8579);
    final now = DateTime.now();

    // adhan_dart parameters
    CalculationParameters params =
        CalculationMethodParameters.muslimWorldLeague()..madhab = Madhab.shafi;

    final prayerTimes = PrayerTimes(
      coordinates: coordinates,
      date: now,
      calculationParameters: params,
      precision: true,
    );

    // nextPrayer() returns a Prayer enum
    final Prayer nextPrayerEnum = prayerTimes.nextPrayer();

    // Get UTC time for that prayer
    final DateTime? nextUtcTime = prayerTimes.timeForPrayer(nextPrayerEnum);
    if (nextUtcTime == null) {
      setState(() {
        _nextPrayerName = null;
        _nextPrayerTime = null;
        _timeRemainingText = null;
      });
      return;
    }

    // Convert to device local time
    final DateTime localNextTime = nextUtcTime.toLocal();

    // Map enum to display name
    String displayName;
    switch (nextPrayerEnum) {
      case Prayer.fajr:
        displayName = 'prayers.fajr'.tr();
        break;
      case Prayer.sunrise:
        displayName = 'prayers.sunrise'.tr();
        break;
      case Prayer.dhuhr:
        displayName = 'prayers.dhuhr'.tr();
        break;
      case Prayer.asr:
        displayName = 'prayers.asr'.tr();
        break;
      case Prayer.maghrib:
        displayName = 'prayers.maghrib'.tr();
        break;
      case Prayer.isha:
        displayName = 'prayers.isha'.tr();
        break;
      default:
        displayName = 'home.next_prayer'.tr();
    }

    setState(() {
      _nextPrayerName = displayName;
      _nextPrayerTime = localNextTime;
      _timeRemainingText = _formatRemaining(now, localNextTime);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_nextPrayerTime != null) {
        setState(() {
          _timeRemainingText = _formatRemaining(
            DateTime.now(),
            _nextPrayerTime!,
          );
        });
      }
    });
  }

  String _formatRemaining(DateTime now, DateTime target) {
    final diff = target.difference(now);
    if (diff.isNegative) return '0:00';

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  // NAV BAR
  void _onItemTapped(int index) {
    // Index 2 is the SOS button — it opens a new page instead of switching tabs
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SOSRequestPage()),
      );
      return;
    }
    setState(() {
      // Map nav indices to page indices (skip index 2 which is SOS)
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context
        .watch<AppSettingsProvider>(); // ← for font size in nav bar
    const background = Color(0xFF050608);
    const cardColor = Color(0xFF17191E);
    const bottomBarColor = Color(0xFF121317);
    const accent = Color(0xFFF6B733);

    // Pages: 0=Home, 1=Chatbot, 2=SOS(not a page), 3=Map, 4=Settings
    final pages = <Widget>[
      _HomeTab(
        accent: accent,
        cardColor: cardColor,
        userName: _userName,
        userEmail: _userEmail,
        nextPrayerName: _nextPrayerName,
        nextPrayerTime: _nextPrayerTime,
        timeRemainingText: _timeRemainingText,
      ),
      const _ChatbotTab(),
      const SizedBox(), // placeholder for SOS (never shown, opens as page)
      MapPage(),
      const _HajjSettingsTab(),
    ];

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: bottomBarColor,
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Home
                _NavBarItem(
                  icon: Icons.home_rounded,
                  label: 'nav.home'.tr(),
                  isSelected: _selectedIndex == 0,
                  accent: accent,
                  fontSize: settings.fontSize - 3,
                  onTap: () => _onItemTapped(0),
                ),
                // Chatbot
                _NavBarItem(
                  icon: Icons.chat_bubble_rounded,
                  label: 'nav.chatbot'.tr(),
                  isSelected: _selectedIndex == 1,
                  accent: accent,
                  fontSize: settings.fontSize - 3,
                  onTap: () => _onItemTapped(1),
                ),
                // SOS - Raised circle button
                GestureDetector(
                  onTap: () => _onItemTapped(2),
                  child: Container(
                    width: 62,
                    height: 62,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sos_rounded, color: Colors.black, size: 20),
                        SizedBox(height: 1),
                        Text(
                          'Get Help',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Map
                _NavBarItem(
                  icon: Icons.map_rounded,
                  label: 'nav.map'.tr(),
                  isSelected: _selectedIndex == 3,
                  accent: accent,
                  fontSize: settings.fontSize - 3,
                  onTap: () => _onItemTapped(3),
                ),
                // Settings
                _NavBarItem(
                  icon: Icons.settings_rounded,
                  label: 'nav.settings'.tr(),
                  isSelected: _selectedIndex == 4,
                  accent: accent,
                  fontSize: settings.fontSize - 3,
                  onTap: () => _onItemTapped(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CUSTOM NAV BAR ITEM (for the pilgrim bottom bar)
// =============================================================================
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accent;
  final double fontSize;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? accent : Colors.white70, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accent : Colors.white70,
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HOME TAB (Hajj Performer)
// =============================================================================
class _HomeTab extends StatelessWidget {
  final Color accent;
  final Color cardColor;
  final String? userName;
  final String? userEmail;
  final String? nextPrayerName;
  final DateTime? nextPrayerTime;
  final String? timeRemainingText;

  const _HomeTab({
    required this.accent,
    required this.cardColor,
    this.userName,
    this.userEmail,
    this.nextPrayerName,
    this.nextPrayerTime,
    this.timeRemainingText,
  });

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          _TopHeaderCard(
            accent: accent,
            cardColor: cardColor,
            userName: userName,
            userEmail: userEmail,
          ),
          const SizedBox(height: 16),

          // Next Prayer card (dynamic)
          _SectionCard(
            cardColor: cardColor,
            child: _NextPrayerContent(
              nextPrayerName: nextPrayerName,
              nextPrayerTime: nextPrayerTime,
              timeRemainingText: timeRemainingText,
            ),
          ),

          const SizedBox(height: 12),

          // Daily Dua
          _SectionCard(
            cardColor: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home.daily_dua_title'.tr(),
                  style: TextStyle(
                    color: const Color(0xFFF6B733),
                    fontWeight: FontWeight.w600,
                    fontSize: fs,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'home.daily_dua_arabic'.tr(),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white, fontSize: fs + 1),
                ),
                const SizedBox(height: 8),
                Text(
                  'home.daily_dua_transliteration'.tr(),
                  style: TextStyle(color: Colors.white70, fontSize: fs - 1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Current ritual
          _SectionCard(
            cardColor: cardColor,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.blueGrey.shade700,
                    child: const Icon(
                      Icons.mosque_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'home.current_ritual'.tr(),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: fs - 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'home.ritual_name'.tr(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: fs + 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'home.ritual_location'.tr(),
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: fs - 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // AI Guide / chatbot entry
          _SectionCard(
            cardColor: cardColor,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'home.ai_guide_title'.tr(),
                        style: TextStyle(
                          color: const Color(0xFFF6B733),
                          fontWeight: FontWeight.w600,
                          fontSize: fs,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'home.ai_guide_subtitle'.tr(),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: fs - 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6B733),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.mic_none_rounded,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      // Later: programmatically switch to chatbot tab
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// NEXT PRAYER CONTENT
// =============================================================================
class _NextPrayerContent extends StatelessWidget {
  final String? nextPrayerName;
  final DateTime? nextPrayerTime;
  final String? timeRemainingText;

  const _NextPrayerContent({
    this.nextPrayerName,
    this.nextPrayerTime,
    this.timeRemainingText,
  });

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;
    final name = nextPrayerName ?? 'home.next_prayer'.tr();
    final timeStr = nextPrayerTime != null
        ? DateFormat.Hm().format(nextPrayerTime!)
        : '--:--';
    final remaining = timeRemainingText ?? '--:--';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'home.next_prayer'.tr(),
              style: TextStyle(color: Colors.white70, fontSize: fs - 1),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: fs + 6,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeStr,
              style: TextStyle(color: Colors.white54, fontSize: fs - 1),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'home.in_time'.tr(namedArgs: {'time': remaining}),
              style: TextStyle(
                color: const Color(0xFFF6B733),
                fontWeight: FontWeight.w600,
                fontSize: fs,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'home.prayer_time_label'.tr(),
              style: TextStyle(color: Colors.white54, fontSize: fs - 2),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// TOP HEADER CARD
// =============================================================================
class _TopHeaderCard extends StatelessWidget {
  final Color accent;
  final Color cardColor;
  final String? userName;
  final String? userEmail;

  const _TopHeaderCard({
    required this.accent,
    required this.cardColor,
    this.userName,
    this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;
    final displayName = (userName != null && userName!.trim().isNotEmpty)
        ? userName!
        : (userEmail != null ? userEmail!.split('@').first : 'Pilgrim');

    return _SectionCard(
      cardColor: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'app_name'.tr(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: fs + 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'home.welcome'.tr(namedArgs: {'name': displayName}),
                      style: TextStyle(color: Colors.white70, fontSize: fs - 1),
                    ),
                  ],
                ),
              ),
              // Language indicator — shows current locale
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black.withOpacity(0.35),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  context.locale.languageCode.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: fs - 2,
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

// =============================================================================
// SECTION CARD
// =============================================================================
class _SectionCard extends StatelessWidget {
  final Widget child;
  final Color cardColor;

  const _SectionCard({required this.child, required this.cardColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

// =============================================================================
// CHATBOT TAB
// =============================================================================
class _ChatbotTab extends StatefulWidget {
  const _ChatbotTab();

  @override
  State<_ChatbotTab> createState() => _ChatbotTabState();
}

class _ChatbotTabState extends State<_ChatbotTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<_ChatMessage> _messages;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages = [];
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_history_$uid');
    if (!mounted) return;
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _messages = list.map((e) => _ChatMessage.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      });
    } else {
      setState(() {
        _messages = [_ChatMessage(fromUser: false, text: 'chatbot.greeting'.tr())];
      });
    }
    _scrollToBottom();
  }

  Future<void> _saveMessages() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history_$uid', jsonEncode(_messages.map((m) => m.toJson()).toList()));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(fromUser: true, text: text));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'default';
      final reply = await ApiService().askChatbot(text, sessionId: uid);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(fromUser: false, text: reply));
        });
        _saveMessages();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(fromUser: false, text: 'chatbot.error'.tr()),
          );
        });
        _saveMessages();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    try {
      await ApiService().resetSession(uid);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history_$uid');
    if (mounted) {
      setState(() {
        _messages = [_ChatMessage(fromUser: false, text: 'chatbot.greeting'.tr())];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;
    const background = Color(0xFF050608);
    const accent = Color(0xFFF6B733);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0D0F14),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E2128), width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1000),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'chatbot.title'.tr(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: fs + 2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Online',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: fs - 4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear chat',
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white38,
                      size: 22,
                    ),
                    onPressed: _clearChat,
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const _TypingIndicator();
                  }
                  final msg = _messages[index];
                  final timeStr =
                      '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}';

                  if (msg.fromUser) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(width: 56),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(18),
                                      topRight: Radius.circular(18),
                                      bottomLeft: Radius.circular(18),
                                      bottomRight: Radius.circular(4),
                                    ),
                                  ),
                                  child: Text(
                                    msg.text,
                                    style: TextStyle(
                                      color: Color(0xFF0D0F14),
                                      fontSize: fs,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: Colors.white24,
                                    fontSize: fs - 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1000),
                              shape: BoxShape.circle,
                              border: Border.all(color: accent, width: 1),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: accent,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF141720),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(18),
                                      topRight: Radius.circular(18),
                                      bottomRight: Radius.circular(18),
                                      bottomLeft: Radius.circular(4),
                                    ),
                                  ),
                                  child: Text(
                                    msg.text,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: fs,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: Colors.white24,
                                    fontSize: fs - 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 56),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),

            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0D0F14),
                border: Border(
                  top: BorderSide(color: Color(0xFF1E2128), width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF17191E),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF2A2D35),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: Colors.white, fontSize: fs),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'chatbot.ask_placeholder'.tr(),
                          hintStyle: TextStyle(
                            color: Colors.white38,
                            fontSize: fs,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (_, val, __) {
                      final active = val.text.trim().isNotEmpty && !_isLoading;
                      return GestureDetector(
                        onTap: active ? _sendMessage : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: active
                                ? accent
                                : const Color(0xFF1E2128),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: active ? Colors.black : Colors.white24,
                            size: 22,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final bool fromUser;
  final String text;
  final DateTime time;

  _ChatMessage({required this.fromUser, required this.text, DateTime? time})
      : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'fromUser': fromUser,
        'text': text,
        'time': time.millisecondsSinceEpoch,
      };

  factory _ChatMessage.fromJson(Map<String, dynamic> j) => _ChatMessage(
        fromUser: j['fromUser'] as bool,
        text: j['text'] as String,
        time: DateTime.fromMillisecondsSinceEpoch(j['time'] as int),
      );
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF6B733);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1000),
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 1),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: accent, size: 15),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: const BoxDecoration(
              color: Color(0xFF141720),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = (_controller.value - i * 0.18) % 1.0;
                  final opacity = (sin(t * 2 * pi) * 0.5 + 0.5).clamp(0.2, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PLACEHOLDER TAB
// =============================================================================
class _PlaceholderTab extends StatelessWidget {
  final String title;

  const _PlaceholderTab({required this.title});

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;
    return Center(
      child: Text(
        '$title\n(Coming soon)',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: fs + 4),
      ),
    );
  }
}

// =============================================================================
// HAJJ SETTINGS TAB
// =============================================================================
class _HajjSettingsTab extends StatelessWidget {
  const _HajjSettingsTab();
  @override
  Widget build(BuildContext context) =>
      const _AppSettingsContent(isVolunteer: false);
}

// =============================================================================
// VOLUNTEER HOME PAGE
// =============================================================================
class VolunteerHomePage extends StatefulWidget {
  const VolunteerHomePage({super.key});

  @override
  State<VolunteerHomePage> createState() => _VolunteerHomePageState();
}

class _VolunteerHomePageState extends State<VolunteerHomePage> {
  int _selectedIndex = 0;
  String? _volunteerName;
  List<String> _myExpertise = [];

  @override
  void initState() {
    super.initState();
    _loadVolunteerProfile();
  }

  Future<void> _loadVolunteerProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      _volunteerName = doc.data()?['name'] as String?;
    }

    // Load expertise from volunteer_applications
    final appDoc = await FirebaseFirestore.instance
        .collection('volunteer_applications')
        .doc(user.uid)
        .get();

    if (appDoc.exists) {
      _myExpertise = List<String>.from(appDoc.data()?['expertiseAreas'] ?? []);
    }

    if (_myExpertise.isEmpty) {
      _myExpertise = ['medical', 'navigation', 'translation',
          'general_guidance', 'emergency_response', 'crowd_management'];
    }

    if (mounted) setState(() {});
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    const background = Color(0xFF050608);
    const bottomBarColor = Color(0xFF121317);
    const accent = Color(0xFFF6B733);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final pages = <Widget>[
      _VolunteerHomeTab(
        volunteerName: _volunteerName,
        myExpertise: _myExpertise,
        onGoToRequests: () => setState(() => _selectedIndex = 1),
      ),
      const VolunteerRequestsTab(),
      const _VolunteerChatsTab(),
      _PlaceholderTab(title: 'nav.map'.tr()),
      const _VolunteerSettingsTab(),
    ];

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        // Listen for pending requests matching expertise for the badge count
        stream: _myExpertise.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('helpRequests')
                .where('status', isEqualTo: 'pending')
                .where('requestType', whereIn: _myExpertise)
                .snapshots()
            : null,
        builder: (context, badgeSnap) {
          // Filter out requests this volunteer has declined
          final pendingCount = (badgeSnap.data?.docs ?? []).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final declinedBy = List<String>.from(data['declinedBy'] ?? []);
            return !declinedBy.contains(uid);
          }).length;

          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: bottomBarColor,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: accent,
            unselectedItemColor: Colors.white70,
            showUnselectedLabels: true,
            selectedLabelStyle: TextStyle(fontSize: settings.fontSize - 2),
            unselectedLabelStyle: TextStyle(fontSize: settings.fontSize - 3),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_rounded),
                label: 'nav.home'.tr(),
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10)),
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.assignment_rounded),
                ),
                label: 'nav.requests'.tr(),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.chat_bubble_rounded),
                label: 'nav.chat'.tr(),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.map_rounded),
                label: 'nav.map'.tr(),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_rounded),
                label: 'nav.settings'.tr(),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// VOLUNTEER HOME TAB — live stats from Firestore
// =============================================================================
class _VolunteerHomeTab extends StatelessWidget {
  final String? volunteerName;
  final List<String> myExpertise;
  final VoidCallback onGoToRequests;

  const _VolunteerHomeTab({
    this.volunteerName,
    this.myExpertise = const [],
    required this.onGoToRequests,
  });

  String _typeLabel(String? t) {
    const m = {
      'medical': 'Medical',
      'navigation': 'Navigation',
      'translation': 'Translation',
      'general_guidance': 'General Help',
      'emergency_response': 'Emergency',
      'crowd_management': 'Crowd Safety',
    };
    return m[t] ?? t ?? 'Help';
  }

  IconData _typeIcon(String? t) {
    switch (t) {
      case 'medical': return Icons.local_hospital_rounded;
      case 'navigation': return Icons.navigation_rounded;
      case 'translation': return Icons.translate_rounded;
      case 'emergency_response': return Icons.emergency_rounded;
      case 'crowd_management': return Icons.groups_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  Color _priorityColor(int p) {
    switch (p) {
      case 5: return Colors.red;
      case 4: return Colors.deepOrange;
      case 3: return Colors.orange;
      case 2: return Colors.lightGreen;
      default: return Colors.green;
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;
    const cardColor = Color(0xFF17191E);
    const accent = Color(0xFFF6B733);

    final displayName = volunteerName ?? 'Volunteer';
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('helpRequests')
          .where('assignedVolunteer', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? [];

        final resolvedCount = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['status'] == 'resolved';
        }).length;

        DocumentSnapshot? activeRequest;
        for (final d in allDocs) {
          final data = d.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';
          if (status == 'accepted' || status == 'in_progress') {
            activeRequest = d;
            break;
          }
        }

        final bool isBusy = activeRequest != null;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: accent.withOpacity(0.2),
                          child: Icon(
                            Icons.volunteer_activism_rounded,
                            color: accent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'app_name'.tr(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: fs + 2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'home.welcome'.tr(namedArgs: {'name': displayName}),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: fs,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isBusy
                                ? accent.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: isBusy ? accent : Colors.green,
                                size: 8,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isBusy ? 'Helping' : 'Available',
                                style: TextStyle(
                                  color: isBusy ? accent : Colors.green,
                                  fontSize: fs - 2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Row 1: Current Status banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isBusy
                        ? accent.withOpacity(0.25)
                        : Colors.green.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isBusy
                            ? accent.withOpacity(0.15)
                            : Colors.green.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isBusy
                            ? Icons.diversity_1_rounded
                            : Icons.check_circle_rounded,
                        color: isBusy ? accent : Colors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Status',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: fs - 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isBusy ? 'Helping a pilgrim' : 'Available',
                            style: TextStyle(
                              color: isBusy ? accent : Colors.green,
                              fontSize: fs + 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Row 2: Requests Completed banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Requests Completed',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: fs - 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$resolvedCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fs + 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── ACTIVE REQUEST / INCOMING REQUESTS SECTION ──
              if (isBusy) ...[
                Text(
                  'Active Request',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fs + 4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final data = activeRequest!.data() as Map<String, dynamic>;
                  final type = data['requestType'] as String? ?? 'general_guidance';
                  final desc = data['description'] as String? ?? '';
                  final pilgrimName = data['pilgrimName'] as String? ?? 'Pilgrim';
                  final priority = data['priority'] as int? ?? 3;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withOpacity(0.4), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.person_pin_circle_rounded,
                                  color: accent, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_typeLabel(type),
                                    style: TextStyle(color: Colors.white,
                                      fontSize: fs, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('Pilgrim: $pilgrimName',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: fs - 2)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _priorityColor(priority).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                priority >= 4 ? 'Urgent' : 'Active',
                                style: TextStyle(
                                  color: _priorityColor(priority),
                                  fontSize: fs - 3, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6), fontSize: fs - 1)),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  requestId: activeRequest!.id, myRole: 'volunteer'),
                              ));
                            },
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: Text('Open Chat',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: fs)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                // ── INCOMING REQUESTS PREVIEW (when not busy) ──
                Text(
                  'Incoming Requests',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fs + 4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot>(
                  stream: myExpertise.isNotEmpty
                      ? FirebaseFirestore.instance
                          .collection('helpRequests')
                          .where('status', isEqualTo: 'pending')
                          .where('requestType', whereIn: myExpertise)
                          .orderBy('createdAt', descending: true)
                          .limit(5)
                          .snapshots()
                      : null,
                  builder: (context, incomingSnap) {
                    final incomingDocs = (incomingSnap.data?.docs ?? []).where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final declinedBy = List<String>.from(data['declinedBy'] ?? []);
                      return !declinedBy.contains(uid);
                    }).toList();

                    if (incomingDocs.isEmpty) {
                      // Waiting for requests — calm empty state
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.notifications_none_rounded,
                                  color: accent.withOpacity(0.5), size: 28),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Waiting for requests',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: fs,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'You\'ll be notified when a pilgrim needs your help',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: fs - 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    // Show compact preview cards
                    return Column(
                      children: [
                        ...incomingDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final type = data['requestType'] as String? ?? 'general_guidance';
                          final priority = data['priority'] as int? ?? 3;
                          final pilgrimName = data['pilgrimName'] as String? ?? 'Pilgrim';
                          final createdAt = data['createdAt'] as Timestamp?;

                          return GestureDetector(
                            onTap: onGoToRequests,
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: priority >= 4
                                    ? Border.all(
                                        color: _priorityColor(priority).withOpacity(0.3))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _priorityColor(priority).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(_typeIcon(type),
                                        color: _priorityColor(priority), size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_typeLabel(type),
                                          style: TextStyle(color: Colors.white,
                                            fontSize: fs - 1, fontWeight: FontWeight.w600)),
                                        Text(pilgrimName,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.4),
                                            fontSize: fs - 3)),
                                      ],
                                    ),
                                  ),
                                  Text(_timeAgo(createdAt),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: fs - 3)),
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right_rounded,
                                      color: Colors.white.withOpacity(0.2), size: 18),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: onGoToRequests,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('View all requests',
                                  style: TextStyle(color: accent, fontSize: fs - 1,
                                    fontWeight: FontWeight.w600)),
                                const SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded,
                                    color: accent, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// VOLUNTEER CHATS TAB
// Uses StatefulWidget so the stream subscription survives rebuilds.
// Query is intentionally simple (single field filter only) to avoid
// needing a composite Firestore index. Filtering by status is done
// client-side after the snapshot arrives.
// =============================================================================
class _VolunteerChatsTab extends StatefulWidget {
  const _VolunteerChatsTab();

  @override
  State<_VolunteerChatsTab> createState() => _VolunteerChatsTabState();
}

class _VolunteerChatsTabState extends State<_VolunteerChatsTab> {
  Stream<QuerySnapshot>? _stream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Simple single-field query — no composite index needed.
      // Status filtering happens client-side below.
      _stream = FirebaseFirestore.instance
          .collection('helpRequests')
          .where('assignedVolunteer', isEqualTo: uid)
          .snapshots();
    }
  }

  String _typeLabel(String? type) {
    const m = {
      'medical': 'Medical Assistance',
      'navigation': 'Navigation Help',
      'translation': 'Translation Help',
      'general_guidance': 'General Help',
      'emergency_response': 'Emergency Response',
      'crowd_management': 'Crowd Safety',
    };
    return m[type] ?? 'General Help';
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;
    const background = Color(0xFF050608);
    const cardColor = Color(0xFF17191E);
    const accent = Color(0xFFF6B733);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Active Chats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fs + 6,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: _stream == null
                  ? const Center(
                      child: Text(
                        'Please log in',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: _stream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: accent),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }

                        // Client-side filter: only accepted / in_progress
                        final docs =
                            (snapshot.data?.docs ?? []).where((d) {
                                final s =
                                    (Map<String, dynamic>.from(
                                          d.data() as Map? ?? {},
                                        ))['status']
                                        as String?;
                                return s == 'accepted' || s == 'in_progress';
                              }).toList()
                              // Sort by acceptedAt descending client-side
                              ..sort((a, b) {
                                final ta =
                                    (Map<String, dynamic>.from(
                                          a.data() as Map? ?? {},
                                        ))['acceptedAt']
                                        as Timestamp?;
                                final tb =
                                    (Map<String, dynamic>.from(
                                          b.data() as Map? ?? {},
                                        ))['acceptedAt']
                                        as Timestamp?;
                                if (ta == null && tb == null) return 0;
                                if (ta == null) return 1;
                                if (tb == null) return -1;
                                return tb.compareTo(ta);
                              });

                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 56,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No active chats',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: fs,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Accept a request to start chatting',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
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
                          itemBuilder: (context, i) {
                            final data = Map<String, dynamic>.from(
                              docs[i].data() as Map? ?? {},
                            );
                            final pilgrimName =
                                data['pilgrimName'] as String? ?? 'Pilgrim';
                            final type =
                                data['requestType'] as String? ??
                                'general_guidance';
                            final lastMsg =
                                data['lastMessage'] as String? ?? '';
                            final acceptedAt = data['acceptedAt'] as Timestamp?;

                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    requestId: docs[i].id,
                                    myRole: 'volunteer',
                                  ),
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: accent.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: accent.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.chat_bubble_outline,
                                        color: accent,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pilgrimName,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: fs,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _typeLabel(type),
                                            style: TextStyle(
                                              color: accent.withOpacity(0.8),
                                              fontSize: fs - 3,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (lastMsg.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              lastMsg,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.45,
                                                ),
                                                fontSize: fs - 3,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Colors.white24,
                                          size: 14,
                                        ),
                                        if (acceptedAt != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            _timeAgo(acceptedAt),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                              fontSize: fs - 4,
                                            ),
                                          ),
                                        ],
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

// =============================================================================
// STAT CARD
// =============================================================================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17191E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: fs + 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: fs - 2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// VOLUNTEER SETTINGS TAB → delegates to shared _AppSettingsContent
// =============================================================================
class _VolunteerSettingsTab extends StatelessWidget {
  const _VolunteerSettingsTab();
  @override
  Widget build(BuildContext context) =>
      const _AppSettingsContent(isVolunteer: true);
}

// =============================================================================
// SHARED APP SETTINGS CONTENT (replaces both _HajjSettingsTab & _VolunteerSettingsTab)
// =============================================================================
class _AppSettingsContent extends StatefulWidget {
  final bool isVolunteer;
  const _AppSettingsContent({required this.isVolunteer});
  @override
  State<_AppSettingsContent> createState() => _AppSettingsContentState();
}

class _AppSettingsContentState extends State<_AppSettingsContent> {
  bool _isAvailable = true;
  bool _prayerNotificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _prayerNotificationsEnabled =
            doc.data()?['prayerNotifications'] as bool? ?? false;
        _isAvailable = doc.data()?['isAvailable'] as bool? ?? true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final fs = settings.fontSize;
    const accent = Color(0xFFF6B733);
    const cardColor = Color(0xFF17191E);

    return Scaffold(
      backgroundColor: const Color(0xFF050608),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'settings.title'.tr(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fs + 6,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Account
              _sectionLabel('settings.account_section'.tr(), accent, fs),
              _buildTile(
                cardColor,
                accent,
                Icons.person_rounded,
                'settings.my_profile'.tr(),
                'settings.profile_subtitle'.tr(),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
                fs,
              ),
              const SizedBox(height: 20),

              // App Preferences
              _sectionLabel('settings.app_section'.tr(), accent, fs),
              _buildLanguageTile(cardColor, accent, settings, fs),
              const SizedBox(height: 8),
              _buildFontSizeTile(cardColor, accent, settings, fs),
              const SizedBox(height: 8),
              _buildSwitchTile(
                cardColor,
                accent,
                Icons.notifications_active_rounded,
                'profile.notifications_enable'.tr(),
                'profile.notifications_subtitle'.tr(),
                _prayerNotificationsEnabled,
                (v) {
                  setState(() => _prayerNotificationsEnabled = v);
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .update({'prayerNotifications': v});
                },
                fs,
              ),

              if (widget.isVolunteer) ...[
                const SizedBox(height: 8),
                _buildSwitchTile(
                  cardColor,
                  accent,
                  Icons.schedule_rounded,
                  'settings.availability'.tr(),
                  'settings.availability_subtitle'.tr(),
                  _isAvailable,
                  (v) {
                    setState(() => _isAvailable = v);
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .update({'isAvailable': v});
                  },
                  fs,
                ),
              ],

              const SizedBox(height: 32),
              // Logout
              _buildTile(
                cardColor,
                Colors.redAccent,
                Icons.logout,
                'common.logout'.tr(),
                '',
                () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted)
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RoleSelectionPage(),
                      ),
                    );
                },
                fs,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color color, double fs) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: fs - 3,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    ),
  );

  Widget _buildTile(
    Color bg,
    Color acc,
    IconData icon,
    String title,
    String sub,
    VoidCallback tap,
    double fs,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: ListTile(
      leading: Icon(icon, color: acc),
      title: Text(
        title,
        style: TextStyle(color: Colors.white, fontSize: fs),
      ),
      subtitle: sub.isNotEmpty
          ? Text(
              sub,
              style: TextStyle(color: Colors.white54, fontSize: fs - 2),
            )
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
      onTap: tap,
    ),
  );

  Widget _buildSwitchTile(
    Color bg,
    Color acc,
    IconData icon,
    String title,
    String sub,
    bool val,
    Function(bool) onChange,
    double fs,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: acc),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.white, fontSize: fs),
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  style: TextStyle(color: Colors.white54, fontSize: fs - 2),
                ),
            ],
          ),
        ),
        Switch(value: val, activeColor: acc, onChanged: onChange),
      ],
    ),
  );

  Widget _buildLanguageTile(
    Color bg,
    Color acc,
    AppSettingsProvider settings,
    double fs,
  ) {
    final isAr = context.locale == const Locale('ar');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.language_rounded, color: acc),
              const SizedBox(width: 10),
              Text(
                'profile.language_section'.tr(),
                style: TextStyle(color: Colors.white, fontSize: fs),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _langBtn('en', 'English', !isAr, acc, settings, fs),
              const SizedBox(width: 8),
              _langBtn('ar', 'العربية', isAr, acc, settings, fs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _langBtn(
    String code,
    String label,
    bool sel,
    Color acc,
    AppSettingsProvider settings,
    double fs,
  ) => Expanded(
    child: GestureDetector(
      onTap: () async {
        await context.setLocale(Locale(code));
        await settings.setLanguage(code == 'ar' ? 'Arabic' : 'English');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? acc : Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: sel ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: fs - 1,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildFontSizeTile(
    Color bg,
    Color acc,
    AppSettingsProvider settings,
    double fs,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(Icons.text_fields_rounded, color: acc),
            const SizedBox(width: 10),
            Text(
              'profile.font_section'.tr(),
              style: TextStyle(color: Colors.white, fontSize: fs),
            ),
            const Spacer(),
            Text(
              '${fs.toInt()}',
              style: TextStyle(
                color: acc,
                fontWeight: FontWeight.bold,
                fontSize: fs,
              ),
            ),
          ],
        ),
        Slider(
          value: fs,
          min: 12,
          max: 22,
          activeColor: acc,
          onChanged: (v) => settings.setFontSize(v),
        ),
      ],
    ),
  );
}
