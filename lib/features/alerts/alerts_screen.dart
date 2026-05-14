// lib/features/alerts/alerts_screen.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _filterIdx = 0;
  final _filters = ['All', 'High', 'Medium', 'Low', 'Resolved'];
  int? _expandedIdx;

  final _alerts = [
    {
      'type': 'Voltage Anomaly', 'severity': 'high', 'alertType': 'voltage_low',
      'zone': 'Lobby', 'device': 'ESP32-004', 'time': 'Today, 09:38',
      'reading': '198.2 V (nominal 230V)', 'ack': false,
      'action': 'Check main distribution panel for Lobby. Verify breaker status and inspect wiring connections.',
      'resolved': false,
    },
    {
      'type': 'Overload Warning', 'severity': 'medium', 'alertType': 'overload',
      'zone': 'Kitchen', 'device': 'ESP32-002', 'time': 'Today, 09:21',
      'reading': '24.8 A (limit 20 A)', 'ack': false,
      'action': 'Reduce load in Kitchen zone. Consider redistributing appliances to different circuits.',
      'resolved': false,
    },
    {
      'type': 'AI Anomaly Detected', 'severity': 'medium', 'alertType': 'anomaly',
      'zone': 'Server Room', 'device': 'ESP32-003', 'time': 'Today, 08:55',
      'reading': 'Confidence: 87.4%', 'ack': false,
      'action': 'Unusual consumption pattern detected between 08:40–08:55. Review server load and HVAC logs.',
      'resolved': false,
    },
    {
      'type': 'Voltage Restored', 'severity': 'low', 'alertType': 'voltage_high',
      'zone': 'Office', 'device': 'ESP32-001', 'time': 'Yesterday, 17:22',
      'reading': 'Resolved automatically', 'ack': true,
      'action': 'No action required.',
      'resolved': true,
    },
  ];

  Color _severityColor(String severity) => switch (severity) {
    'high' => AppColors.red,
    'medium' => AppColors.orange,
    _ => AppColors.green,
  };

  IconData _alertIcon(String type) => switch (type) {
    'voltage_low' || 'voltage_high' => Icons.warning_amber_rounded,
    'overload' => Icons.bolt,
    'anomaly' => Icons.psychology,
    _ => Icons.check_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    final filtered = _alerts.where((a) {
      if (_filterIdx == 0) return true;
      if (_filterIdx == 4) return a['resolved'] as bool;
      final severities = ['', 'high', 'medium', 'low'];
      return a['severity'] == severities[_filterIdx] && !(a['resolved'] as bool);
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Alerts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('3 unacknowledged', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.red.withOpacity(0.3)),
                    ),
                    child: const Text('3 Active', style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: _filters.asMap().entries.map((e) => GestureDetector(
                  onTap: () => setState(() { _filterIdx = e.key; _expandedIdx = null; }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _filterIdx == e.key ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _filterIdx == e.key ? AppColors.accent : AppColors.border),
                    ),
                    child: Text(e.value, style: TextStyle(fontSize: 12, color: _filterIdx == e.key ? AppColors.accent : AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  ),
                )).toList(),
              ),
            ),
            // Alerts list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final a = filtered[i];
                  final severity = a['severity'] as String;
                  final sColor = _severityColor(severity);
                  final acked = a['ack'] as bool;
                  final resolved = a['resolved'] as bool;
                  final expanded = _expandedIdx == i;

                  return GestureDetector(
                    onTap: () => setState(() => _expandedIdx = expanded ? null : i),
                    child: Opacity(
                      opacity: resolved ? 0.5 : 1.0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: expanded ? sColor.withOpacity(0.4) : AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(color: sColor.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
                                  child: Icon(_alertIcon(a['alertType'] as String), color: sColor, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Text(a['type'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(color: sColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                                        child: Text(severity[0].toUpperCase() + severity.substring(1), style: TextStyle(fontSize: 10, color: sColor, fontWeight: FontWeight.w600)),
                                      ),
                                    ]),
                                    Text('${a['zone']} · ${a['device']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    Text(a['time'] as String, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                                  ]),
                                ),
                                Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textTertiary, size: 18),
                              ],
                            ),
                            if (expanded) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                                child: Column(
                                  children: [
                                    _DetailRow('Alert type', a['alertType'] as String, valueColor: sColor),
                                    _DetailRow('Severity', severity[0].toUpperCase() + severity.substring(1)),
                                    _DetailRow('Device', a['device'] as String),
                                    _DetailRow('Reading', a['reading'] as String),
                                    _DetailRow('Time', a['time'] as String),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentBlue.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.lightbulb_outline, color: AppColors.accentBlue, size: 14),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(a['action'] as String, style: const TextStyle(fontSize: 11, color: AppColors.accentBlue))),
                                        ],
                                      ),
                                    ),
                                    if (!acked && !resolved)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.green, foregroundColor: Colors.black,
                                              minimumSize: const Size(double.infinity, 40),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                            ),
                                            onPressed: () => setState(() { a['ack'] = true; }),
                                            child: const Text('Acknowledge Alert', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                          ),
                                        ),
                                      ),
                                    if (acked)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          Icon(Icons.check_circle, color: AppColors.green, size: 14),
                                          SizedBox(width: 4),
                                          Text('Acknowledged', style: TextStyle(color: AppColors.green, fontSize: 12)),
                                        ]),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _DetailRow(String key, String val, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(key, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary)),
      ],
    ),
  );
}
