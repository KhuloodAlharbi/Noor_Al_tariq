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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _roleLabel {
    if (widget.role == 'hajj_performer') return 'Hajj Performer';
    if (widget.role == 'volunteer') return 'Volunteer';
    return widget.role;
  }

  String get _titleText {
    final action = _isLogin ? 'Login' : 'Sign Up';
    return '$action as $_roleLabel';
  }

  String get _switchText {
    return _isLogin
        ? "Don't have an account? Sign up"
        : "Already have an account? Login";
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
        _errorMessage =
            e.message ?? 'Authentication error (${e.code}), please try again.';
      });
    } catch (e) {
      print('UNEXPECTED LOGIN ERROR: $e');
      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================================
  // SIGNUP - MODIFIED to handle volunteer flow
  // =========================================================================
  Future<void> _signup() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
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
        _errorMessage = e.message ?? 'Something went wrong during sign up.';
      });
    } catch (e) {
      print('UNEXPECTED SIGNUP ERROR: $e');
      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
    const accent = Color(0xFFC9973A);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4EF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E)),
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
                  side: const BorderSide(color: Color(0xFFE8E4DE)),
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
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Using your Noor Al-Tariq account',
                          style: TextStyle(
                            fontSize: 13,
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
                              color: accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: accent.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'After signing up, you\'ll complete an application form for admin review.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B6B80),
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
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
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
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) {
                                    if (_isLogin) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your full name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],

                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              if (!_isLogin) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Confirm Password',
                                    prefixIcon: Icon(Icons.lock_outline),
                                  ),
                                  validator: (value) {
                                    if (_isLogin) return null;
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
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
                                    backgroundColor: accent,
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
                                          ),
                                        )
                                      : Text(
                                          _isLogin ? 'Login' : 'Sign Up',
                                          style: const TextStyle(
                                            fontSize: 16,
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
                                  style: const TextStyle(fontSize: 13),
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
