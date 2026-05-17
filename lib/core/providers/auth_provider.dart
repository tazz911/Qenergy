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
 
  AuthStatus get status => _status;
  String? get error => _errorMessage;
  UserModel? get user => _userModel;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
 
  AuthProvider() { _svc.authStateChanges.listen(_onAuthStateChanged); }
 
  Future<void> _onAuthStateChanged(User? user) async {
    if (_status == AuthStatus.loading) return;
 
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _userModel = null;
    } else {
      _userModel = await _svc.getUser(user.uid);
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }
 
  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _status = AuthStatus.authenticated;
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
 
      // ✅ Save to Firestore
      await _svc.createUserDoc(cred.user!.uid, fullName, email.trim());
 
      // ✅ Save to Realtime Database
      await _svc.saveUserRealtime(cred.user!.uid, fullName, email.trim());
 
      return (success: true, uid: cred.user?.uid);
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
    notifyListeners();
    await _svc.signOut();
  }
}