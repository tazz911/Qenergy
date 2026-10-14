// Browser notifications (used when the app runs in Chrome / Edge).
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> initNotifications() async => _granted;

Future<bool> requestNotificationPermission() async {
  if (_granted) return true;
  if (web.Notification.permission == 'denied') return false;
  final result = await web.Notification.requestPermission().toDart;
  return result.toDart == 'granted';
}

Future<void> showNotification(int id, String title, String body) async {
  if (!_granted) return;
  web.Notification(title, web.NotificationOptions(body: body, icon: 'icons/Icon-192.png', tag: 'energyiq-$id'));
}

bool get _granted => web.Notification.permission == 'granted';
