// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../home/main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;
  String? _emailError;
  String? _passError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
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
      body: SafeArea(
        child: Column(
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
        ),
      ),
    );
  }

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
