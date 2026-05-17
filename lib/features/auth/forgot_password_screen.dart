// lib/features/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading    = false;
  bool _sent       = false;
  String? _emailError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email address');
      return;
    }

    setState(() { _loading = true; _emailError = null; });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() { _loading = false; _sent = true; });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _emailError = e.code == 'user-not-found'
            ? 'No account found with this email.'
            : e.message ?? 'Failed to send reset link. Try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _emailError = 'Network error. Try again.'; });
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
        title: Text(_sent ? 'Email Sent' : 'Forgot Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _sent ? _DoneView() : _EmailView(),
        ),
      ),
    );
  }

  Widget _EmailView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Center(child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent, width: 2),
        ),
        child: const Icon(Icons.lock_reset, color: AppColors.accent, size: 32),
      )),
      const SizedBox(height: 20),
      const Center(
        child: Text('Forgot Password',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ),
      const SizedBox(height: 8),
      const Center(
        child: Text(
          'Enter your email and we\'ll send\na password reset link.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
        ),
      ),
      const SizedBox(height: 32),
      const Text('Email address',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      const SizedBox(height: 6),
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
      _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ElevatedButton(
              onPressed: _sendResetLink,
              child: const Text('Send Reset Link'),
            ),
    ],
  );

  Widget _DoneView() => Column(
    children: [
      const SizedBox(height: 40),
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.green, width: 3),
        ),
        child: const Icon(Icons.mark_email_read_outlined, color: AppColors.green, size: 40),
      ),
      const SizedBox(height: 20),
      const Text('Check Your Email',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      Text(
        'A password reset link has been sent to\n${_emailCtrl.text.trim()}\n\nFollow the link to set a new password.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: AppColors.accent, size: 14),
          SizedBox(width: 8),
          Expanded(child: Text(
            'The link expires in 1 hour. Check your spam folder if not received.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
          )),
        ]),
      ),
      const SizedBox(height: 32),
      ElevatedButton(
        onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        child: const Text('Back to Sign In'),
      ),
    ],
  );
}
