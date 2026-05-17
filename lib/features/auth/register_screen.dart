// lib/features/auth/register_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../home/main_shell.dart';

const _serviceId  = 'service_s07dvkk';
const _templateId = 'template_05thw2k';
const _publicKey  = '2TbvVci0KOW9ZaPd7';

enum _RegisterStep { form, otp }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  _RegisterStep _step = _RegisterStep.form;

  // ── Form fields ───────────────────────────────────────
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

  // ── OTP fields ────────────────────────────────────────
  final List<TextEditingController> _otpCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());
  String _generatedOtp = '';
  bool _otpLoading  = false;
  bool _otpSending  = false;
  String? _otpError;
  Timer? _timer;
  int  _seconds   = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _timer?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final n in _otpNodes) n.dispose();
    super.dispose();
  }

  bool _isValidEmail(String e) =>
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$').hasMatch(e);

  bool _hasUppercase(String p) => p.contains(RegExp(r'[A-Z]'));
  bool _hasDigit(String p)     => p.contains(RegExp(r'[0-9]'));
  bool _hasSpecial(String p)   => p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]]'));

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
    else if (pass.isNotEmpty &&
        (!_hasUppercase(pass) || !_hasDigit(pass) || !_hasSpecial(pass)))
      pe = 'Must contain uppercase, number, and special character (!@#\$...)';

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
      await _sendOtp();
      setState(() => _step = _RegisterStep.otp);
    }
  }

  // ── OTP logic ─────────────────────────────────────────

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
            'otp_code': _generatedOtp,
            'to_email': _emailCtrl.text.trim(),
            'time':     '10 minutes',
          },
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Verification code sent to your email!'),
            backgroundColor: AppColors.green,
          ));
        } else {
          setState(() => _otpError = 'Failed to send code. Tap Resend.');
        }
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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds == 0) {
        t.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _seconds--);
      }
    });
  }

  String get _otp => _otpCtrls.map((c) => c.text).join();

  void _onOtpChanged(int i, String val) {
    if (val.isNotEmpty && i < 5) _otpNodes[i + 1].requestFocus();
    if (val.isEmpty && i > 0)   _otpNodes[i - 1].requestFocus();
    setState(() => _otpError = null);
  }

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) return;
    setState(() { _otpLoading = true; _otpError = null; });
    await Future.delayed(const Duration(milliseconds: 500));

    if (_otp == _generatedOtp) {
      final auth = context.read<AuthProvider>();
      await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
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

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (_step == _RegisterStep.otp) {
              setState(() => _step = _RegisterStep.form);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(_step == _RegisterStep.form ? 'Create Account' : 'Verify Email'),
      ),
      body: SafeArea(
        child: _step == _RegisterStep.form ? _FormView() : _OtpView(),
      ),
    );
  }

  Widget _FormView() {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
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
    );
  }

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
        const Text('Verify your email',
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border, width: 2),
                  ),
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
                  child: const Text('Verify & Continue'),
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
