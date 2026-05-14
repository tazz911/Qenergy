// lib/features/auth/login_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../home/main_shell.dart';

// ── EmailJS credentials (same as otp_screen.dart) ────
const _serviceId  = 'service_82v543r';
const _templateId = 'template_styn7r9';
const _publicKey  = 'yQkmEMeZwReslOlzp';

enum _LoginStep { credentials, otp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _LoginStep _step = _LoginStep.credentials;

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;
  String? _emailError;
  String? _passError;

  final List<TextEditingController> _otpCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());
  String _generatedOtp = '';
  bool _otpLoading = false;
  bool _otpSending = false;
  String? _otpError;
  int _seconds = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final n in _otpNodes) n.dispose();
    super.dispose();
  }

  bool _validate() {
    String? ee, pe;
    if (_emailCtrl.text.trim().isEmpty) ee = 'Email address is required';
    if (_passCtrl.text.isEmpty)         pe = 'Password is required';
    setState(() { _emailError = ee; _passError = pe; });
    return ee == null && pe == null;
  }

  Future<void> _login() async {
    if (!_validate()) return;
    final auth = context.read<AuthProvider>();
    final ok   = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (ok) {
      await _sendOtp();
      setState(() => _step = _LoginStep.otp);
    }
  }

  Future<void> _sendOtp() async {
    setState(() { _otpSending = true; _otpError = null; });
    _generatedOtp = List.generate(6, (_) => Random().nextInt(10)).join();

    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'https://localhost',
        },
        body: jsonEncode({
          'service_id':  _serviceId,
          'template_id': _templateId,
          'user_id':     _publicKey,
          'template_params': {
            'to_email': _emailCtrl.text.trim(),
            'otp_code': _generatedOtp,
          },
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Verification code sent to your email!'),
            backgroundColor: AppColors.green,
          ));
        }
      } else {
        if (mounted) setState(() => _otpError = 'Failed to send code. Tap Resend.');
      }
    } catch (e) {
      if (mounted) setState(() => _otpError = 'Network error. Tap Resend.');
    }

    if (mounted) {
      setState(() => _otpSending = false);
      _startTimer();
    }
  }

  void _startTimer() {
    setState(() { _seconds = 60; _canResend = false; });
    _otpCtrls[0].clear();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _seconds--);
      if (_seconds <= 0) {
        if (mounted) setState(() => _canResend = true);
        return false;
      }
      return true;
    });
  }

  String get _otp => _otpCtrls.map((c) => c.text).join();

  void _onOtpChanged(int i, String val) {
    if (val.isNotEmpty && i < 5) _otpNodes[i + 1].requestFocus();
    if (val.isEmpty && i > 0) _otpNodes[i - 1].requestFocus();
    setState(() => _otpError = null);
  }

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) return;
    setState(() { _otpLoading = true; _otpError = null; });
    await Future.delayed(const Duration(milliseconds: 500));

    if (_otp == _generatedOtp) {
      final auth = context.read<AuthProvider>();
      await auth.completeLogin();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (_) => false,
        );
      }
    } else {
      setState(() {
        _otpLoading = false;
        _otpError = 'Incorrect code. Please try again.';
        for (final c in _otpCtrls) c.clear();
      });
      _otpNodes[0].requestFocus();
    }
  }

  Future<void> _resend() async {
    for (final c in _otpCtrls) c.clear();
    setState(() { _otpError = null; _canResend = false; });
    _otpNodes[0].requestFocus();
    await _sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: _step == _LoginStep.credentials
            ? _CredentialsView(auth)
            : _OtpView(),
      ),
    );
  }

  Widget _CredentialsView(AuthProvider auth) => Column(
    children: [
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 2),
              ),
              child: const Icon(Icons.bolt, color: AppColors.accent, size: 36),
            ),
            const SizedBox(height: 16),
            Text('EnergyIQ', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 4),
            Text('Smart Energy Monitoring',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Sign in to your account',
                style: Theme.of(context).textTheme.bodyMedium),
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
                  _mapFirebaseError(auth.error!),
                  style: const TextStyle(color: AppColors.red, fontSize: 13),
                ),
              ),

            const Text('Email address',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (_) => setState(() { _emailError = null; _passError = null; }),
              decoration: InputDecoration(
                hintText: 'you@example.com',
                errorText: _emailError,
                errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Password',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (_) => setState(() { _emailError = null; _passError = null; }),
              decoration: InputDecoration(
                hintText: '••••••••',
                errorText: _passError,
                errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textTertiary, size: 18),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                child: const Text('Forgot password?',
                    style: TextStyle(color: AppColors.accent, fontSize: 12)),
              ),
            ),

            auth.status == AuthStatus.loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : ElevatedButton(onPressed: _login, child: const Text('Sign In')),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Don't have an account? ",
                    style: Theme.of(context).textTheme.bodyMedium),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Register',
                      style: TextStyle(color: AppColors.accent,
                          fontWeight: FontWeight.w500, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _OtpView() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const SizedBox(height: 32),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          child: const Icon(Icons.mail_outline, color: AppColors.accent, size: 32),
        ),
        const SizedBox(height: 16),
        const Text('Check your email',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to\n${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13,
              color: AppColors.textSecondary, height: 1.6),
        ),
        const SizedBox(height: 28),

        if (_otpSending)
          const Column(children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 8),
            Text('Sending code to your email...',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) => Container(
              width: 44, height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TextFormField(
                controller: _otpCtrls[i],
                focusNode: _otpNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.bg3,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border, width: 2)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _otpCtrls[i].text.isNotEmpty
                          ? AppColors.accent : AppColors.border,
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent, width: 2),
                  ),
                ),
                onChanged: (val) => _onOtpChanged(i, val),
                onTap: () => _otpCtrls[i].selection = TextSelection.fromPosition(
                    TextPosition(offset: _otpCtrls[i].text.length)),
              ),
            )),
          ),

          if (_otpError != null) ...[
            const SizedBox(height: 10),
            Text(_otpError!,
                style: const TextStyle(color: AppColors.red, fontSize: 12),
                textAlign: TextAlign.center),
          ],

          const SizedBox(height: 20),
          _otpLoading
              ? const CircularProgressIndicator(color: AppColors.accent)
              : ElevatedButton(
                  onPressed: _otp.length == 6 ? _verifyOtp : null,
                  child: const Text('Verify Code'),
                ),
          const SizedBox(height: 16),

          if (!_canResend)
            Text('Resend code in ${_seconds}s',
                style: const TextStyle(fontSize: 12,
                    color: AppColors.textSecondary))
          else
            GestureDetector(
              onTap: _resend,
              child: const Text('Resend verification code',
                  style: TextStyle(fontSize: 12, color: AppColors.accent,
                      fontWeight: FontWeight.w600)),
            ),

          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _step = _LoginStep.credentials;
              for (final c in _otpCtrls) c.clear();
            }),
            child: const Text('← Back to Sign In',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.accent, size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Code expires in 10 minutes. Check your spam folder if not received.',
                    style: TextStyle(fontSize: 11,
                        color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  String _mapFirebaseError(String error) {
    if (error.contains('user-not-found') || error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'Invalid email or password. Please try again.';
    }
    if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    return error;
  }
}