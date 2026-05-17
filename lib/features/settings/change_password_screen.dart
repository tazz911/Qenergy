// lib/features/settings/change_password_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl     = TextEditingController();
  final _confirmCtrl     = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _loading        = false;

  String? _currentPassError;
  String? _newPassError;
  String? _confirmError;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _hasUppercase(String p) => p.contains(RegExp(r'[A-Z]'));
  bool _hasDigit(String p)     => p.contains(RegExp(r'[0-9]'));
  bool _hasSpecial(String p)   => p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]]'));

  bool _validate() {
    String? ce, ne, conf;
    final current = _currentPassCtrl.text;
    final pass    = _newPassCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty) ce = 'Current password is required';
    if (pass.isEmpty)    ne = 'New password is required';
    if (confirm.isEmpty) conf = 'Please confirm your new password';

    if (pass.isNotEmpty && pass.length < 8)
      ne = 'Password must be at least 8 characters';
    else if (pass.isNotEmpty &&
        (!_hasUppercase(pass) || !_hasDigit(pass) || !_hasSpecial(pass)))
      ne = 'Must contain uppercase, number, and special character (!@#\$...)';
    if (pass.isNotEmpty && confirm.isNotEmpty && pass != confirm)
      conf = 'Passwords do not match';
    if (pass.isNotEmpty && current.isNotEmpty && pass == current)
      ne = 'New password must be different from current password';

    setState(() {
      _currentPassError = ce;
      _newPassError     = ne;
      _confirmError     = conf;
    });
    return ce == null && ne == null && conf == null;
  }

  Future<void> _changePassword() async {
    if (!_validate()) return;
    setState(() { _loading = true; _currentPassError = null; _newPassError = null; _confirmError = null; });

    try {
      final user  = FirebaseAuth.instance.currentUser!;
      final email = user.email!;

      // Step 1 — Re-authenticate with current password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _currentPassCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Step 2 — Update to new password
      await user.updatePassword(_newPassCtrl.text);

      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password changed successfully!'),
        backgroundColor: AppColors.green,
      ));
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _currentPassError = 'Current password is incorrect.';
        } else if (e.code == 'weak-password') {
          _newPassError = 'Password is too weak.';
        } else if (e.code == 'requires-recent-login') {
          _currentPassError = 'Session expired. Please sign out and sign in again.';
        } else {
          _newPassError = e.message ?? 'Failed to update password.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _newPassError = 'Network error. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Change Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: const Icon(Icons.lock_outline, color: AppColors.accent, size: 32),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text('Change Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Enter your current password and choose\na new strong password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
                ),
              ),
              const SizedBox(height: 32),

              // Current password
              const Text('Current Password',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _currentPassCtrl,
                obscureText: _obscureCurrent,
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (_) => setState(() => _currentPassError = null),
                decoration: InputDecoration(
                  hintText: 'Enter current password',
                  errorText: _currentPassError,
                  errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textTertiary, size: 18),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // New password
              const Text('New Password',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _newPassCtrl,
                obscureText: _obscureNew,
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (_) => setState(() => _newPassError = null),
                decoration: InputDecoration(
                  hintText: 'Min. 8 characters',
                  errorText: _newPassError,
                  errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textTertiary, size: 18),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),

              if (_newPassCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _StrengthRow(_newPassCtrl.text),
              ],

              const SizedBox(height: 20),

              // Confirm password
              const Text('Confirm New Password',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (_) => setState(() => _confirmError = null),
                decoration: InputDecoration(
                  hintText: 'Repeat new password',
                  errorText: _confirmError,
                  errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textTertiary, size: 18),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : ElevatedButton(
                      onPressed: _changePassword,
                      child: const Text('Update Password'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _StrengthRow(String pass) {
    final long    = pass.length >= 8;
    final upper   = _hasUppercase(pass);
    final digit   = _hasDigit(pass);
    final special = _hasSpecial(pass);

    Color barColor;
    String label;
    if (long && upper && digit && special) { barColor = AppColors.green;  label = 'Strong'; }
    else if (long)                          { barColor = AppColors.orange; label = 'Medium'; }
    else                                    { barColor = AppColors.red;    label = 'Weak'; }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: long && upper && digit && special ? 1.0 : long ? 0.55 : 0.25,
              minHeight: 4, backgroundColor: AppColors.bg3, color: barColor,
            ),
          )),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 11, color: barColor,
              fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 8, children: [
          _Criterion('8+ chars', long),
          _Criterion('Uppercase', upper),
          _Criterion('Number', digit),
          _Criterion('Special (!@#)', special),
        ]),
      ],
    );
  }

  Widget _Criterion(String label, bool met) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 12, color: met ? AppColors.green : AppColors.textTertiary),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10,
          color: met ? AppColors.green : AppColors.textTertiary)),
    ],
  );
}