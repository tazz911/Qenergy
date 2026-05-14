// lib/core/models/models.dart

class UserModel {
  final String userId;
  final String fullName;
  final String email;
  final DateTime createdAt;

  UserModel({required this.userId, required this.fullName, required this.email, required this.createdAt});

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['user_id'] ?? '',
      fullName: map['full_name'] ?? '',
      email: map['email'] ?? '',
      createdAt: (map['created_at'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
  Map<String, dynamic> toMap() => {
    'user_id': userId, 'full_name': fullName, 'email': email, 'created_at': createdAt,
  };
}

class ZoneModel {
  final String zoneId;
  final String userId;
  final String zoneName;
  final String? location;
  final String status; // active / inactive
  final DateTime createdAt;

  ZoneModel({required this.zoneId, required this.userId, required this.zoneName, this.location, required this.status, required this.createdAt});

  factory ZoneModel.fromMap(Map<String, dynamic> map, String id) {
    return ZoneModel(
      zoneId: id,
      userId: map['user_id'] ?? '',
      zoneName: map['zone_name'] ?? '',
      location: map['location'],
      status: map['status'] ?? 'active',
      createdAt: (map['created_at'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
  Map<String, dynamic> toMap() => {
    'user_id': userId, 'zone_name': zoneName, 'location': location,
    'status': status, 'created_at': createdAt,
  };
  bool get isActive => status == 'active';
}

class DeviceModel {
  final String deviceId;
  final String zoneId;
  final String deviceName;
  final String deviceType;
  final String serialNumber;
  final String status;
  final DateTime installedAt;
  final DateTime? lastSeenAt;

  DeviceModel({required this.deviceId, required this.zoneId, required this.deviceName,
    required this.deviceType, required this.serialNumber, required this.status,
    required this.installedAt, this.lastSeenAt});

  factory DeviceModel.fromMap(Map<String, dynamic> map, String id) {
    return DeviceModel(
      deviceId: id,
      zoneId: map['zone_id'] ?? '',
      deviceName: map['device_name'] ?? '',
      deviceType: map['device_type'] ?? '',
      serialNumber: map['serial_number'] ?? '',
      status: map['status'] ?? 'active',
      installedAt: (map['installed_at'] as dynamic)?.toDate() ?? DateTime.now(),
      lastSeenAt: (map['last_seen_at'] as dynamic)?.toDate(),
    );
  }
}

class EnergyReading {
  final String reportId;
  final String deviceId;
  final DateTime timestamp;
  final double voltage;
  final double current;
  final double power;
  final double energyKwh;
  final double? powerFactor;

  EnergyReading({required this.reportId, required this.deviceId, required this.timestamp,
    required this.voltage, required this.current, required this.power,
    required this.energyKwh, this.powerFactor});

  factory EnergyReading.fromMap(Map<String, dynamic> map, String id) {
    return EnergyReading(
      reportId: id,
      deviceId: map['device_id'] ?? '',
      timestamp: (map['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      voltage: (map['voltage'] ?? 0).toDouble(),
      current: (map['current'] ?? 0).toDouble(),
      power: (map['power'] ?? 0).toDouble(),
      energyKwh: (map['energy_kwh'] ?? 0).toDouble(),
      powerFactor: map['power_factor']?.toDouble(),
    );
  }
}

class AlertModel {
  final String alertId;
  final String deviceId;
  final String? readingId;
  final String alertType; // overload / anomaly / voltage_high / voltage_low
  final String severity; // low / medium / high
  final String message;
  final DateTime alertTime;
  final bool isAcknowledged;

  AlertModel({required this.alertId, required this.deviceId, this.readingId,
    required this.alertType, required this.severity, required this.message,
    required this.alertTime, required this.isAcknowledged});

  factory AlertModel.fromMap(Map<String, dynamic> map, String id) {
    return AlertModel(
      alertId: id,
      deviceId: map['device_id'] ?? '',
      readingId: map['reading_id'],
      alertType: map['alert_type'] ?? '',
      severity: map['severity'] ?? 'low',
      message: map['message'] ?? '',
      alertTime: (map['alert_time'] as dynamic)?.toDate() ?? DateTime.now(),
      isAcknowledged: map['is_acknowledged'] ?? false,
    );
  }
  Map<String, dynamic> toMap() => {
    'device_id': deviceId, 'reading_id': readingId, 'alert_type': alertType,
    'severity': severity, 'message': message, 'alert_time': alertTime,
    'is_acknowledged': isAcknowledged,
  };
}
