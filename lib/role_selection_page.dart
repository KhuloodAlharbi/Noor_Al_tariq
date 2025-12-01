// =============================================================================
// FILE: role_selection_page.dart
// DESCRIPTION: Role selection page - MODIFIED for new volunteer flow
// CHANGES: 
//   - Both roles now go to AuthPage first (volunteer no longer skips auth)
//   - Removed direct navigation to VolunteerRequestPage
//   - Added visual distinction for the two paths
// =============================================================================

import 'package:flutter/material.dart';
import 'auth_page.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Noor Al-Tariq'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.brightness_2_rounded, size: 22), // moon icon
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Arabic greeting
            const Text(
              'السلام عليكم',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'How will you use Noor Al-Tariq?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Choose your role to personalize your experience.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Column(
                children: [
                  // HAJJ PERFORMER CARD
                  _RoleCard(
                    title: 'Hajj Performer',
                    subtitle: 'Navigation, duas, help requests and more.',
                    icon: Icons.mosque_rounded,
                    accent: accent,
                    cardColor: cardColor,
                    onTap: () {
                      // Navigate to auth page for hajj performer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AuthPage(role: 'hajj_performer'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // VOLUNTEER CARD - MODIFIED: Now goes to AuthPage first
                  _RoleCard(
                    title: 'Volunteer',
                    subtitle: 'Sign up to assist pilgrims after approval.',
                    icon: Icons.volunteer_activism_rounded,
                    accent: accent,
                    cardColor: cardColor,
                    // NEW: Show badge indicating approval required
                    badge: 'Approval Required',
                    onTap: () {
                      // MODIFIED: Navigate to auth page first, then application form
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AuthPage(role: 'volunteer'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Footer info
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Volunteers require admin approval before access.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MODIFIED: _RoleCard widget with optional badge
// =============================================================================
class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color cardColor;
  final VoidCallback onTap;
  final String? badge; // NEW: Optional badge text

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.cardColor,
    required this.onTap,
    this.badge, // NEW
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(width: 16),

              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with optional badge
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        // NEW: Badge for volunteer
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accent.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
