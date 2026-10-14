// lib/core/models/models.dart
// Field names match the Supabase tables in supabase/schema.sql.

DateTime _date(dynamic v) => v == null ? DateTime.now() : DateTime.parse(v as String).toLocal();
double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();

class UserModel {
  final String userId;
  final String fullName;
  final String email;
  final DateTime createdAt;
  // Settings screen
  final double voltageMin;
  final double voltageMax;
  final double currentMax;
  final bool pushNotifications;
  final bool anomalyAlerts;
  final bool emailReports;

  UserModel({required this.userId, required this.fullName, required this.email, required this.createdAt,
    this.voltageMin = 210, this.voltageMax = 250, this.currentMax = 20,
    this.pushNotifications = true, this.anomalyAlerts = true, this.emailReports = false});

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['user_id'] ?? '',
      fullName: map['full_name'] ?? '',
      email: map['email'] ?? '',
      createdAt: _date(map['created_at']),
      voltageMin: map['voltage_min'] == null ? 210 : _num(map['voltage_min']),
      voltageMax: map['voltage_max'] == null ? 250 : _num(map['voltage_max']),
      currentMax: map['current_max'] == null ? 20 : _num(map['current_max']),
      pushNotifications: map['push_notifications'] ?? true,
      anomalyAlerts: map['anomaly_alerts'] ?? true,
      emailReports: map['email_reports'] ?? false,
    );
  }
}

class ZoneModel {
  final String zoneId;
  final String userId;
  final String zoneName;
  final String? location;
  final String status; // active / inactive
  final DateTime createdAt;

  ZoneModel({required this.zoneId, required this.userId, required this.zoneName, this.location, required this.status, required this.createdAt});

  factory ZoneModel.fromMap(Map<String, dynamic> map) {
    return ZoneModel(
      zoneId: map['zone_id'],
      userId: map['user_id'] ?? '',
      zoneName: map['zone_name'] ?? '',
      location: map['location'],
      status: map['status'] ?? 'active',
      createdAt: _date(map['created_at']),
    );
  }
  bool get isActive => status == 'active';
}

class DeviceModel {
  final String deviceId;
  final String zoneId;
  final String deviceName;
  final String deviceType; // ESP32 / meter / sensor
  final String serialNumber;
  final String apiKey;
  final String status;
  final DateTime installedAt;
  final DateTime? lastSeenAt;

  DeviceModel({required this.deviceId, required this.zoneId, required this.deviceName,
    required this.deviceType, required this.serialNumber, required this.apiKey,
    required this.status, required this.installedAt, this.lastSeenAt});

  factory DeviceModel.fromMap(Map<String, dynamic> map) {
    return DeviceModel(
      deviceId: map['device_id'],
      zoneId: map['zone_id'] ?? '',
      deviceName: map['device_name'] ?? '',
      deviceType: map['device_type'] ?? 'meter',
      serialNumber: map['serial_number'] ?? '',
      apiKey: map['api_key'] ?? '',
      status: map['status'] ?? 'active',
      installedAt: _date(map['installed_at']),
      lastSeenAt: map['last_seen_at'] == null ? null : _date(map['last_seen_at']),
    );
  }
  bool get isActive => status == 'active';
}

class EnergyReading {
  final int readingId;
  final String deviceId;
  final DateTime timestamp;
  final double voltage;
  final double current;
  final double power;
  final double energyKwh;
  final double? powerFactor;

  EnergyReading({required this.readingId, required this.deviceId, required this.timestamp,
    required this.voltage, required this.current, required this.power,
    required this.energyKwh, this.powerFactor});

  factory EnergyReading.fromMap(Map<String, dynamic> map) {
    return EnergyReading(
      readingId: map['reading_id'],
      deviceId: map['device_id'] ?? '',
      timestamp: _date(map['timestamp']),
      voltage: _num(map['voltage']),
      current: _num(map['current']),
      power: _num(map['power']),
      energyKwh: _num(map['energy_kwh']),
      powerFactor: map['power_factor'] == null ? null : _num(map['power_factor']),
    );
  }
}

class AlertModel {
  final String alertId;
  final String deviceId;
  final int? readingId;
  final String alertType; // overload / anomaly / voltage_high / voltage_low
  final String severity; // low / medium / high
  final String message;
  final DateTime alertTime;
  final bool isAcknowledged;

  AlertModel({required this.alertId, required this.deviceId, this.readingId,
    required this.alertType, required this.severity, required this.message,
    required this.alertTime, required this.isAcknowledged});

  factory AlertModel.fromMap(Map<String, dynamic> map) {
    return AlertModel(
      alertId: map['alert_id'],
      deviceId: map['device_id'] ?? '',
      readingId: map['reading_id'],
      alertType: map['alert_type'] ?? '',
      severity: map['severity'] ?? 'low',
      message: map['message'] ?? '',
      alertTime: _date(map['alert_time']),
      isAcknowledged: map['is_acknowledged'] ?? false,
    );
  }
}

/// One bar/point on a chart: usage in one hour or one day.
class UsageBucket {
  final DateTime bucket;
  final double kwh;
  final double avgVoltage;
  final double maxPower; // W

  UsageBucket({required this.bucket, required this.kwh, required this.avgVoltage, required this.maxPower});

  factory UsageBucket.fromMap(Map<String, dynamic> map) {
    return UsageBucket(
      bucket: _date(map['bucket']),
      kwh: _num(map['kwh']),
      avgVoltage: _num(map['avg_voltage']),
      maxPower: _num(map['max_power']),
    );
  }
}
