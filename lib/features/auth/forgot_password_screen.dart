// lib/features/auth/forgot_password_screen.dart
// Step 1: enter email → Supabase emails a 6-digit code.
// Step 2: enter the code + new password → password is changed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

enum _Step { email, code, done }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();
  final _passCtrl  = TextEditingController();
  _Step _step      = _Step.email;
  bool _loading    = false;
  bool _obscure    = true;
  String? _emailError, _codeError, _passError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email address');
      return;
    }
    setState(() { _loading = true; _emailError = null; });
    final err = await context.read<AuthProvider>().sendPasswordResetCode(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (err == null) { _step = _Step.code; } else { _emailError = err; }
    });
  }

  Future<void> _resetPassword() async {
    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text;
    String? ce, pe;
    if (code.length != 6) ce = 'Enter the 6-digit code from the email';
    if (pass.length < 8) pe = 'Password must be at least 8 characters';
    setState(() { _codeError = ce; _passError = pe; });
    if (ce != null || pe != null) return;

    setState(() => _loading = true);
    final err = await context.read<AuthProvider>()
        .resetPasswordWithCode(_emailCtrl.text.trim(), code, pass);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (err == null) {
        _step = _Step.done;
      } else if (err.contains('expired') || err.contains('invalid')) {
        _codeError = 'Incorrect or expired code.';
      } else {
        _passError = err;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_step == _Step.done ? 'Password Changed' : 'Forgot Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            _Step.email => _EmailView(),
            _Step.code  => _CodeView(),
            _Step.done  => _DoneView(),
          },
        ),
      ),
    );
  }

  Widget _Icon(IconData icon, Color color) => Center(child: Container(
    width: 72, height: 72,
    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
    child: Icon(icon, color: color, size: 32),
  ));

  Widget _Title(String title, String sub) => Column(children: [
    Center(child: Text(title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
    const SizedBox(height: 8),
    Center(child: Text(sub, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6))),
  ]);

  Widget _Label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
  );

  Widget _Button(String label, VoidCallback onPressed) => _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
      : ElevatedButton(onPressed: onPressed, child: Text(label));

  Widget _EmailView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      _Icon(Icons.lock_reset, AppColors.accent),
      const SizedBox(height: 20),
      _Title('Forgot Password', 'Enter your email and we\'ll send\na 6-digit reset code.'),
      const SizedBox(height: 32),
      _Label('Email address'),
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(color: AppColors.textPrimary),
        onChanged: (_) => setState(() => _emailError = null),
        decoration: InputDecoration(
          hintText: 'you@example.com',
          errorText: _emailError,
          errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
        ),
      ),
      const SizedBox(height: 24),
      _Button('Send Reset Code', _sendCode),
    ],
  );

  Widget _CodeView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      _Icon(Icons.mail_outline, AppColors.accent),
      const SizedBox(height: 20),
      _Title('Enter Reset Code', 'We sent a 6-digit code to\n${_emailCtrl.text.trim()}'),
      const SizedBox(height: 32),
      _Label('Reset code'),
      TextField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, letterSpacing: 8),
        onChanged: (_) => setState(() => _codeError = null),
        decoration: InputDecoration(
          hintText: '000000',
          counterText: '',
          errorText: _codeError,
          errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
        ),
      ),
      const SizedBox(height: 16),
      _Label('New password'),
      TextField(
        controller: _passCtrl,
        obscureText: _obscure,
        style: const TextStyle(color: AppColors.textPrimary),
        onChanged: (_) => setState(() => _passError = null),
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
      const SizedBox(height: 24),
      _Button('Reset Password', _resetPassword),
      const SizedBox(height: 12),
      Center(child: TextButton(
        onPressed: _loading ? null : _sendCode,
        child: const Text('Resend code', style: TextStyle(color: AppColors.accent)),
      )),
    ],
  );

  Widget _DoneView() => Column(
    children: [
      const SizedBox(height: 40),
      _Icon(Icons.check_circle_outline, AppColors.green),
      const SizedBox(height: 20),
      _Title('Password Changed', 'Your password was updated\nand you are now signed in.'),
      const SizedBox(height: 32),
      ElevatedButton(
        onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        child: const Text('Continue'),
      ),
    ],
  );
}
