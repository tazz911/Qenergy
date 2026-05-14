// lib/features/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../home/main_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  bool _obscure        = true;
  bool _obscureConfirm = true;

  String? _nameError;
  String? _emailError;
  String? _passError;
  String? _confirmError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String e) =>
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$').hasMatch(e);

  bool _hasUppercase(String p) => p.contains(RegExp(r'[A-Z]'));
  bool _hasDigit(String p)     => p.contains(RegExp(r'[0-9]'));

  bool _validate() {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    String? ne, ee, pe, ce;

    if (name.isEmpty)    ne = 'Full name is required';
    if (email.isEmpty)   ee = 'Email address is required';
    if (pass.isEmpty)    pe = 'Password is required';
    if (confirm.isEmpty) ce = 'Please confirm your password';

    if (email.isNotEmpty && !_isValidEmail(email))
      ee = 'Invalid email address';

    if (pass.isNotEmpty && pass.length < 8)
      pe = 'Password must be at least 8 characters';
    else if (pass.isNotEmpty && (!_hasUppercase(pass) || !_hasDigit(pass)))
      pe = 'Must contain uppercase letters and numbers';

    if (pass.isNotEmpty && confirm.isNotEmpty && pass != confirm)
      ce = 'Passwords do not match';

    setState(() {
      _nameError    = ne;
      _emailError   = ee;
      _passError    = pe;
      _confirmError = ce;
    });
    return ne == null && ee == null && pe == null && ce == null;
  }

  Future<void> _register() async {
    if (!_validate()) return;
    final auth   = context.read<AuthProvider>();
    final result = await auth.register(
      _nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text,
    );
    if (!mounted) return;
    if (result.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: const Icon(Icons.bolt, color: AppColors.accent, size: 28),
                ),
              ),
              const SizedBox(height: 24),

              if (auth.status == AuthStatus.error && auth.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    auth.error!.contains('already-in-use')
                        ? 'Email already exists. Please use a different email.'
                        : auth.error!,
                    style: const TextStyle(color: AppColors.red, fontSize: 13),
                  ),
                ),

              _buildField('Full name', _nameCtrl,
                  hint: 'Ahmad Al-Rashidi', error: _nameError),
              const SizedBox(height: 16),
              _buildField('Email address', _emailCtrl,
                  hint: 'you@example.com', error: _emailError,
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 16),

              // Password field with strength indicator
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Password',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: AppColors.textPrimary),
                    onChanged: (_) => setState(() {
                      _nameError = _emailError = _passError = _confirmError = null;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Min. 8 characters',
                      errorText: _passError,
                      errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textTertiary, size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_passCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _StrengthRow(_passCtrl.text),
                  ],
                ],
              ),

              const SizedBox(height: 16),
              _buildField('Confirm password', _confirmCtrl,
                  hint: 'Repeat password', error: _confirmError,
                  obscure: _obscureConfirm,
                  toggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
              const SizedBox(height: 24),

              auth.status == AuthStatus.loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : ElevatedButton(
                      onPressed: _register,
                      child: const Text('Create Account')),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('Sign in',
                        style: TextStyle(color: AppColors.accent,
                            fontWeight: FontWeight.w500, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _StrengthRow(String pass) {
    final long  = pass.length >= 8;
    final upper = _hasUppercase(pass);
    final digit = _hasDigit(pass);
    Color barColor;
    String label;
    if (long && upper && digit) { barColor = AppColors.green;  label = 'Strong'; }
    else if (long)               { barColor = AppColors.orange; label = 'Medium'; }
    else                         { barColor = AppColors.red;    label = 'Weak'; }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: long && upper && digit ? 1.0 : long ? 0.6 : 0.3,
              minHeight: 4,
              backgroundColor: AppColors.bg3,
              color: barColor,
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

  Widget _buildField(String label, TextEditingController ctrl, {
    String hint = '', String? error, bool obscure = false,
    TextInputType keyboard = TextInputType.text, VoidCallback? toggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboard,
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: (_) => setState(() {
            _nameError = _emailError = _passError = _confirmError = null;
          }),
          decoration: InputDecoration(
            hintText: hint,
            errorText: error,
            errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
            suffixIcon: toggle != null
                ? IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textTertiary, size: 18),
                    onPressed: toggle)
                : null,
          ),
        ),
      ],
    );
  }
}