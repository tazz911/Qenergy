// lib/features/analytics/analytics_screen.dart
// Usage report: pick a period (or custom dates) and a zone → totals, chart, breakdown.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import 'report_pdf.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _svc = SupabaseService();
  int _periodIdx = 0;
  final _periods = ['Today', 'This Week', 'This Month', 'Custom'];
  DateTimeRange? _custom;
  String? _zoneId; // null = all zones

  List<ZoneModel> _zones = [];
  List<UsageBucket> _buckets = [];
  Map<String, double> _zoneKwh = {};
  bool _loading = true;
  bool _exporting = false;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Keep numbers live while the meter sends readings (same as Home).
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }

  ({DateTime from, DateTime to}) get _range {
    final now = DateTime.now();
    final today = startOfDay(now);
    final tomorrow = today.add(const Duration(days: 1));
    return switch (_periodIdx) {
      0 => (from: today, to: tomorrow),
      1 => (from: today.subtract(const Duration(days: 6)), to: tomorrow),
      2 => (from: DateTime(now.year, now.month, 1), to: tomorrow),
      _ => (from: _custom!.start, to: startOfDay(_custom!.end).add(const Duration(days: 1))),
    };
  }

  bool get _hourly => _range.to.difference(_range.from).inDays <= 1;

  Future<void> _load({bool silent = false}) async {
    if (silent && (_loading || _exporting)) return;
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final r = _range;
      final results = await Future.wait([
        _svc.getZones(),
        _svc.usageBuckets(r.from, r.to, bucket: _hourly ? 'hour' : 'day', zoneId: _zoneId),
        _svc.zoneUsage(r.from, r.to),
      ]);
      if (!mounted) return;
      setState(() {
        _zones = results[0] as List<ZoneModel>;
        _buckets = results[1] as List<UsageBucket>;
        _zoneKwh = results[2] as Map<String, double>;
        _loading = false;
      });
    } catch (_) {
      if (silent) return; // keep showing the last good numbers
      if (mounted) setState(() { _loading = false; _error = 'Could not load data. Pull down to retry.'; });
    }
  }

  Future<void> _selectPeriod(int i) async {
    if (i == 3) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
        initialDateRange: _custom ?? DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      );
      if (picked == null) return;
      _custom = picked;
    }
    _periodIdx = i;
    _load();
  }

  /// M6F1: make a PDF of what is on screen (same period + zone filter).
  Future<void> _exportPdf() async {
    if (_loading || _exporting) return;
    setState(() => _exporting = true);
    try {
      final r = _range;
      final results = await Future.wait([_svc.alertsBetween(r.from, r.to), _svc.getAllDevices()]);
      final devices = results[1] as List<DeviceModel>;
      final zoneName = {for (final z in _zones) z.zoneId: z.zoneName};
      final deviceZone = {for (final d in devices) d.deviceId: zoneName[d.zoneId] ?? '-'};
      var alerts = results[0] as List<AlertModel>;
      if (_zoneId != null) {
        final ids = devices.where((d) => d.zoneId == _zoneId).map((d) => d.deviceId).toSet();
        alerts = alerts.where((a) => ids.contains(a.deviceId)).toList();
      }
      final zoneRows = _zones.where((z) => _zoneId == null || z.zoneId == _zoneId)
          .map((z) => (name: z.zoneName, kwh: _zoneKwh[z.zoneId] ?? 0.0)).toList()
        ..sort((a, b) => b.kwh.compareTo(a.kwh));
      final user = context.read<AuthProvider>().user;
      await shareEnergyReport(EnergyReportData(
        ownerName: (user?.fullName.isNotEmpty ?? false) ? user!.fullName : (user?.email ?? ''),
        from: r.from, to: r.to,
        periodName: _periods[_periodIdx],
        zoneName: _zoneId == null ? 'All zones' : (zoneName[_zoneId] ?? '-'),
        hourly: _hourly,
        buckets: _buckets, zoneRows: zoneRows, alerts: alerts, deviceZone: deviceZone,
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not create the report. Try again.'), backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header()),
              SliverToBoxAdapter(child: _PeriodTabs()),
              SliverToBoxAdapter(child: _ZoneFilter()),
              if (_loading)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent))))
              else if (_error != null)
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
                    child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)))))
              else ...[
                SliverToBoxAdapter(child: _StatsGrid()),
                SliverToBoxAdapter(child: _UsageChart()),
                if (_zoneId == null) SliverToBoxAdapter(child: _ZoneBreakdown()),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _Header() {
    final r = _range;
    final fmt = DateFormat('d MMM');
    final last = r.to.subtract(const Duration(days: 1));
    final label = _hourly ? DateFormat('EEEE, d MMM').format(r.from) : '${fmt.format(r.from)} – ${fmt.format(last)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ]),
        ),
        OutlinedButton.icon(
          onPressed: _loading || _exporting ? null : _exportPdf,
          icon: _exporting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
              : const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: const Text('Report PDF', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent)),
        ),
      ]),
    );
  }

  Widget _PeriodTabs() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(
      children: _periods.asMap().entries.map((e) => GestureDetector(
        onTap: () => _selectPeriod(e.key),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: _periodIdx == e.key ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _periodIdx == e.key ? AppColors.accent : AppColors.border),
          ),
          child: Text(e.value, style: TextStyle(fontSize: 12, color: _periodIdx == e.key ? Colors.black : AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ),
      )).toList(),
    ),
  );

  Widget _ZoneFilter() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: DropdownButtonFormField<String?>(
      value: _zoneId,
      dropdownColor: AppColors.bg3,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_list, size: 18, color: AppColors.textTertiary)),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All zones')),
        ..._zones.map((z) => DropdownMenuItem<String?>(value: z.zoneId, child: Text(z.zoneName))),
      ],
      onChanged: (v) { _zoneId = v; _load(); },
    ),
  );

  Widget _StatsGrid() {
    final total = _buckets.fold(0.0, (s, b) => s + b.kwh);
    final peak = _buckets.fold(0.0, (m, b) => b.maxPower > m ? b.maxPower : m) / 1000;
    final withV = _buckets.where((b) => b.avgVoltage > 0).toList();
    final avgV = withV.isEmpty ? null : withV.fold(0.0, (s, b) => s + b.avgVoltage) / withV.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6,
        children: [
          _StatCard(label: 'Total kWh', value: total.toStringAsFixed(total < 1 ? 3 : 2), valueColor: AppColors.accent, sub: _periods[_periodIdx]),
          _StatCard(label: 'Peak Power', value: '${peak.toStringAsFixed(2)} kW', valueColor: AppColors.accentBlue, sub: 'Highest single reading'),
          _StatCard(label: 'Avg Voltage', value: avgV == null ? '--' : '${avgV.toStringAsFixed(1)} V', sub: 'Nominal: 230V'),
          _StatCard(label: 'Cost Est.', value: 'OMR ${(total * tariffOmrPerKwh).toStringAsFixed(3)}', valueColor: AppColors.accentAmber,
              sub: '${(tariffOmrPerKwh * 1000).toStringAsFixed(0)} baisa / kWh'),
        ],
      ),
    );
  }

  Widget _UsageChart() {
    final r = _range;
    // One bar per hour (0–23) or per day of the period.
    final count = _hourly ? 24 : r.to.difference(r.from).inDays;
    final values = List<double>.filled(count, 0);
    for (final b in _buckets) {
      final i = _hourly ? b.bucket.hour : startOfDay(b.bucket).difference(r.from).inDays;
      if (i >= 0 && i < count) values[i] += b.kwh;
    }
    final maxV = values.fold(0.0, (m, v) => v > m ? v : m);
    final maxY = maxV == 0 ? 1.0 : maxV * 1.2;
    final barWidth = (220 / count).clamp(3.0, 20.0);
    final labelEvery = count <= 8 ? 1 : (count / 6).ceil();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_hourly ? 'Hourly consumption (kWh)' : 'Daily consumption (kWh)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: maxV == 0
                ? const Center(child: Text('No readings in this period', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)))
                : BarChart(BarChartData(
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i % labelEvery != 0) return const SizedBox();
                          final text = _hourly ? '${i}h' : DateFormat(count <= 8 ? 'E' : 'd/M').format(r.from.add(Duration(days: i)));
                          return Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 8));
                        })),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                        getTitlesWidget: (v, _) => Text(v.toStringAsFixed(v < 10 ? 1 : 0), style: const TextStyle(color: AppColors.textSecondary, fontSize: 8)))),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: values.asMap().entries.map((e) =>
                      BarChartGroupData(x: e.key, barRods: [
                        BarChartRodData(
                          toY: e.value, width: barWidth, borderRadius: BorderRadius.circular(3),
                          // Red = top 15% of the busiest bar, orange = top 30%
                          color: e.value > maxV * 0.85 ? AppColors.red.withOpacity(0.7)
                              : e.value > maxV * 0.7 ? AppColors.orange.withOpacity(0.7)
                              : AppColors.accentBlue.withOpacity(0.6),
                          backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: AppColors.bg3),
                        ),
                      ]),
                    ).toList(),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _ZoneBreakdown() {
    const colors = [AppColors.accentBlue, AppColors.accent, AppColors.accentAmber, AppColors.red, AppColors.green];
    final rows = _zones.map((z) => (name: z.zoneName, kwh: _zoneKwh[z.zoneId] ?? 0.0)).toList()
      ..sort((a, b) => b.kwh.compareTo(a.kwh));
    final total = rows.fold(0.0, (s, r) => s + r.kwh);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Zone breakdown (kWh)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const Text('No zones yet.', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ...rows.asMap().entries.map((e) =>
              _BreakdownRow(e.value.name, e.value.kwh, total, colors[e.key % colors.length])),
        ],
      ),
    );
  }

  Widget _BreakdownRow(String name, double kwh, double total, Color color) {
    final pct = total == 0 ? 0.0 : kwh / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 80, child: Text(name, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 8,
              backgroundColor: AppColors.bg3, color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(kwh.toStringAsFixed(2), style: TextStyle(fontSize: 11, color: color, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final String? sub;
  const _StatCard({required this.label, required this.value, this.valueColor, this.sub});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary)),
      if (sub != null) Text(sub!, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    ]),
  );
}
