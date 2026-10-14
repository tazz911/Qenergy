// lib/core/services/supabase_service.dart
// All database access goes through here. Row Level Security in Supabase makes
// sure each user only ever gets their own zones, devices, readings and alerts.
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  final SupabaseClient _db = Supabase.instance.client;

  // ── AUTH ──────────────────────────────────────────────
  GoTrueClient get auth => _db.auth;
  User? get currentUser => _db.auth.currentUser;
  Stream<AuthState> get authStateChanges => _db.auth.onAuthStateChange;

  // ── USER ──────────────────────────────────────────────
  Future<UserModel?> getUser(String uid) async {
    final row = await _db.from('profiles').select().eq('user_id', uid).maybeSingle();
    return row == null ? null : UserModel.fromMap(row);
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> fields) {
    return _db.from('profiles').update(fields).eq('user_id', uid);
  }

  // ── ZONES ─────────────────────────────────────────────
  Stream<List<ZoneModel>> zonesStream(String userId) {
    return _db.from('zones').stream(primaryKey: ['zone_id'])
        .eq('user_id', userId)
        .order('created_at')
        .map((rows) => rows.map(ZoneModel.fromMap).toList());
  }

  Future<List<ZoneModel>> getZones() async {
    final rows = await _db.from('zones').select().order('created_at');
    return rows.map(ZoneModel.fromMap).toList();
  }

  Future<void> addZone(String userId, String zoneName, String? location) {
    return _db.from('zones').insert({
      'user_id': userId, 'zone_name': zoneName, 'location': location,
    });
  }

  Future<void> updateZone(String zoneId, {String? zoneName, String? location, String? status}) {
    return _db.from('zones').update({
      if (zoneName != null) 'zone_name': zoneName,
      if (location != null) 'location': location,
      if (status != null) 'status': status,
    }).eq('zone_id', zoneId);
  }

  Future<void> deleteZone(String zoneId) {
    return _db.from('zones').delete().eq('zone_id', zoneId);
  }

  // ── DEVICES ───────────────────────────────────────────
  Stream<List<DeviceModel>> devicesStream(String zoneId) {
    return _db.from('devices').stream(primaryKey: ['device_id'])
        .eq('zone_id', zoneId)
        .map((rows) => rows.map(DeviceModel.fromMap).toList());
  }

  Future<List<DeviceModel>> getAllDevices() async {
    final rows = await _db.from('devices').select().order('installed_at');
    return rows.map(DeviceModel.fromMap).toList();
  }

  Future<void> addDevice(String zoneId, String deviceName, String deviceType, String serialNumber) {
    return _db.from('devices').insert({
      'zone_id': zoneId, 'device_name': deviceName,
      'device_type': deviceType, 'serial_number': serialNumber,
    });
  }

  Future<void> updateDevice(String deviceId, {String? deviceName, String? deviceType, String? status}) {
    return _db.from('devices').update({
      if (deviceName != null) 'device_name': deviceName,
      if (deviceType != null) 'device_type': deviceType,
      if (status != null) 'status': status,
    }).eq('device_id', deviceId);
  }

  Future<void> deleteDevice(String deviceId) {
    return _db.from('devices').delete().eq('device_id', deviceId);
  }

  // ── ENERGY READINGS ───────────────────────────────────
  Stream<EnergyReading?> latestReadingStream(String deviceId) {
    return _db.from('energy_readings').stream(primaryKey: ['reading_id'])
        .eq('device_id', deviceId)
        .order('timestamp', ascending: false)
        .limit(1)
        .map((rows) => rows.isEmpty ? null : EnergyReading.fromMap(rows.first));
  }

  Future<List<EnergyReading>> getReadingsHistory(String deviceId, {int hours = 24}) async {
    final since = DateTime.now().subtract(Duration(hours: hours)).toUtc().toIso8601String();
    final rows = await _db.from('energy_readings').select()
        .eq('device_id', deviceId)
        .gt('timestamp', since)
        .order('timestamp');
    return rows.map(EnergyReading.fromMap).toList();
  }

  /// Readings of all the user's devices between two dates (used by reports / analytics).
  Future<List<EnergyReading>> getReadingsBetween(DateTime from, DateTime to, {List<String>? deviceIds}) async {
    var q = _db.from('energy_readings').select()
        .gte('timestamp', from.toUtc().toIso8601String())
        .lt('timestamp', to.toUtc().toIso8601String());
    if (deviceIds != null) q = q.inFilter('device_id', deviceIds);
    final rows = await q.order('timestamp');
    return rows.map(EnergyReading.fromMap).toList();
  }

  // ── DASHBOARD CALCULATIONS (SQL functions in 002_app_features.sql) ──
  /// kWh used per zone between two times → {zoneId: kWh}.
  Future<Map<String, double>> zoneUsage(DateTime from, DateTime to) async {
    final rows = await _db.rpc('zone_usage', params: {
      'p_from': from.toUtc().toIso8601String(), 'p_to': to.toUtc().toIso8601String(),
    }) as List;
    return {for (final r in rows) r['zone_id'] as String: (r['kwh'] as num).toDouble()};
  }

  /// Usage grouped by 'hour' or 'day', optionally for one zone.
  Future<List<UsageBucket>> usageBuckets(DateTime from, DateTime to, {String bucket = 'hour', String? zoneId}) async {
    final rows = await _db.rpc('usage_buckets', params: {
      'p_from': from.toUtc().toIso8601String(), 'p_to': to.toUtc().toIso8601String(),
      'p_bucket': bucket, 'p_zone': zoneId,
    }) as List;
    return rows.map((r) => UsageBucket.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Newest reading of every device that sent data in the last 10 minutes.
  Future<List<EnergyReading>> latestReadings() async {
    final rows = await _db.rpc('latest_readings') as List;
    return rows.map((r) => EnergyReading.fromMap(r as Map<String, dynamic>)).toList();
  }

  // ── ALERTS ────────────────────────────────────────────
  Stream<List<AlertModel>> alertsStream() {
    return _db.from('alerts').stream(primaryKey: ['alert_id'])
        .order('alert_time', ascending: false)
        .limit(50)
        .map((rows) => rows.map(AlertModel.fromMap).toList());
  }

  /// All alerts between two dates, newest first (used by the PDF report).
  Future<List<AlertModel>> alertsBetween(DateTime from, DateTime to) async {
    final rows = await _db.from('alerts').select()
        .gte('alert_time', from.toUtc().toIso8601String())
        .lt('alert_time', to.toUtc().toIso8601String())
        .order('alert_time', ascending: false);
    return rows.map(AlertModel.fromMap).toList();
  }

  Future<void> acknowledgeAlert(String alertId) {
    return _db.from('alerts').update({'is_acknowledged': true}).eq('alert_id', alertId);
  }
}
