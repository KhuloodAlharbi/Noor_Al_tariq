// =============================================================================
// FILE: auth_page.dart
// DESCRIPTION: Authentication page - MODIFIED for new volunteer flow
// CHANGES:
//   - After volunteer signup/login, redirect to VolunteerApplicationPage
//   - Check if volunteer already has application submitted
//   - Handle pending/approved/declined states
//   - Added _checkVolunteerStatusAndNavigate() method
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'app_settings_provider.dart';
import 'home_pages.dart';
import 'volunteer_application_page.dart';
import 'pending_approval_page.dart';

class AuthPage extends StatefulWidget {
  final String role; // 'hajj_performer' or 'volunteer'

  const AuthPage({super.key, required this.role});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Start in SIGN UP mode
  bool _isLogin = false;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  static const Color _background = Color(0xFFF7F4EF);
  static const Color _textColor = Color(0xFF1A1A2E);
  static const Color _mutedColor = Color(0xFF6B6B80);
  static const Color _borderColor = Color(0xFFE8E4DE);
  static const Color _accent = Color(0xFFC9973A);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _roleLabel {
    if (widget.role == 'hajj_performer') return 'auth.role_hajj'.tr();
    if (widget.role == 'volunteer') return 'auth.role_volunteer'.tr();
    return widget.role;
  }

  String get _titleText {
    return _isLogin
        ? 'auth.login_as'.tr(namedArgs: {'role': _roleLabel})
        : 'auth.signup_as'.tr(namedArgs: {'role': _roleLabel});
  }

  String get _switchText {
    return _isLogin
        ? 'auth.no_account'.tr()
        : 'auth.already_have_account'.tr();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLogin) {
      await _login();
    } else {
      await _signup();
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });
  }

  // =========================================================================
  // LOGIN - MODIFIED to handle volunteer flow
  // =========================================================================
  Future<void> _login() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 1) Sign in with Firebase Auth
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = cred.user!.uid;

      // 2) Read or create Firestore user doc
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await docRef.get();

      String role;

      if (!doc.exists) {
        // First time: create Firestore profile with selected role
        role = widget.role;
        await docRef.set({
          'email': _emailController.text.trim(),
          'role': role,
          'isVolunteer': false, // NEW: Default to false
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = doc.data();
        final existingRole = data?['role'] as String?;

        if (existingRole == null) {
          role = widget.role;
          await docRef.update({
            'role': role,
            'isVolunteer': false,
          });
        } else {
          role = existingRole;
        }
      }

      // 3) Navigate based on role
      await _navigateByRole(role, uid);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'errors.auth_generic'.tr();
      });
    } catch (e) {
      debugPrint('UNEXPECTED LOGIN ERROR: $e');
      setState(() {
        _errorMessage = 'errors.unexpected'.tr();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // =========================================================================
  // SIGNUP - MODIFIED to handle volunteer flow
  // =========================================================================
  Future<void> _signup() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'errors.passwords_mismatch'.tr();
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 1) Create user in Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = cred.user!.uid;

      // 2) Save basic user info + role in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': widget.role,
        'isVolunteer': false, // NEW: Default to false until approved
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3) Navigate based on role
      await _navigateByRole(widget.role, uid);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'errors.auth_generic'.tr();
      });
    } catch (e) {
      debugPrint('UNEXPECTED SIGNUP ERROR: $e');
      setState(() {
        _errorMessage = 'errors.unexpected'.tr();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // =========================================================================
  // NEW: Navigate based on role - handles volunteer application flow
  // =========================================================================
  Future<void> _navigateByRole(String role, String uid) async {
    Widget page;

    if (role == 'hajj_performer') {
      // Hajj performer - go directly to home
      page = const HajjHomePage();
    } else if (role == 'volunteer') {
      // MODIFIED: Check volunteer application status
      page = await _checkVolunteerStatusAndGetPage(uid);
    } else {
      // Unknown role - default to Hajj home
      page = const HajjHomePage();
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  // =========================================================================
  // NEW: Check volunteer application status and return appropriate page
  // =========================================================================
  Future<Widget> _checkVolunteerStatusAndGetPage(String uid) async {
    final firestore = FirebaseFirestore.instance;

    // Check if user is already an approved volunteer
    final userDoc = await firestore.collection('users').doc(uid).get();
    final userData = userDoc.data();
    final isVolunteer = userData?['isVolunteer'] as bool? ?? false;

    if (isVolunteer) {
      // Already approved - go to volunteer home
      return const VolunteerHomePage();
    }

    // Check for existing application
    final appDoc = await firestore
        .collection('volunteer_applications')
        .doc(uid)
        .get();

    if (!appDoc.exists) {
      // No application yet - redirect to application form
      return const VolunteerApplicationPage();
    }

    final appData = appDoc.data()!;
    final status = appData['status'] as String?;

    switch (status) {
      case 'approved':
        // This shouldn't happen if isVolunteer is properly set
        // Update the user doc and go to volunteer home
        await firestore.collection('users').doc(uid).update({
          'isVolunteer': true,
        });
        return const VolunteerHomePage();

      case 'declined':
        // Show declined page with reason and option to reapply
        return PendingApprovalPage(
          status: 'declined',
          declineReason: appData['declineReason'] as String?,
        );

      case 'pending':
      default:
        // Show pending approval page
        return const PendingApprovalPage(status: 'pending');
    }
  }

  // =========================================================================
  // UI - Same as before with minor text updates
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final fs = context.watch<AppSettingsProvider>().fontSize;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _textColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: _borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // Logo
                      Image.asset(
                        'assets/images/logo.png',
                        height: 56,
                      ),
                      const SizedBox(height: 12),

                        // Title
                      Text(
                        _titleText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fs + 8,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'auth.account_subtitle'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fs - 1,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.65),
                        ),
                      ),

                        // NEW: Info for volunteers
                      if (widget.role == 'volunteer') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _accent.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: _accent,
                                size: fs + 6,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'auth.volunteer_info'.tr(),
                                  style: TextStyle(
                                    fontSize: fs - 2,
                                    color: _mutedColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                        // Error message
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: fs - 1,
                            ),
                          ),
                        ),
                      ],

                        // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                              // Full Name only in Sign Up mode
                            if (!_isLogin) ...[
                              TextFormField(
                                controller: _nameController,
                                style: TextStyle(fontSize: fs),
                                decoration: InputDecoration(
                                  labelText: 'auth.full_name'.tr(),
                                  prefixIcon:
                                      const Icon(Icons.person_outline),
                                ),
                                validator: (value) {
                                  if (_isLogin) return null;

                                  if (value == null || value.trim().isEmpty) {
                                    return 'errors.name_required'.tr();
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(fontSize: fs),
                              decoration: InputDecoration(
                                labelText: 'auth.email'.tr(),
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'errors.email_required'.tr();
                                }

                                if (!value.contains('@')) {
                                  return 'errors.email_invalid'.tr();
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: TextStyle(fontSize: fs),
                              decoration: InputDecoration(
                                labelText: 'auth.password'.tr(),
                                prefixIcon: const Icon(Icons.lock_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'errors.password_required'.tr();
                                }

                                if (value.length < 6) {
                                  return 'errors.password_short'.tr();
                                }

                                return null;
                              },
                            ),

                            if (!_isLogin) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: true,
                                style: TextStyle(fontSize: fs),
                                decoration: InputDecoration(
                                  labelText: 'auth.confirm_password'.tr(),
                                  prefixIcon:
                                      const Icon(Icons.lock_outline),
                                ),
                                validator: (value) {
                                  if (_isLogin) return null;

                                  if (value == null || value.isEmpty) {
                                    return 'errors.password_confirm'.tr();
                                  }

                                  if (value != _passwordController.text) {
                                    return 'errors.passwords_mismatch'.tr();
                                  }

                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  backgroundColor: _accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _isLogin
                                            ? 'auth.login'.tr()
                                            : 'auth.signup'.tr(),
                                        style: TextStyle(
                                          fontSize: fs + 2,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            TextButton(
                              onPressed: _isLoading ? null : _toggleMode,
                              child: Text(
                                _switchText,
                                style: TextStyle(fontSize: fs - 1),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
