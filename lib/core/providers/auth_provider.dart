// lib/core/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error, pendingOtp }

class AuthProvider extends ChangeNotifier {
  final FirebaseService _svc = FirebaseService();
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  UserModel? _userModel;
  String? _pendingEmail;
  String? _pendingPassword;

  AuthStatus get status => _status;
  String? get error => _errorMessage;
  UserModel? get user => _userModel;
  String? get pendingEmail => _pendingEmail;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() { _svc.authStateChanges.listen(_onAuthStateChanged); }

  Future<void> _onAuthStateChanged(User? user) async {
    // Ignore Firebase auth changes while waiting for OTP
    if (_status == AuthStatus.pendingOtp) return;
    if (_status == AuthStatus.loading) return;

    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _userModel = null;
    } else {
      _userModel = await _svc.getUser(user.uid) ?? _modelFromFirebaseUser(user);
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  UserModel _modelFromFirebaseUser(User user) => UserModel(
    userId: user.uid,
    fullName: user.displayName ?? '',
    email: user.email ?? '',
    createdAt: DateTime.now(),
  );

  // Called after OTP is verified — sign back in and complete login
  Future<void> completeLogin() async {
    if (_pendingEmail == null || _pendingPassword == null) return;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _pendingEmail!,
        password: _pendingPassword!,
      );
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userModel = await _svc.getUser(user.uid) ?? _modelFromFirebaseUser(user);
      }
      _status = AuthStatus.authenticated;
      _pendingEmail = null;
      _pendingPassword = null;
      notifyListeners();
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Failed to complete login.';
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      // Step 1 — verify credentials with Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Step 2 — immediately sign out, wait for OTP
      await FirebaseAuth.instance.signOut();

      // Save credentials for after OTP
      _pendingEmail    = email.trim();
      _pendingPassword = password;
      _status = AuthStatus.pendingOtp;
      notifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Login failed.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<({bool success, String? uid})> register(String fullName, String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(fullName);
      final uid = cred.user?.uid;
      if (uid != null) {
        await _svc.createUserDoc(uid, fullName, email.trim());
        _userModel = await _svc.getUser(uid);
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return (success: true, uid: uid);
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Registration failed.';
      _status = AuthStatus.error;
      notifyListeners();
      return (success: false, uid: null);
    } catch (e) {
      _errorMessage = 'Network error.';
      _status = AuthStatus.error;
      notifyListeners();
      return (success: false, uid: null);
    }
  }

  Future<void> logout() async {
    _status = AuthStatus.unauthenticated;
    _pendingEmail = null;
    _pendingPassword = null;
    notifyListeners();
    await _svc.signOut();
  }
}