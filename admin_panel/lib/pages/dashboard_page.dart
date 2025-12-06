// =============================================================================
// FILE: admin_panel/lib/pages/dashboard_page.dart
// DESCRIPTION: Main dashboard with sidebar navigation
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_page.dart';
import 'pending_volunteers_page.dart';
import 'approved_volunteers_page.dart';
import 'declined_volunteers_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  String? _adminName;
  String? _adminEmail;
  bool _isVerifyingAdmin = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _verifyAdminAndLoadProfile();
  }

  Future<void> _verifyAdminAndLoadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _signOut();
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        _signOut();
        return;
      }

      final userData = userDoc.data()!;
      final isAdmin = userData['isAdmin'] as bool? ?? false;

      if (!isAdmin) {
        _signOut();
        return;
      }

      if (mounted) {
        setState(() {
          _isAdmin = true;
          _isVerifyingAdmin = false;
          _adminName = userData['name'] as String? ?? 'Admin';
          _adminEmail = user.email;
        });
      }
    } catch (e) {
      print('Error verifying admin: $e');
      _signOut();
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).colorScheme.surface;

    if (_isVerifyingAdmin) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Verifying admin access...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access denied',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    // Define pages
    final pages = <Widget>[
      _DashboardHome(accent: accent, cardColor: cardColor),
      const PendingVolunteersPage(),
      const ApprovedVolunteersPage(),
      const DeclinedVolunteersPage(),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            color: cardColor,
            child: Column(
              children: [
                // Logo header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.brightness_2_rounded,
                          color: accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Noor Al-Tariq',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Admin Panel',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12, height: 1),

                // Navigation items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _NavItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        isSelected: _selectedIndex == 0,
                        onTap: () => setState(() => _selectedIndex = 0),
                        accent: accent,
                      ),
                      _NavItem(
                        icon: Icons.pending_actions_rounded,
                        label: 'Pending Requests',
                        isSelected: _selectedIndex == 1,
                        onTap: () => setState(() => _selectedIndex = 1),
                        accent: accent,
                        badge: _PendingCountBadge(),
                      ),
                      _NavItem(
                        icon: Icons.check_circle_outline,
                        label: 'Approved Volunteers',
                        isSelected: _selectedIndex == 2,
                        onTap: () => setState(() => _selectedIndex = 2),
                        accent: accent,
                      ),
                      _NavItem(
                        icon: Icons.cancel_outlined,
                        label: 'Declined Requests',
                        isSelected: _selectedIndex == 3,
                        onTap: () => setState(() => _selectedIndex = 3),
                        accent: accent,
                      ),
                    ],
                  ),
                ),

                // Admin profile footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: accent.withOpacity(0.2),
                        child: Icon(
                          Icons.person,
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
                              _adminName ?? 'Admin',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_adminEmail != null)
                              Text(
                                _adminEmail!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white54,
                          size: 20,
                        ),
                        onPressed: _signOut,
                        tooltip: 'Sign Out',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

// Navigation item widget
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accent;
  final Widget? badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.accent,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? accent.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? accent : Colors.white54,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (badge != null) badge!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Pending count badge widget
class _PendingCountBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('volunteer_applications')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final count = snapshot.data!.docs.length;
        if (count == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

// Dashboard home content
class _DashboardHome extends StatelessWidget {
  final Color accent;
  final Color cardColor;

  const _DashboardHome({required this.accent, required this.cardColor});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome to the Noor Al-Tariq Admin Panel',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          // Stats cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Pending Requests',
                  icon: Icons.pending_actions_rounded,
                  color: Colors.orange,
                  stream: FirebaseFirestore.instance
                      .collection('volunteer_applications')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Approved Volunteers',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  stream: FirebaseFirestore.instance
                      .collection('volunteer_applications')
                      .where('status', isEqualTo: 'approved')
                      .snapshots(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Declined Requests',
                  icon: Icons.cancel_outlined,
                  color: Colors.red,
                  stream: FirebaseFirestore.instance
                      .collection('volunteer_applications')
                      .where('status', isEqualTo: 'declined')
                      .snapshots(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Total Users',
                  icon: Icons.people_outline,
                  color: accent,
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Recent pending requests
          const Text(
            'Recent Pending Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('volunteer_applications')
                  .where('status', isEqualTo: 'pending')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
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
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No pending requests',
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

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: Colors.white12,
                  ),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final name = data['fullName'] as String? ?? 'Unknown';
                    final email = data['email'] as String? ?? '';
                    final expertise = (data['expertiseAreas'] as List?)
                            ?.map((e) => e.toString())
                            .join(', ') ??
                        '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accent.withOpacity(0.2),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        '$email • $expertise',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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
    );
  }
}

// Stat card widget
class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot> stream;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: stream,
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
