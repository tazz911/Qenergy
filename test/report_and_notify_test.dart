import 'package:flutter_test/flutter_test.dart';
import 'package:energyiq/core/models/models.dart';
import 'package:energyiq/core/services/notification_service.dart';
import 'package:energyiq/features/analytics/report_pdf.dart';

AlertModel _alert(String id, {String type = 'overload', bool ack = false}) => AlertModel(
    alertId: id, deviceId: 'd1', alertType: type, severity: 'high',
    message: 'Current 25 A', alertTime: DateTime(2026, 10, 7, 10), isAcknowledged: ack);

UserModel _user({bool push = true, bool anomaly = true}) => UserModel(
    userId: 'u1', fullName: 'Test', email: 't@t.com', createdAt: DateTime(2026),
    pushNotifications: push, anomalyAlerts: anomaly);

void main() {
  group('M7F2 notifications', () {
    test('alerts that existed when the app opened are not notified', () {
      final n = NotificationService.instance..reset();
      expect(n.handle([_alert('a1')], _user()), isEmpty);
    });

    test('a new alert is notified', () {
      final n = NotificationService.instance..reset();
      n.handle([_alert('a1')], _user());
      final fresh = n.handle([_alert('a2'), _alert('a1')], _user());
      expect(fresh.map((a) => a.alertId), ['a2']);
      expect(n.handle([_alert('a2'), _alert('a1')], _user()), isEmpty); // not twice
    });

    test('push switch off = no notifications', () {
      expect(NotificationService.allowed(_alert('a'), _user(push: false)), isFalse);
    });

    test('anomaly switch off blocks only anomaly alerts', () {
      final u = _user(anomaly: false);
      expect(NotificationService.allowed(_alert('a', type: 'anomaly'), u), isFalse);
      expect(NotificationService.allowed(_alert('b', type: 'voltage_high'), u), isTrue);
    });

    test('acknowledged alerts are not notified', () {
      expect(NotificationService.allowed(_alert('a', ack: true), _user()), isFalse);
    });
  });

  group('M6F1 report', () {
    test('builds a PDF file', () async {
      final bytes = await buildEnergyReport(EnergyReportData(
        ownerName: 'Yahya', from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 8),
        periodName: 'This Week', zoneName: 'All zones', hourly: false,
        buckets: [UsageBucket(bucket: DateTime(2026, 10, 2), kwh: 3.5, avgVoltage: 231, maxPower: 2400)],
        zoneRows: [(name: 'Kitchen', kwh: 3.5)],
        alerts: [_alert('a1')], deviceZone: {'d1': 'Kitchen'},
      ));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });
  });
}
