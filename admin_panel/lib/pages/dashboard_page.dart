// =============================================================================
// FILE: admin_panel/lib/pages/dashboard_page.dart
// DESCRIPTION: Main dashboard – light / warm theme matching the mobile app
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart'; // AppColors
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
  int    _selectedIndex    = 0;
  String? _adminName;
  String? _adminEmail;
  bool   _isVerifyingAdmin = true;
  bool   _isAdmin          = false;

  @override
  void initState() {
    super.initState();
    _verifyAdminAndLoadProfile();
  }

  Future<void> _verifyAdminAndLoadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _signOut(); return; }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) { _signOut(); return; }

      final userData = userDoc.data()!;
      final isAdmin  = userData['isAdmin'] as bool? ?? false;
      if (!isAdmin)  { _signOut(); return; }

      if (mounted) {
        setState(() {
          _isAdmin          = true;
          _isVerifyingAdmin = false;
          _adminName        = userData['name'] as String? ?? 'Admin';
          _adminEmail       = user.email;
        });
      }
    } catch (e) {
      debugPrint('Error verifying admin: $e');
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
    if (_isVerifyingAdmin) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text(
                'Verifying admin access...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Access denied', style: TextStyle(color: Colors.red)),
        ),
      );
    }

    final pages = <Widget>[
      _DashboardHome(),
      const PendingVolunteersPage(),
      const ApprovedVolunteersPage(),
      const DeclinedVolunteersPage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: AppColors.sidebar,
              border: Border(
                right: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Column(
              children: [
                // Logo header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:        AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.brightness_2_rounded,
                          color: AppColors.accent,
                          size:  24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Noor Al-Tariq',
                            style: TextStyle(
                              fontSize:   16,
                              fontWeight: FontWeight.bold,
                              color:      AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Admin Panel',
                            style: TextStyle(
                              fontSize: 12,
                              color:    AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(color: AppColors.divider, height: 1),

                // Nav items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _NavItem(
                        icon:       Icons.dashboard_rounded,
                        label:      'Dashboard',
                        isSelected: _selectedIndex == 0,
                        onTap:      () => setState(() => _selectedIndex = 0),
                      ),
                      _NavItem(
                        icon:       Icons.pending_actions_rounded,
                        label:      'Pending Requests',
                        isSelected: _selectedIndex == 1,
                        onTap:      () => setState(() => _selectedIndex = 1),
                        badge:      _PendingCountBadge(),
                      ),
                      _NavItem(
                        icon:       Icons.check_circle_outline,
                        label:      'Approved Volunteers',
                        isSelected: _selectedIndex == 2,
                        onTap:      () => setState(() => _selectedIndex = 2),
                      ),
                      _NavItem(
                        icon:       Icons.cancel_outlined,
                        label:      'Declined Requests',
                        isSelected: _selectedIndex == 3,
                        onTap:      () => setState(() => _selectedIndex = 3),
                      ),
                    ],
                  ),
                ),

                // Admin profile footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius:          18,
                        backgroundColor: AppColors.accent.withOpacity(0.15),
                        child:           const Icon(Icons.person, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _adminName ?? 'Admin',
                              style: const TextStyle(
                                fontSize:   13,
                                fontWeight: FontWeight.w600,
                                color:      AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_adminEmail != null)
                              Text(
                                _adminEmail!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color:    AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon:    const Icon(Icons.logout, color: AppColors.textSecondary, size: 20),
                        onPressed: _signOut,
                        tooltip: 'Sign Out',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
    );
  }
}

// ── Nav item ─────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final bool       isSelected;
  final VoidCallback onTap;
  final Widget?    badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color:        isSelected ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:        onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
                  size:  20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color:      isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize:   14,
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

// ── Pending count badge ───────────────────────────────────────────────────────
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
            color:        Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}

// ── Dashboard home content ────────────────────────────────────────────────────
class _DashboardHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize:   26,
              fontWeight: FontWeight.bold,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Welcome to the Noor Al-Tariq Admin Panel',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),

          // Stat cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title:  'Pending Requests',
                  icon:   Icons.pending_actions_rounded,
                  color:  const Color(0xFFF59E0B),
                  stream: FirebaseFirestore.instance
                      .collection('volunteer_applications')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title:  'Approved Volunteers',
                  icon:   Icons.check_circle_outline,
                  color:  const Color(0xFF10B981),
                  stream: FirebaseFirestore.instance
                      .collection('volunteer_applications')
                      .where('status', isEqualTo: 'approved')
                      .snapshots(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title:  'Declined Requests',
                  icon:   Icons.cancel_outlined,
                  color:  const Color(0xFFEF4444),
                  stream: FirebaseFirestore.instance
                      .collection('volunteer_applications')
                      .where('status', isEqualTo: 'declined')
                      .snapshots(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title:  'Total Users',
                  icon:   Icons.people_outline,
                  color:  AppColors.accent,
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Recent pending
          const Text(
            'Recent Pending Requests',
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.w600,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color:        AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: AppColors.cardBorder),
            ),
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
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
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
                            size:  48,
                            color: AppColors.textSecondary.withOpacity(0.4),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No pending requests',
                            style: TextStyle(
                              color:    AppColors.textSecondary,
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
                  physics:    const NeverScrollableScrollPhysics(),
                  itemCount:  docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final data      = docs[index].data() as Map<String, dynamic>;
                    final name      = data['fullName'] as String? ?? 'Unknown';
                    final email     = data['email']    as String? ?? '';
                    final expertise = (data['expertiseAreas'] as List?)
                            ?.map((e) => e.toString())
                            .join(', ') ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.accent.withOpacity(0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color:      AppColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color:      AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '$email • $expertise',
                        style: const TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:        const Color(0xFFF59E0B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(
                            color:      Color(0xFFD97706),
                            fontSize:   12,
                            fontWeight: FontWeight.w600,
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

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String                 title;
  final IconData               icon;
  final Color                  color;
  final Stream<QuerySnapshot>  stream;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: stream,
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize:   28,
                      fontWeight: FontWeight.bold,
                      color:      color,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}