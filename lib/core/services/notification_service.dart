// lib/core/services/notification_service.dart
// Tracing sheet M7F2: notify the user when a new alert (abnormal usage /
// anomaly) arrives. Respects the "Push Notifications" and "Anomaly Alerts"
// switches in Settings (M7F1).
import '../models/models.dart';
import '../utils/format.dart';
import 'notify/notify_native.dart' if (dart.library.js_interop) 'notify/notify_web.dart' as platform;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final Set<String> _seen = {};
  bool _firstBatch = true;

  Future<void> init() => platform.initNotifications();

  /// Ask the phone / browser for permission. Returns true if allowed.
  Future<bool> requestPermission() => platform.requestNotificationPermission();

  /// Should this alert be notified, given the user's settings?
  static bool allowed(AlertModel a, UserModel? user) {
    if (a.isAcknowledged) return false;
    if (!(user?.pushNotifications ?? true)) return false;
    if (a.alertType == 'anomaly' && !(user?.anomalyAlerts ?? true)) return false;
    return true;
  }

  /// Give it every alerts list from the realtime stream. Alerts that existed
  /// when the app opened are skipped; only new ones are returned and notified.
  List<AlertModel> handle(List<AlertModel> alerts, UserModel? user) {
    final fresh = alerts.where((a) => !_seen.contains(a.alertId)).toList();
    _seen.addAll(fresh.map((a) => a.alertId));
    if (_firstBatch) { _firstBatch = false; return const []; }
    final toNotify = fresh.where((a) => allowed(a, user)).toList();
    for (final a in toNotify) {
      platform.showNotification(a.alertId.hashCode & 0x7fffffff,
          'EnergyIQ: ${alertTitle(a.alertType)}', a.message);
    }
    return toNotify;
  }

  /// Call on logout so the next user starts clean.
  void reset() { _seen.clear(); _firstBatch = true; }
}
