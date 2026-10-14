// Phone notifications (Android / iOS) using flutter_local_notifications.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _plugin = FlutterLocalNotificationsPlugin();
bool _ready = false;

Future<bool> initNotifications() async {
  if (_ready) return true;
  try {
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    _ready = true;
  } catch (_) {
    // Desktop builds (Windows etc.) have no settings above → no notifications.
  }
  return _ready;
}

Future<bool> requestNotificationPermission() async {
  if (!await initNotifications()) return false;
  final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  return await android?.requestNotificationsPermission()
      ?? await ios?.requestPermissions(alert: true, sound: true, badge: true)
      ?? true;
}

Future<void> showNotification(int id, String title, String body) async {
  if (!_ready) return;
  await _plugin.show(id, title, body, const NotificationDetails(
    android: AndroidNotificationDetails('energy_alerts', 'Energy alerts',
        channelDescription: 'Abnormal usage, overload and voltage alerts',
        importance: Importance.high, priority: Priority.high),
    iOS: DarwinNotificationDetails(),
  ));
}
