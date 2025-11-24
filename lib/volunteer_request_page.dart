import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerRequestPage extends StatefulWidget {
  const VolunteerRequestPage({super.key});

  @override
  State<VolunteerRequestPage> createState() => _VolunteerRequestPageState();
}

class _VolunteerRequestPageState extends State<VolunteerRequestPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String _availability = 'available';

  // selections for expertise and languages
  final Map<String, bool> _expertise = {
    'medical': false,
    'navigation': false,
    'translation': false,
    'general_guidance': false,
  };

  final Map<String, bool> _languages = {
    'Arabic': false,
    'English': false,
    'Urdu': false,
    'Other': false,
  };

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedExpertise = _expertise.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final selectedLanguages = _languages.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedExpertise.isEmpty || selectedLanguages.isEmpty) {
      setState(() {
        _error = 'Please select at least one expertise and one language.';
      });
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
        _error = null;
      });

      await FirebaseFirestore.instance.collection('volunteer_requests').add({
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'expertiseAreas': selectedExpertise,
        'availabilityStatus': _availability,
        'languages': selectedLanguages,
        'status': 'pending', // pending | approved | rejected
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your request has been sent. You will be contacted after review.',
          ),
        ),
      );

      Navigator.pop(context); // back to role selection
    } catch (e) {
      setState(() {
        _error = 'Failed to submit request: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(title: const Text('Volunteer Access Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Request Volunteer Access',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Fill in your details. An admin will review your request '
                        'and contact you if approved.',
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          if (!v.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Expertise Areas ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: _expertise.keys.map((key) {
                          return FilterChip(
                            label: Text(key.replaceAll('_', ' ')),
                            selected: _expertise[key]!,
                            onSelected: (value) {
                              setState(() {
                                _expertise[key] = value;
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Availability Status ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _availability,
                        items: const [
                          DropdownMenuItem(
                            value: 'available',
                            child: Text('Available'),
                          ),
                          DropdownMenuItem(value: 'busy', child: Text('Busy')),
                          DropdownMenuItem(
                            value: 'offline',
                            child: Text('Offline'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _availability = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Languages Spoken',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: _languages.keys.map((key) {
                          return FilterChip(
                            label: Text(key),
                            selected: _languages[key]!,
                            onSelected: (value) {
                              setState(() {
                                _languages[key] = value;
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Submit Request',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
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
