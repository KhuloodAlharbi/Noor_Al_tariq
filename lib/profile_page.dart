// =============================================================================
// FILE: lib/profile_page.dart
// DESCRIPTION: Personal data only — FR2.1, FR2.3, FR2.4, FR2.5
//              Language (FR2.2), Font Size (FR2.6), Notifications (FR2.7)
//              have been moved to the Settings tab in home_pages.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'app_settings_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController                  = TextEditingController();
  final _ageController                   = TextEditingController();
  final _healthController                = TextEditingController();
  final _emergencyNameController         = TextEditingController();
  final _emergencyPhoneController        = TextEditingController();
  final _emergencyRelationController     = TextEditingController();

  bool    _isLoading = true;
  bool    _isSaving  = false;
  String? _errorMessage;
  String? _successMessage;
  String? _selectedNationality;
  String? _selectedMobility;
  String? _selectedCampaign;

  // ── lookup tables ──────────────────────────────────────────────────────────
  static const _natKeys = [
    'saudi_arabia','egypt','pakistan','indonesia','malaysia','turkey',
    'iran','nigeria','bangladesh','india','jordan','morocco','sudan','algeria','other',
  ];
  static const _natVals = [
    'Saudi Arabia','Egypt','Pakistan','Indonesia','Malaysia','Turkey',
    'Iran','Nigeria','Bangladesh','India','Jordan','Morocco','Sudan','Algeria','Other',
  ];
  static const _mobKeys = ['none','wheelchair','walking_aid','visual','hearing','full'];
  static const _mobVals = [
    'None required','Wheelchair','Walking aid / crutches',
    'Visual impairment assistance','Hearing impairment assistance',
    'Full mobility assistance required',
  ];
  static const _camKeys = ['a','b','c','vip','gov','private'];
  static const _camVals = [
    'Hajj 1446 - Campaign A','Hajj 1446 - Campaign B','Hajj 1446 - Campaign C',
    'VIP Hajj 1446','Institutional Hajj - Government','Institutional Hajj - Private',
  ];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    for (final c in [_nameController, _ageController, _healthController,
      _emergencyNameController, _emergencyPhoneController, _emergencyRelationController]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Firestore load ─────────────────────────────────────────────────────────
  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _isLoading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final d = doc.data()!;
        final emg = d['emergencyContact'] as Map<String, dynamic>? ?? {};
        setState(() {
          _nameController.text                  = d['name']             as String? ?? '';
          _ageController.text                   = (d['age'] ?? '').toString();
          _healthController.text                = d['healthConditions'] as String? ?? '';
          _selectedNationality                  = d['nationality']      as String?;
          _selectedMobility                     = d['mobilityAssistance'] as String?;
          _selectedCampaign                     = d['campaign']         as String?;
          _emergencyNameController.text         = emg['name']     as String? ?? '';
          _emergencyPhoneController.text        = emg['phone']    as String? ?? '';
          _emergencyRelationController.text     = emg['relation'] as String? ?? '';
        });
      }
    } catch (_) {
      setState(() => _errorMessage = 'errors.load_profile'.tr());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Firestore save ─────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() { _isSaving = true; _errorMessage = null; _successMessage = null; });
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name':               _nameController.text.trim(),
        'age':                int.tryParse(_ageController.text.trim()),
        'healthConditions':   _healthController.text.trim(),
        'nationality':        _selectedNationality,
        'mobilityAssistance': _selectedMobility,
        'campaign':           _selectedCampaign,
        'emergencyContact': {
          'name':     _emergencyNameController.text.trim(),
          'phone':    _emergencyPhoneController.text.trim(),
          'relation': _emergencyRelationController.text.trim(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _successMessage = 'profile.saved'.tr());
    } catch (_) {
      setState(() => _errorMessage = 'errors.save_profile'.tr());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settings   = context.watch<AppSettingsProvider>();
    const bg         = Color(0xFF050608);
    const accent     = Color(0xFFF6B733);
    const cardColor  = Color(0xFF17191E);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('profile.title'.tr()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ── avatar + name header ──────────────────────────────
                    _buildHeader(accent, cardColor, settings),
                    const SizedBox(height: 16),

                    if (_errorMessage   != null) _alert(_errorMessage!,   Colors.red,   settings),
                    if (_successMessage != null) _alert(_successMessage!, Colors.green, settings),

                    // FR2.1 — Personal Info
                    _section(cardColor, accent, Icons.person_rounded,
                        'profile.personal_section'.tr(), settings,
                        Column(children: [
                          _field(_nameController, 'profile.full_name'.tr(),
                              Icons.badge_rounded, settings,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'errors.name_required'.tr() : null),
                          const SizedBox(height: 12),
                          _field(_ageController, 'profile.age'.tr(),
                              Icons.cake_rounded, settings,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final a = int.tryParse(v.trim());
                                return (a == null || a < 1 || a > 120)
                                    ? 'errors.age_invalid'.tr() : null;
                              }),
                          const SizedBox(height: 12),
                          _dropdown('profile.nationality'.tr(), Icons.flag_rounded,
                              _selectedNationality,
                              List.generate(_natKeys.length, (i) => ('profile.nationalities.${_natKeys[i]}'.tr(), _natVals[i])),
                              (v) => setState(() => _selectedNationality = v), settings),
                          const SizedBox(height: 12),
                          _field(_healthController, 'profile.health_conditions'.tr(),
                              Icons.health_and_safety_rounded, settings,
                              maxLines: 3, hint: 'profile.health_hint'.tr()),
                        ])),
                    const SizedBox(height: 16),

                    // FR2.3 — Mobility
                    _section(cardColor, accent, Icons.accessible_rounded,
                        'profile.mobility_section'.tr(), settings,
                        _dropdown('profile.mobility_placeholder'.tr(),
                            Icons.wheelchair_pickup_rounded, _selectedMobility,
                            List.generate(_mobKeys.length, (i) => ('profile.mobility_options.${_mobKeys[i]}'.tr(), _mobVals[i])),
                            (v) => setState(() => _selectedMobility = v), settings)),
                    const SizedBox(height: 16),

                    // FR2.4 — Campaign
                    _section(cardColor, accent, Icons.campaign_rounded,
                        'profile.campaign_section'.tr(), settings,
                        _dropdown('profile.campaign_placeholder'.tr(),
                            Icons.groups_rounded, _selectedCampaign,
                            List.generate(_camKeys.length, (i) => ('profile.campaigns.${_camKeys[i]}'.tr(), _camVals[i])),
                            (v) => setState(() => _selectedCampaign = v), settings)),
                    const SizedBox(height: 16),

                    // FR2.5 — Emergency Contact
                    _section(cardColor, accent, Icons.emergency_rounded,
                        'profile.emergency_section'.tr(), settings,
                        Column(children: [
                          _field(_emergencyNameController, 'profile.emergency_name'.tr(),
                              Icons.person_pin_rounded, settings,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'errors.emergency_name_required'.tr() : null),
                          const SizedBox(height: 12),
                          _field(_emergencyPhoneController, 'profile.emergency_phone'.tr(),
                              Icons.phone_rounded, settings,
                              keyboardType: TextInputType.phone,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'errors.emergency_phone_required'.tr() : null),
                          const SizedBox(height: 12),
                          _field(_emergencyRelationController, 'profile.emergency_relation'.tr(),
                              Icons.family_restroom_rounded, settings,
                              hint: 'profile.emergency_relation_hint'.tr()),
                        ])),
                    const SizedBox(height: 32),

                    // Save
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent, foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : Text('profile.save_button'.tr(),
                                style: TextStyle(fontSize: settings.fontSize + 2,
                                    fontWeight: FontWeight.w700, color: Colors.black)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Avatar header ──────────────────────────────────────────────────────────
  Widget _buildHeader(Color accent, Color cardColor, AppSettingsProvider settings) {
    final name = _nameController.text.trim();
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join()
        : '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: accent.withOpacity(0.2),
          child: Text(initials, style: TextStyle(
              color: accent, fontSize: settings.fontSize + 6, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isNotEmpty ? name : 'profile.full_name'.tr(),
              style: TextStyle(color: Colors.white, fontSize: settings.fontSize + 4,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(FirebaseAuth.instance.currentUser?.email ?? '',
              style: TextStyle(color: Colors.white54, fontSize: settings.fontSize - 2)),
        ])),
      ]),
    );
  }

  // ── Reusable widgets ───────────────────────────────────────────────────────
  Widget _section(Color cardColor, Color accent, IconData icon,
      String title, AppSettingsProvider settings, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: accent,
              fontSize: settings.fontSize - 1, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      AppSettingsProvider settings, {
        String? hint, int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: ctrl, maxLines: maxLines, keyboardType: keyboardType,
      style: TextStyle(color: Colors.white, fontSize: settings.fontSize),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: TextStyle(color: Colors.white70, fontSize: settings.fontSize),
        hintStyle: TextStyle(color: Colors.white38, fontSize: settings.fontSize),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        filled: true, fillColor: const Color(0xFF23252B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF6B733), width: 1.5)),
        errorStyle: TextStyle(fontSize: settings.fontSize - 2, color: Colors.redAccent),
      ),
      validator: validator,
    );
  }

  Widget _dropdown(String label, IconData icon, String? value,
      List<(String, String)> items, void Function(String?) onChanged,
      AppSettingsProvider settings) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF23252B),
      style: TextStyle(color: Colors.white, fontSize: settings.fontSize),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70, fontSize: settings.fontSize),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        filled: true, fillColor: const Color(0xFF23252B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF6B733), width: 1.5)),
      ),
      items: items.map((item) => DropdownMenuItem<String>(
        value: item.$2,
        child: Text(item.$1, style: TextStyle(color: Colors.white, fontSize: settings.fontSize)),
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _alert(String msg, Color color, AppSettingsProvider settings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(color == Colors.red ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: TextStyle(color: color, fontSize: settings.fontSize - 1))),
      ]),
    );
  }
}
