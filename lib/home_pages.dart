// =============================================================================
// FILE: home_pages.dart
// DESCRIPTION: Home pages for both Hajj Performers and Volunteers
// MERGED: Original Hajj home UI + New Volunteer home with bottom nav
// CHANGES: + easy_localization (.tr()) + dynamic fontSize from AppSettingsProvider
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'role_selection_page.dart';
import 'app_settings_provider.dart';
import 'profile_page.dart';
import 'sos_request_page.dart';
import 'volunteer_requests_tab.dart';
import 'chat_page.dart';

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
      _PlaceholderTab(title: 'nav.map'.tr()),
      const _HajjSettingsTab(),
    ];

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(child: pages[_selectedIndex]),
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
  late List<_ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = [
      _ChatMessage(fromUser: false, text: 'chatbot.greeting'.tr()),
      _ChatMessage(fromUser: true, text: 'chatbot.suggest_ritual'.tr()),
      _ChatMessage(fromUser: false, text: 'chatbot.sample_answer'.tr()),
    ];
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(fromUser: true, text: text));
      _controller.clear();
      // Later we should call the chatbot API here and add a reply
    });
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;
    const background = Color(0xFF050608);
    const panelColor = Color(0xFF17191E);
    const accent = Color(0xFFF6B733);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: background,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'chatbot.title'.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: fs + 4,
                    ),
                  ),
                  const Icon(Icons.settings_outlined, color: Colors.white70),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _messages.length,
                        padding: const EdgeInsets.only(bottom: 12),
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final align = msg.fromUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft;
                          final bubbleColor = msg.fromUser
                              ? const Color(0xFF3B2B22)
                              : const Color(0xFF2A2D32);

                          return Align(
                            alignment: align,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: bubbleColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                msg.text,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: fs,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          _SuggestionChip(
                            label: 'chatbot.suggest_ritual'.tr(),
                            onTap: () => setState(
                              () => _messages.add(
                                _ChatMessage(
                                  fromUser: true,
                                  text: 'chatbot.next_ritual_q'.tr(),
                                ),
                              ),
                            ),
                          ),
                          _SuggestionChip(
                            label: 'chatbot.suggest_prayer'.tr(),
                            onTap: () => setState(
                              () => _messages.add(
                                _ChatMessage(
                                  fromUser: true,
                                  text: 'chatbot.prayer_times_q'.tr(),
                                ),
                              ),
                            ),
                          ),
                          _SuggestionChip(
                            label: 'chatbot.suggest_location'.tr(),
                            onTap: () => setState(
                              () => _messages.add(
                                _ChatMessage(
                                  fromUser: true,
                                  text: 'chatbot.location_q'.tr(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: TextStyle(color: Colors.white, fontSize: fs),
                            decoration: InputDecoration(
                              hintText: 'chatbot.ask_placeholder'.tr(),
                              hintStyle: TextStyle(
                                color: Colors.white54,
                                fontSize: fs,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF101218),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.black,
                            ),
                            onPressed: _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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

  const _ChatMessage({required this.fromUser, required this.text});
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF101218),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
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

    if (doc.exists)
      setState(() => _volunteerName = doc.data()?['name'] as String?);
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    const background = Color(0xFF050608);
    const bottomBarColor = Color(0xFF121317);
    const accent = Color(0xFFF6B733);

    final pages = <Widget>[
      _VolunteerHomeTab(volunteerName: _volunteerName),
      const VolunteerRequestsTab(),
      const _VolunteerChatsTab(),
      _PlaceholderTab(title: 'nav.map'.tr()),
      const _VolunteerSettingsTab(),
    ];

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
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
            icon: const Icon(Icons.assignment_rounded),
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
      ),
    );
  }
}

// =============================================================================
// VOLUNTEER HOME TAB
// =============================================================================
class _VolunteerHomeTab extends StatelessWidget {
  final String? volunteerName;

  const _VolunteerHomeTab({this.volunteerName});

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;
    const cardColor = Color(0xFF17191E);
    const accent = Color(0xFFF6B733);

    final displayName = volunteerName ?? 'Volunteer';

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
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle,
                            color: Colors.green,
                            size: 8,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'volunteer_home.active'.tr(),
                            style: TextStyle(
                              color: Colors.green,
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

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people_rounded,
                  label: 'volunteer_home.pilgrims_helped'.tr(),
                  value: '0',
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_rounded,
                  label: 'volunteer_home.requests_completed'.tr(),
                  value: '0',
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Active requests section
          Text(
            'volunteer_home.active_requests'.tr(),
            style: TextStyle(
              color: Colors.white,
              fontSize: fs + 4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 48,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'volunteer_home.no_requests'.tr(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: fs,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'volunteer_home.no_requests_subtitle'.tr(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: fs - 2,
                  ),
                  textAlign: TextAlign.center,
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
