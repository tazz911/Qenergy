// lib/core/utils/format.dart
// Small shared helpers for showing data on screens.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

/// Electricity price used for the "Cost est." card. Change to match your tariff.
const tariffOmrPerKwh = 0.014;

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

String timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

String friendlyTime(DateTime t) {
  final today = startOfDay(DateTime.now());
  final day = startOfDay(t);
  final hm = DateFormat('HH:mm').format(t);
  if (day == today) return 'Today, $hm';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday, $hm';
  return '${DateFormat('d MMM').format(t)}, $hm';
}

/// A device counts as online if it sent a reading in the last 2 minutes.
bool isOnline(DeviceModel d) =>
    d.lastSeenAt != null && DateTime.now().difference(d.lastSeenAt!).inMinutes < 2;

IconData zoneIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('kitchen')) return Icons.kitchen;
  if (n.contains('office')) return Icons.business;
  if (n.contains('server')) return Icons.storage;
  if (n.contains('lobby') || n.contains('entrance')) return Icons.door_front_door;
  if (n.contains('bed')) return Icons.bed;
  if (n.contains('living') || n.contains('majlis')) return Icons.weekend;
  if (n.contains('bath')) return Icons.bathtub;
  if (n.contains('garage')) return Icons.garage;
  return Icons.grid_view;
}

Color severityColor(String severity) => switch (severity) {
  'high' => AppColors.red,
  'medium' => AppColors.orange,
  _ => AppColors.green,
};

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String alertTitle(String type) => switch (type) {
  'voltage_high' => 'High Voltage',
  'voltage_low' => 'Low Voltage',
  'overload' => 'Overload Warning',
  'anomaly' => 'AI Anomaly Detected',
  _ => 'Alert',
};

IconData alertIcon(String type) => switch (type) {
  'voltage_low' || 'voltage_high' => Icons.warning_amber_rounded,
  'overload' => Icons.bolt,
  'anomaly' => Icons.psychology,
  _ => Icons.info_outline,
};

/// Recommended action shown under each alert.
String alertAdvice(String type) => switch (type) {
  'voltage_low' => 'Check the distribution panel for this zone. Verify breaker status and inspect wiring connections.',
  'voltage_high' => 'Voltage is above the safe limit. Unplug sensitive electronics and contact the electricity provider if it continues.',
  'overload' => 'Reduce load in this zone. Consider moving some appliances to a different circuit.',
  'anomaly' => 'Unusual consumption pattern. Check for appliances left on or a faulty device.',
  _ => 'Review this zone.',
};

/// Zone status from its open (not acknowledged) alerts.
({String label, Color color}) zoneStatus(ZoneModel zone, List<AlertModel> openAlerts) {
  if (!zone.isActive) return (label: 'Inactive', color: AppColors.textSecondary);
  if (openAlerts.any((a) => a.severity == 'high')) return (label: 'Anomaly', color: AppColors.red);
  if (openAlerts.isNotEmpty) return (label: 'High Load', color: AppColors.orange);
  return (label: 'Normal', color: AppColors.green);
}
