// =============================================================================
// FILE: admin_panel/lib/pages/login_page.dart
// DESCRIPTION: Admin login page – light / warm theme matching the mobile app
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart'; // AppColors
import 'dashboard_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey        = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  bool   _isLoading       = false;
  String? _errorMessage;
  bool   _obscurePassword  = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid     = cred.user!.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        setState(() => _errorMessage = 'Access denied. User not found in database.');
        return;
      }

      final isAdmin = userDoc.data()!['isAdmin'] as bool? ?? false;
      if (!isAdmin) {
        await FirebaseAuth.instance.signOut();
        setState(() => _errorMessage = 'Access denied. You are not authorized as an admin.');
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _getAuthErrorMessage(e.code));
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':   return 'No account found with this email.';
      case 'wrong-password':   return 'Incorrect password.';
      case 'invalid-email':    return 'Invalid email address.';
      case 'user-disabled':    return 'This account has been disabled.';
      case 'too-many-requests': return 'Too many attempts. Please try again later.';
      default:                 return 'Authentication failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F0E8), Color(0xFFEDE5D5)],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo ────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color:  AppColors.accent.withOpacity(0.15),
                      shape:  BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size:  64,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Noor Al-Tariq',
                    style: TextStyle(
                      fontSize:   28,
                      fontWeight: FontWeight.bold,
                      color:      AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 16,
                      color:    AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Login card ──────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color:        AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset:     const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize:   22,
                                fontWeight: FontWeight.bold,
                                color:      AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Enter your admin credentials to continue',
                              style: TextStyle(
                                color:    AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Error banner
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:        Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border:       Border.all(color: Colors.red.withOpacity(0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(color: Colors.red, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email
                            TextFormField(
                              controller:   _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                labelText:   'Email',
                                prefixIcon:  Icon(Icons.email_outlined, color: AppColors.textSecondary),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Please enter your email';
                                if (!v.contains('@')) return 'Please enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password
                            TextFormField(
                              controller:  _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                labelText:  'Password',
                                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Please enter your password';
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // Sign-in button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const SizedBox(
                                        width:  22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize:   16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Only authorized administrators can access this dashboard.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}