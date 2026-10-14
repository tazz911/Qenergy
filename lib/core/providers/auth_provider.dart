// lib/core/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as sb show AuthState;
import '../services/supabase_service.dart';
import '../models/models.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final SupabaseService _svc = SupabaseService();
  late final StreamSubscription<sb.AuthState> _sub;
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  UserModel? _userModel;

  AuthStatus get status => _status;
  String? get error => _errorMessage;
  UserModel? get user => _userModel;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _sub = _svc.authStateChanges.listen((state) => _onSessionChanged(state.session));
  }

  @override
  void dispose() { _sub.cancel(); super.dispose(); }

  Future<void> _onSessionChanged(Session? session) async {
    if (session == null) {
      _userModel = null;
      if (_status != AuthStatus.loading && _status != AuthStatus.error) {
        _status = AuthStatus.unauthenticated;
      }
    } else {
      try {
        _userModel = await _svc.getUser(session.user.id);
      } catch (_) {
        _userModel = null;
      }
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  void _fail(Object e) {
    _errorMessage = e is AuthException ? e.message : 'Network error. Please try again.';
    _status = AuthStatus.error;
    notifyListeners();
  }

  void _startLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _startLoading();
    try {
      await _svc.auth.signInWithPassword(email: email.trim(), password: password);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  /// Step 1 of registration: creates the account and Supabase emails a 6-digit code.
  Future<bool> register(String fullName, String email, String password) async {
    _startLoading();
    try {
      final res = await _svc.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName},
      );
      // Supabase returns a user with no identities when the email is already registered.
      if (res.user?.identities?.isEmpty ?? false) {
        _fail(const AuthException('An account already exists for this email.'));
        return false;
      }
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  /// Step 2 of registration: checks the code from the email and signs the user in.
  Future<String?> verifySignupCode(String email, String code) async {
    try {
      await _svc.auth.verifyOTP(email: email.trim(), token: code, type: OtpType.signup);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Network error. Please try again.';
    }
  }

  Future<String?> resendSignupCode(String email) async {
    try {
      await _svc.auth.resend(email: email.trim(), type: OtpType.signup);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Network error. Please try again.';
    }
  }

  /// Forgot password step 1: Supabase emails a 6-digit reset code.
  Future<String?> sendPasswordResetCode(String email) async {
    try {
      await _svc.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Network error. Please try again.';
    }
  }

  /// Forgot password step 2: check the code, then set the new password.
  Future<String?> resetPasswordWithCode(String email, String code, String newPassword) async {
    try {
      await _svc.auth.verifyOTP(email: email.trim(), token: code, type: OtpType.recovery);
      await _svc.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Network error. Please try again.';
    }
  }

  /// Change password from Settings: re-checks the current password first.
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    final email = _svc.currentUser?.email;
    if (email == null) return 'Session expired. Please sign in again.';
    try {
      await _svc.auth.signInWithPassword(email: email, password: currentPassword);
    } on AuthException {
      return 'Current password is incorrect.';
    } catch (_) {
      return 'Network error. Please try again.';
    }
    try {
      await _svc.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Network error. Please try again.';
    }
  }

  /// Save profile/settings fields (e.g. {'full_name': 'Yahya'} or {'voltage_max': 245}).
  Future<String?> updateProfile(Map<String, dynamic> fields) async {
    final uid = _svc.currentUser?.id;
    if (uid == null) return 'Session expired. Please sign in again.';
    try {
      await _svc.updateProfile(uid, fields);
      _userModel = await _svc.getUser(uid);
      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not save. Check your internet and try again.';
    }
  }

  Future<void> logout() async {
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    await _svc.auth.signOut();
  }
}
