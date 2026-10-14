// lib/features/zones/zone_detail_screen.dart
// One zone: live readings, 7-day usage, devices (add / view / delete), AI note.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../devices/device_dialogs.dart';

class ZoneDetailScreen extends StatefulWidget {
  final ZoneModel zone;
  const ZoneDetailScreen({super.key, required this.zone});
  @override State<ZoneDetailScreen> createState() => _ZoneDetailScreenState();
}

class _ZoneDetailScreenState extends State<ZoneDetailScreen> {
  final _svc = SupabaseService();
  late final Stream<List<DeviceModel>> _devices$;
  late final Stream<List<AlertModel>> _alerts$;
  Timer? _timer;
  List<EnergyReading> _latest = [];
  List<double> _week = List.filled(7, 0); // kWh per day, oldest → today
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _devices$ = _svc.devicesStream(widget.zone.zoneId);
    _alerts$ = _svc.alertsStream();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _refresh() async {
    try {
      final today = startOfDay(DateTime.now());
      final from = today.subtract(const Duration(days: 6));
      final results = await Future.wait([
        _svc.latestReadings(),
        _svc.usageBuckets(from, today.add(const Duration(days: 1)), bucket: 'day', zoneId: widget.zone.zoneId),
      ]);
      final buckets = results[1] as List<UsageBucket>;
      final week = List<double>.filled(7, 0);
      for (final b in buckets) {
        final i = startOfDay(b.bucket).difference(from).inDays;
        if (i >= 0 && i < 7) week[i] = b.kwh;
      }
      if (!mounted) return;
      setState(() {
        _latest = results[0] as List<EnergyReading>;
        _week = week;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DeviceModel>>(
      stream: _devices$,
      builder: (context, devSnap) {
        final devices = devSnap.data ?? [];
        final ids = devices.map((d) => d.deviceId).toSet();
        return StreamBuilder<List<AlertModel>>(
          stream: _alerts$,
          builder: (context, alertSnap) {
            final open = (alertSnap.data ?? [])
                .where((a) => ids.contains(a.deviceId) && !a.isAcknowledged).toList();
            final status = zoneStatus(widget.zone, open);
            final live = _latest.where((r) => ids.contains(r.deviceId)).toList();
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
                title: Text(widget.zone.zoneName),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Icon(Icons.circle, color: status.color, size: 6),
                      const SizedBox(width: 4),
                      Text(status.label, style: TextStyle(color: status.color, fontSize: 12)),
                    ]),
                  ),
                ],
              ),
              body: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _ReadingsGrid(live),
                        _WeekChart(),
                        _DevicesCard(devices),
                        _AiCard(open, live),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _ReadingsGrid(List<EnergyReading> live) {
    final hasLive = live.isNotEmpty;
    final voltage = hasLive ? live.map((r) => r.voltage).reduce((a, b) => a + b) / live.length : 0.0;
    final current = live.fold(0.0, (s, r) => s + r.current);
    final power = live.fold(0.0, (s, r) => s + r.power) / 1000;
    final today = _week.last, yesterday = _week[5];
    final vsYesterday = yesterday > 0 ? ((today - yesterday) / yesterday * 100) : null;
    final liveText = hasLive ? 'Live' : 'No live data';
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20), mainAxisSpacing: 12, crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _ReadingCard(label: 'Voltage', value: hasLive ? voltage.toStringAsFixed(1) : '--', unit: 'Volts (V)', trend: liveText, bad: !hasLive),
        _ReadingCard(label: 'Current', value: hasLive ? current.toStringAsFixed(1) : '--', unit: 'Amperes (A)', trend: liveText, bad: !hasLive),
        _ReadingCard(label: 'Power', value: hasLive ? power.toStringAsFixed(2) : '--', unit: 'Kilowatts (kW)', trend: liveText, bad: !hasLive),
        _ReadingCard(
          label: 'Energy', value: today.toStringAsFixed(2), unit: 'kWh today',
          trend: vsYesterday == null ? 'No data for yesterday'
              : '${vsYesterday >= 0 ? '↑' : '↓'} ${vsYesterday.abs().toStringAsFixed(0)}% vs yesterday',
          bad: (vsYesterday ?? 0) > 0,
        ),
      ],
    );
  }

  Widget _WeekChart() {
    final from = startOfDay(DateTime.now()).subtract(const Duration(days: 6));
    final maxY = [..._week, 1.0].reduce((a, b) => a > b ? a : b) * 1.2;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Last 7 days (kWh)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                  getTitlesWidget: (v, _) => Text(DateFormat('E').format(from.add(Duration(days: v.toInt()))),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)))),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                  getTitlesWidget: (v, _) => Text(v.toStringAsFixed(v < 10 ? 1 : 0), style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)))),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _week.asMap().entries.map((e) =>
                BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(toY: e.value, width: 20, borderRadius: BorderRadius.circular(4),
                    color: AppColors.accent.withOpacity(0.7), backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: AppColors.bg3)),
                ]),
              ).toList(),
            )),
          ),
        ],
      ),
    );
  }

  Widget _DevicesCard(List<DeviceModel> devices) => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(child: Text('Devices', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          GestureDetector(
            onTap: () => showAddDeviceDialog(context, zoneId: widget.zone.zoneId),
            child: const Text('+ Add device', style: TextStyle(fontSize: 12, color: AppColors.accent)),
          ),
        ]),
        const SizedBox(height: 10),
        if (devices.isEmpty)
          const Text('No devices in this zone yet. Add the meter installed in this zone.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ...devices.map((d) {
          final online = isOnline(d);
          return InkWell(
            onTap: () => showDeviceDetailsDialog(context, d, zoneName: widget.zone.zoneName),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(Icons.electric_meter_outlined, size: 18, color: online ? AppColors.green : AppColors.textTertiary),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.deviceName, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  Text('${d.serialNumber} · ${d.deviceType}${d.isActive ? '' : ' · inactive'}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ])),
                Text(online ? 'Online' : (d.lastSeenAt == null ? 'Never connected' : 'Offline'),
                    style: TextStyle(fontSize: 11, color: online ? AppColors.green : AppColors.textTertiary)),
                const Icon(Icons.chevron_right, size: 16, color: AppColors.textTertiary),
              ]),
            ),
          );
        }),
      ],
    ),
  );

  Widget _AiCard(List<AlertModel> open, List<EnergyReading> live) {
    final String text;
    if (open.isNotEmpty) {
      text = '${open.length} open alert${open.length == 1 ? '' : 's'}. Latest: ${open.first.message}. ${alertAdvice(open.first.alertType)}';
    } else if (!_loaded || (_week.every((v) => v == 0) && live.isEmpty)) {
      text = 'Not enough data yet. Analysis starts once the meter sends readings.';
    } else {
      text = 'Consumption pattern is within normal range. No anomalies detected.';
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology, color: AppColors.accentBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AI Analysis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentBlue)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  final String label, value, unit, trend;
  final bool bad;
  const _ReadingCard({required this.label, required this.value, required this.unit, required this.trend, required this.bad});

  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text(unit, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text(trend, style: TextStyle(fontSize: 10, color: bad ? AppColors.red : AppColors.green)),
    ]),
  );
}
