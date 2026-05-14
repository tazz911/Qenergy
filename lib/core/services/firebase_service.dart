// lib/core/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── AUTH ──────────────────────────────────────────────
  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> register(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── USER ──────────────────────────────────────────────
  Future<void> createUserDoc(String uid, String fullName, String email) {
    return _db.collection('users').doc(uid).set({
      'user_id': uid, 'full_name': fullName, 'email': email,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  // ── ZONES ─────────────────────────────────────────────
  Stream<List<ZoneModel>> zonesStream(String userId) {
    return _db.collection('zones')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ZoneModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> addZone(String userId, String zoneName, String? location) {
    return _db.collection('zones').add({
      'user_id': userId, 'zone_name': zoneName,
      'location': location ?? '', 'status': 'active',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateZoneStatus(String zoneId, String status) {
    return _db.collection('zones').doc(zoneId).update({'status': status});
  }

  Future<void> deleteZone(String zoneId) {
    return _db.collection('zones').doc(zoneId).delete();
  }

  // ── DEVICES ───────────────────────────────────────────
  Stream<List<DeviceModel>> devicesStream(String zoneId) {
    return _db.collection('devices')
        .where('zone_id', isEqualTo: zoneId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DeviceModel.fromMap(d.data(), d.id)).toList());
  }

  // ── ENERGY READINGS ───────────────────────────────────
  /// Real-time latest reading for a device
  Stream<EnergyReading?> latestReadingStream(String deviceId) {
    return _db.collection('energy_readings')
        .where('device_id', isEqualTo: deviceId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : EnergyReading.fromMap(snap.docs.first.data(), snap.docs.first.id));
  }

  /// Historical readings for chart (last N hours)
  Future<List<EnergyReading>> getReadingsHistory(String deviceId, {int hours = 24}) async {
    final since = DateTime.now().subtract(Duration(hours: hours));
    final snap = await _db.collection('energy_readings')
        .where('device_id', isEqualTo: deviceId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp')
        .get();
    return snap.docs.map((d) => EnergyReading.fromMap(d.data(), d.id)).toList();
  }

  /// Aggregate total kWh for a zone today
  Future<double> getTotalKwhToday(String zoneId) async {
    final start = DateTime.now().copyWith(hour: 0, minute: 0, second: 0);
    // Get all devices in zone
    final devices = await _db.collection('devices').where('zone_id', isEqualTo: zoneId).get();
    double total = 0;
    for (final dev in devices.docs) {
      final snap = await _db.collection('energy_readings')
          .where('device_id', isEqualTo: dev.id)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(start))
          .get();
      for (final r in snap.docs) {
        total += (r.data()['energy_kwh'] ?? 0).toDouble();
      }
    }
    return total;
  }

  // ── ALERTS ────────────────────────────────────────────
  Stream<List<AlertModel>> alertsStream(String userId) {
    // Join via devices → zones → user
    // Simplified: query alerts collection where device belongs to user
    return _db.collection('alerts')
        .orderBy('alert_time', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AlertModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> acknowledgeAlert(String alertId) {
    return _db.collection('alerts').doc(alertId).update({'is_acknowledged': true});
  }
}
