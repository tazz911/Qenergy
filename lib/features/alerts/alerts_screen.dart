// lib/features/alerts/alerts_screen.dart
// Live alerts from Supabase. "Acknowledge" saves is_acknowledged = true.
import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _svc = SupabaseService();
  late final Stream<List<AlertModel>> _alerts$;
  Map<String, DeviceModel> _devices = {};
  Map<String, String> _zoneNames = {};
  int _filterIdx = 0;
  final _filters = ['All', 'High', 'Medium', 'Low', 'Resolved'];
  String? _expandedId;
  final _triedDeviceIds = <String>{}; // devices we already reloaded names for

  @override
  void initState() {
    super.initState();
    _alerts$ = _svc.alertsStream();
    _loadNames();
  }

  Future<void> _loadNames() async {
    try {
      final results = await Future.wait([_svc.getAllDevices(), _svc.getZones()]);
      if (!mounted) return;
      setState(() {
        _devices = {for (final d in results[0] as List<DeviceModel>) d.deviceId: d};
        _zoneNames = {for (final z in results[1] as List<ZoneModel>) z.zoneId: z.zoneName};
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<AlertModel>>(
          stream: _alerts$,
          builder: (context, snap) {
            final alerts = snap.data ?? [];
            // A new alert may come from a device added after this screen loaded.
            final missing = alerts.map((a) => a.deviceId)
                .where((id) => !_devices.containsKey(id) && !_triedDeviceIds.contains(id)).toSet();
            if (missing.isNotEmpty) {
              _triedDeviceIds.addAll(missing);
              _loadNames();
            }
            final openCount = alerts.where((a) => !a.isAcknowledged).length;
            final filtered = alerts.where((a) {
              if (_filterIdx == 0) return true;
              if (_filterIdx == 4) return a.isAcknowledged;
              const severities = ['', 'high', 'medium', 'low'];
              return a.severity == severities[_filterIdx] && !a.isAcknowledged;
            }).toList();

            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Alerts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text('$openCount unacknowledged', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (openCount > 0 ? AppColors.red : AppColors.green).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: (openCount > 0 ? AppColors.red : AppColors.green).withOpacity(0.3)),
                        ),
                        child: Text('$openCount Active', style: TextStyle(color: openCount > 0 ? AppColors.red : AppColors.green, fontSize: 12, fontWeight: FontWeight.w600)),
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
                      onTap: () => setState(() { _filterIdx = e.key; _expandedId = null; }),
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
                  child: !snap.hasData
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : filtered.isEmpty
                          ? const Center(child: Text('No alerts here.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) => _AlertCard(filtered[i]),
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _AlertCard(AlertModel a) {
    final sColor = severityColor(a.severity);
    final expanded = _expandedId == a.alertId;
    final device = _devices[a.deviceId];
    final zoneName = device == null ? 'Unknown zone' : (_zoneNames[device.zoneId] ?? 'Zone');
    final deviceLabel = device?.serialNumber ?? 'Device';

    return GestureDetector(
      onTap: () => setState(() => _expandedId = expanded ? null : a.alertId),
      child: Opacity(
        opacity: a.isAcknowledged ? 0.5 : 1.0,
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
                    child: Icon(alertIcon(a.alertType), color: sColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(alertTitle(a.alertType), overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: sColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text(capitalize(a.severity), style: TextStyle(fontSize: 10, color: sColor, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      Text('$zoneName · $deviceLabel', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text(friendlyTime(a.alertTime), style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
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
                      _DetailRow('Alert type', a.alertType, valueColor: sColor),
                      _DetailRow('Severity', capitalize(a.severity)),
                      _DetailRow('Device', device?.deviceName ?? deviceLabel),
                      _DetailRow('Reading', a.message),
                      _DetailRow('Time', friendlyTime(a.alertTime)),
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
                            Expanded(child: Text(alertAdvice(a.alertType), style: const TextStyle(fontSize: 11, color: AppColors.accentBlue))),
                          ],
                        ),
                      ),
                      if (!a.isAcknowledged)
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
                              onPressed: () async {
                                try {
                                  await _svc.acknowledgeAlert(a.alertId);
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                      content: Text('Could not save. Check your internet.'), backgroundColor: AppColors.red));
                                  }
                                }
                              },
                              child: const Text('Acknowledge Alert', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        )
                      else
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
  }

  Widget _DetailRow(String key, String val, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(key, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
        Expanded(child: Text(val, textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary))),
      ],
    ),
  );
}
