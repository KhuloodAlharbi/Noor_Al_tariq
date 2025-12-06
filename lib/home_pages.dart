// =============================================================================
// FILE: home_pages.dart
// DESCRIPTION: Home pages for both Hajj Performers and Volunteers
// MERGED: Original Hajj home UI + New Volunteer home with bottom nav
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:intl/intl.dart';

import 'role_selection_page.dart';

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
        displayName = 'Fajr';
        break;
      case Prayer.sunrise:
        displayName = 'Sunrise';
        break;
      case Prayer.dhuhr:
        displayName = 'Dhuhr';
        break;
      case Prayer.asr:
        displayName = 'Asr';
        break;
      case Prayer.maghrib:
        displayName = 'Maghrib';
        break;
      case Prayer.isha:
        displayName = 'Isha';
        break;
      default:
        displayName = 'Next Prayer';
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
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF050608);
    const cardColor = Color(0xFF17191E);
    const bottomBarColor = Color(0xFF121317);
    const accent = Color(0xFFF6B733);

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
      const _PlaceholderTab(title: 'Prayers / Rituals'),
      const _ChatbotTab(),
      const _PlaceholderTab(title: 'Map'),
      const _HajjSettingsTab(),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule_rounded),
            label: 'Prayers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_rounded),
            label: 'Chatbot',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Dua',
                  style: TextStyle(
                    color: Color(0xFFF6B733),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً '
                  'وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'Rabbana atina fi d-dunya hasanatan wa fil-akhirati '
                  'hasanatan wa qina adhaban-naar.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Ritual',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tawaf al-Qudum',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Masjid al-Haram, Makkah',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Guide',
                        style: TextStyle(
                          color: Color(0xFFF6B733),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your Hajj companion is ready.\nAsk anything you need.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
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
    final name = nextPrayerName ?? 'Next Prayer';
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
            const Text(
              'Next Prayer',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeStr,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'in $remaining',
              style: const TextStyle(
                color: Color(0xFFF6B733),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Makkah time',
              style: TextStyle(color: Colors.white54, fontSize: 12),
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
                    const Text(
                      'Noor Al-Tariq',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Welcome, $displayName',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
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
                child: const Text(
                  'EN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: SOS request screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'SOS   Request Help',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
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

  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      fromUser: false,
      text:
          'As-salamu alaykum. I am your personal Hajj companion. How may I assist you today?',
    ),
    const _ChatMessage(fromUser: true, text: 'What is the next ritual?'),
    const _ChatMessage(
      fromUser: false,
      text:
          'The next ritual is Tawaf al-Ifadah. It is a mandatory part of Hajj.',
    ),
  ];

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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AI Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  Icon(Icons.settings_outlined, color: Colors.white70),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
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
                            label: 'What is the next ritual?',
                            onTap: () {
                              setState(() {
                                _messages.add(
                                  const _ChatMessage(
                                    fromUser: true,
                                    text: 'What is the next ritual?',
                                  ),
                                );
                              });
                            },
                          ),
                          _SuggestionChip(
                            label: 'Prayer times',
                            onTap: () {
                              setState(() {
                                _messages.add(
                                  const _ChatMessage(
                                    fromUser: true,
                                    text: 'What are the prayer times?',
                                  ),
                                );
                              });
                            },
                          ),
                          _SuggestionChip(
                            label: 'Where am I?',
                            onTap: () {
                              setState(() {
                                _messages.add(
                                  const _ChatMessage(
                                    fromUser: true,
                                    text: 'Where am I now?',
                                  ),
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Ask a question...',
                              hintStyle: const TextStyle(color: Colors.white54),
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
    return Center(
      child: Text(
        '$title\n(Coming soon)',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 18),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050608),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Logout button
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Log Out',
                  style: TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
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

    if (doc.exists) {
      setState(() {
        _volunteerName = doc.data()?['name'] as String?;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF050608);
    const bottomBarColor = Color(0xFF121317);
    const accent = Color(0xFFF6B733);

    final pages = <Widget>[
      _VolunteerHomeTab(volunteerName: _volunteerName),
      const _PlaceholderTab(title: 'Help Requests'),
      const _PlaceholderTab(title: 'Chat'),
      const _PlaceholderTab(title: 'Map'),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_rounded),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
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
                          const Text(
                            'Noor Al-Tariq',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Welcome, $displayName',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            color: Colors.green,
                            size: 8,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
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
                  label: 'Pilgrims Helped',
                  value: '0',
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Requests Completed',
                  value: '0',
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Active requests section
          const Text(
            'Active Requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
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
                  'No active requests',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Help requests from pilgrims will appear here',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 12,
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
    const cardColor = Color(0xFF17191E);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// VOLUNTEER SETTINGS TAB
// =============================================================================
class _VolunteerSettingsTab extends StatefulWidget {
  const _VolunteerSettingsTab();

  @override
  State<_VolunteerSettingsTab> createState() => _VolunteerSettingsTabState();
}

class _VolunteerSettingsTabState extends State<_VolunteerSettingsTab> {
  bool _isAvailable = true;

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF17191E);
    const accent = Color(0xFFF6B733);

    return Scaffold(
      backgroundColor: const Color(0xFF050608),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Availability toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: accent,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Availability',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Toggle to receive help requests',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isAvailable,
                      onChanged: (value) {
                        setState(() {
                          _isAvailable = value;
                        });
                      },
                      activeColor: accent,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Logout button
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RoleSelectionPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}