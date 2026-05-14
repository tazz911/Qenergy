// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../zones/manage_zones_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifs = true, _anomalyAlerts = true, _emailReports = false;

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final fullName = user?.fullName ?? '';
    final email = user?.email ?? '';
    final initials = fullName.isNotEmpty ? _initials(fullName) : '?';
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentBlue])),
                      child: Center(child: Text(initials, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fullName.isNotEmpty ? fullName : 'User', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text(email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        GestureDetector(onTap: () {},
                          child: const Text('Edit profile →', style: TextStyle(fontSize: 11, color: AppColors.accent))),
                      ]),
                    ),
                  ],
                ),
              ),
              _SectionLabel('Monitoring'),
              _SettingsGroup([
                _SettingsItem(Icons.business, 'Manage Buildings', onTap: () {}),
                _SettingsItem(Icons.grid_view, 'Manage Zones',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageZonesScreen()))),
                _SettingsItem(Icons.devices, 'Devices & Meters', onTap: () {}),
              ]),
              _SectionLabel('Notifications'),
              _SettingsGroup([
                _SettingsItem(Icons.notifications_outlined, 'Push Notifications',
                    trailing: _Toggle(value: _pushNotifs, onChanged: (v) => setState(() => _pushNotifs = v))),
                _SettingsItem(Icons.warning_amber_outlined, 'Anomaly Alerts',
                    trailing: _Toggle(value: _anomalyAlerts, onChanged: (v) => setState(() => _anomalyAlerts = v))),
                _SettingsItem(Icons.mail_outline, 'Email Reports',
                    trailing: _Toggle(value: _emailReports, onChanged: (v) => setState(() => _emailReports = v))),
              ]),
              _SectionLabel('Thresholds'),
              _SettingsGroup([
                _SettingsItem(Icons.bolt, 'Voltage Limits',
                    trailing: const Text('210–250V', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)), onTap: () {}),
                _SettingsItem(Icons.waves, 'Current Limit',
                    trailing: const Text('20A max', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)), onTap: () {}),
              ]),
              _SectionLabel('Account'),
              _SettingsGroup([
                // TC-Nav-2 + TC-CP: Change Password now navigates to full flow
                _SettingsItem(Icons.lock_outline, 'Change Password',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
                _SettingsItem(Icons.shield_outlined, 'Security & Privacy', onTap: () {}),
                _SettingsItem(Icons.help_outline, 'Help & Support', onTap: () {}),
              ]),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: BorderSide(color: AppColors.red.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _SectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 20, 6),
    child: Text(label.toUpperCase(),
        style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
  );

  Widget _SettingsGroup(List<Widget> items) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(
      children: items.asMap().entries.map((e) => Column(children: [
        e.value,
        if (e.key < items.length - 1) const Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 0),
      ])).toList(),
    ),
  );
}

class _SettingsItem extends StatelessWidget {
  final IconData icon; final String label; final Widget? trailing; final VoidCallback? onTap;
  const _SettingsItem(this.icon, this.label, {this.trailing, this.onTap});
  @override Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: 20), const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
        trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18) : const SizedBox()),
      ]),
    ),
  );
}

class _Toggle extends StatelessWidget {
  final bool value; final ValueChanged<bool> onChanged;
  const _Toggle({required this.value, required this.onChanged});
  @override Widget build(BuildContext context) => Switch.adaptive(
    value: value, onChanged: onChanged,
    activeColor: AppColors.accent, activeTrackColor: AppColors.accent.withOpacity(0.3),
    inactiveThumbColor: AppColors.textSecondary, inactiveTrackColor: AppColors.bg3,
  );
}
