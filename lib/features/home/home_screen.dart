// lib/features/home/home_screen.dart
// Dashboard: today's total, live V/A/kW, zones, 24h chart, open alerts.
// Zones + alerts update live; numbers refresh every 10 seconds.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/providers/auth_provider.dart' as app;
import '../zones/zone_detail_screen.dart';
import '../zones/manage_zones_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSeeAllAlerts;
  const HomeScreen({super.key, this.onSeeAllAlerts});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _svc = SupabaseService();
  late final Stream<List<ZoneModel>> _zones$;
  late final Stream<List<AlertModel>> _alerts$;
  Timer? _timer;

  Map<String, double> _zoneKwh = {};
  List<UsageBucket> _hourly = [];
  List<EnergyReading> _latest = [];
  List<DeviceModel> _devices = [];

  @override
  void initState() {
    super.initState();
    _zones$ = _svc.zonesStream(_svc.currentUser!.id);
    _alerts$ = _svc.alertsStream();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _refresh() async {
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        _svc.zoneUsage(startOfDay(now), now.add(const Duration(minutes: 1))),
        _svc.usageBuckets(now.subtract(const Duration(hours: 23)).copyWith(minute: 0, second: 0), now.add(const Duration(minutes: 1))),
        _svc.latestReadings(),
        _svc.getAllDevices(),
      ]);
      if (!mounted) return;
      setState(() {
        _zoneKwh = results[0] as Map<String, double>;
        _hourly = results[1] as List<UsageBucket>;
        _latest = results[2] as List<EnergyReading>;
        _devices = results[3] as List<DeviceModel>;
      });
    } catch (_) {
      // keep showing the last values; next refresh will try again
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<ZoneModel>>(
          stream: _zones$,
          builder: (context, zoneSnap) => StreamBuilder<List<AlertModel>>(
            stream: _alerts$,
            builder: (context, alertSnap) {
              final zones = zoneSnap.data ?? [];
              final open = (alertSnap.data ?? []).where((a) => !a.isAcknowledged).toList();
              return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _Header(zones)),
                    SliverToBoxAdapter(child: _TotalCard()),
                    SliverToBoxAdapter(child: _SectionHeader('Zones', 'Manage', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageZonesScreen())))),
                    SliverToBoxAdapter(child: zoneSnap.hasData ? _ZonesList(zones, open) : const _Loading()),
                    SliverToBoxAdapter(child: _ChartCard()),
                    SliverToBoxAdapter(child: _SectionHeader('Open Alerts', 'See all', onTap: widget.onSeeAllAlerts ?? () {})),
                    SliverToBoxAdapter(child: _AlertsPreview(open, zones)),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _Header(List<ZoneModel> zones) {
    final user = context.watch<app.AuthProvider>().user;
    final fullName = user?.fullName ?? '';
    final firstName = fullName.split(' ').where((p) => p.isNotEmpty).firstOrNull ?? 'there';
    final initials = fullName.isNotEmpty ? _initials(fullName) : '?';
    final active = zones.where((z) => z.isActive).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_greeting()}, $firstName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('$active zone${active == 1 ? '' : 's'} active · ${_devices.length} device${_devices.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentBlue])),
            child: Center(child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black))),
          ),
        ],
      ),
    );
  }

  Widget _TotalCard() {
    final total = _zoneKwh.values.fold(0.0, (s, v) => s + v);
    final live = _latest.isNotEmpty;
    final voltage = live ? _latest.map((r) => r.voltage).reduce((a, b) => a + b) / _latest.length : 0.0;
    final current = _latest.fold(0.0, (s, r) => s + r.current);
    final power = _latest.fold(0.0, (s, r) => s + r.power) / 1000;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: live ? AppColors.green : AppColors.textTertiary)),
            const SizedBox(width: 6),
            Text(live ? 'Total consumption today · live' : 'Total consumption today · no live data',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          RichText(text: TextSpan(children: [
            TextSpan(text: total.toStringAsFixed(2), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: AppColors.accent, fontFamily: 'JetBrainsMono')),
            const TextSpan(text: ' kWh', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'SpaceGrotesk')),
          ])),
          const SizedBox(height: 16),
          Row(children: [
            _MiniStat('Voltage', live ? '${voltage.toStringAsFixed(1)} V' : '--', AppColors.accentBlue),
            const SizedBox(width: 12),
            _MiniStat('Current', live ? '${current.toStringAsFixed(1)} A' : '--', AppColors.accentAmber),
            const SizedBox(width: 12),
            _MiniStat('Power', live ? '${power.toStringAsFixed(2)} kW' : '--', AppColors.accent),
          ]),
        ],
      ),
    );
  }

  Widget _MiniStat(String label, String val, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
  );

  Widget _ZonesList(List<ZoneModel> zones, List<AlertModel> open) {
    if (zones.isEmpty) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageZonesScreen())),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: const Row(children: [
            Icon(Icons.add_circle_outline, color: AppColors.accent),
            SizedBox(width: 10),
            Expanded(child: Text('No zones yet. Tap here to add your first zone (e.g. Kitchen).',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          ]),
        ),
      );
    }
    final zoneOfDevice = {for (final d in _devices) d.deviceId: d.zoneId};
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: zones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final z = zones[i];
          final status = zoneStatus(z, open.where((a) => zoneOfDevice[a.deviceId] == z.zoneId).toList());
          final bgColor = status.color.withOpacity(0.12);
          return GestureDetector(
            onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => ZoneDetailScreen(zone: z))),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(9)),
                  child: Icon(zoneIcon(z.zoneName), color: status.color, size: 18),
                ),
                const SizedBox(height: 8),
                Text(z.zoneName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('${(_zoneKwh[z.zoneId] ?? 0).toStringAsFixed(2)} kWh', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(status.label, style: TextStyle(fontSize: 10, color: status.color, fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _ChartCard() {
    // x = 0 (23 hours ago) … 23 (this hour)
    final thisHour = DateTime.now().copyWith(minute: 0, second: 0, millisecond: 0, microsecond: 0);
    final spots = <FlSpot>[];
    for (final b in _hourly) {
      final x = 23 - thisHour.difference(b.bucket).inHours;
      if (x >= 0 && x <= 23) spots.add(FlSpot(x.toDouble(), b.kwh));
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Energy consumption (last 24h, kWh)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: spots.isEmpty
                ? const Center(child: Text('No readings in the last 24 hours',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary)))
                : LineChart(LineChartData(
                    minX: 0, maxX: 23, minY: 0,
                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 4,
                        getTitlesWidget: (v, _) => Text('${thisHour.subtract(Duration(hours: 23 - v.toInt())).hour}h',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)))),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                        getTitlesWidget: (v, _) => Text(v.toStringAsFixed(v < 10 ? 1 : 0), style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)))),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true, preventCurveOverShooting: true,
                        color: AppColors.accent, barWidth: 2, dotData: FlDotData(show: spots.length < 3),
                        belowBarData: BarAreaData(show: true, color: AppColors.accent.withOpacity(0.08)),
                      ),
                    ],
                  )),
          ),
        ],
      ),
    );
  }

  Widget _AlertsPreview(List<AlertModel> open, List<ZoneModel> zones) {
    if (open.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: const Row(children: [
            Icon(Icons.check_circle_outline, color: AppColors.green, size: 18),
            SizedBox(width: 10),
            Text('No open alerts. Everything looks normal.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      );
    }
    final devices = {for (final d in _devices) d.deviceId: d};
    final zoneNames = {for (final z in zones) z.zoneId: z.zoneName};
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: open.take(2).map((a) {
          final d = devices[a.deviceId];
          final where = d == null ? 'Unknown device' : '${zoneNames[d.zoneId] ?? 'Zone'} · ${d.serialNumber}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AlertRow(alertIcon(a.alertType), severityColor(a.severity), alertTitle(a.alertType), where,
                capitalize(a.severity), timeAgo(a.alertTime)),
          );
        }).toList(),
      ),
    );
  }

  Widget _AlertRow(IconData icon, Color color, String title, String sub, String severity, String time) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Row(
      children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text(time, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(severity, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override Widget build(BuildContext context) => const SizedBox(
    height: 140, child: Center(child: CircularProgressIndicator(color: AppColors.accent)));
}

class _SectionHeader extends StatelessWidget {
  final String title, action;
  final VoidCallback onTap;
  const _SectionHeader(this.title, this.action, {required this.onTap});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        GestureDetector(onTap: onTap, child: Text('$action →', style: const TextStyle(fontSize: 12, color: AppColors.accent))),
      ],
    ),
  );
}
