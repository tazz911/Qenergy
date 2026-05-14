// lib/features/analytics/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _periodIdx = 0;
  final _periods = ['Today', 'This Week', 'This Month', 'Custom'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header()),
            SliverToBoxAdapter(child: _PeriodTabs()),
            SliverToBoxAdapter(child: _StatsGrid()),
            SliverToBoxAdapter(child: _HourlyChart()),
            SliverToBoxAdapter(child: _ZoneBreakdown()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  Widget _Header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 2),
      Row(children: [
        Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.green)),
        const SizedBox(width: 6),
        const Text('Building A overview', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    ]),
  );

  Widget _PeriodTabs() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(
      children: _periods.asMap().entries.map((e) => GestureDetector(
        onTap: () => setState(() => _periodIdx = e.key),
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

  Widget _StatsGrid() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    child: GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6,
      children: const [
        _StatCard(label: 'Total kWh', value: '124.7', valueColor: AppColors.accent, change: '↑ 8.2% vs yesterday', changeUp: true),
        _StatCard(label: 'Peak Power', value: '6.8 kW', valueColor: AppColors.accentBlue, change: '↓ 3.1% improvement', changeUp: false),
        _StatCard(label: 'Avg Voltage', value: '228.9 V', sub: 'Nominal: 230V'),
        _StatCard(label: 'Cost Est.', value: 'OMR 2.8', valueColor: AppColors.accentAmber, change: '↑ based on tariff', changeUp: true),
      ],
    ),
  );

  Widget _HourlyChart() => Container(
    margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hourly consumption (kWh)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
                getTitlesWidget: (v, _) => Text('${(v.toInt() + 6)}h', style: const TextStyle(color: AppColors.textSecondary, fontSize: 8)))),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: const TextStyle(color: AppColors.textSecondary, fontSize: 8)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [3.2, 4.1, 5.8, 6.4, 6.1, 5.9, 6.8, 6.5, 5.2, 5.8, 4.9, 4.1].asMap().entries.map((e) =>
              BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(
                  toY: e.value, width: 16, borderRadius: BorderRadius.circular(3),
                  color: e.value > 6.5 ? AppColors.red.withOpacity(0.7) : e.value > 5.5 ? AppColors.orange.withOpacity(0.7) : AppColors.accentBlue.withOpacity(0.6),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: 8, color: AppColors.bg3),
                ),
              ]),
            ).toList(),
          )),
        ),
      ],
    ),
  );

  Widget _ZoneBreakdown() => Container(
    margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Zone breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 14),
        _BreakdownRow('Server Room', 41.8, 124.7, AppColors.accentBlue),
        _BreakdownRow('Office', 32.4, 124.7, AppColors.accent),
        _BreakdownRow('Kitchen', 28.1, 124.7, AppColors.accentAmber),
        _BreakdownRow('Lobby', 22.4, 124.7, AppColors.red),
      ],
    ),
  );

  Widget _BreakdownRow(String name, double kwh, double total, Color color) {
    final pct = kwh / total;
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
        Text(kwh.toStringAsFixed(1), style: TextStyle(fontSize: 11, color: color, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final String? change, sub;
  final bool changeUp;
  const _StatCard({required this.label, required this.value, this.valueColor, this.change, this.sub, this.changeUp = true});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary)),
      if (sub != null) Text(sub!, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      if (change != null) Text(change!, style: TextStyle(fontSize: 10, color: changeUp ? AppColors.red : AppColors.green)),
    ]),
  );
}
