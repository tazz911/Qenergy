// lib/features/zones/zone_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';

class ZoneDetailScreen extends StatelessWidget {
  final String zoneName;
  const ZoneDetailScreen({super.key, required this.zoneName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text(zoneName),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: const Row(
              children: [
                Icon(Icons.circle, color: AppColors.green, size: 6),
                SizedBox(width: 4),
                Text('Normal', style: TextStyle(color: AppColors.green, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Live readings grid
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20), mainAxisSpacing: 12, crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: const [
                  _ReadingCard(label: 'Voltage', value: '229.4', unit: 'Volts (V)', trend: '↓ 0.8V stable', trendUp: false),
                  _ReadingCard(label: 'Current', value: '14.2', unit: 'Amperes (A)', trend: '↑ 1.2A rising', trendUp: true),
                  _ReadingCard(label: 'Power', value: '3.3', unit: 'Kilowatts (kW)', trend: '↔ Stable', trendUp: false),
                  _ReadingCard(label: 'Energy', value: '32.4', unit: 'kWh today', trend: '↓ 5% vs yesterday', trendUp: false),
                ],
              ),
              // History chart
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Historical trend (7 days)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: BarChart(BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                            getTitlesWidget: (v, _) {
                              const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
                              if (v.toInt() < days.length) return Text(days[v.toInt()], style: const TextStyle(color: AppColors.textSecondary, fontSize: 9));
                              return const Text('');
                            })),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                            getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)))),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [28.0, 31.0, 27.0, 35.0, 30.0, 22.0, 32.0].asMap().entries.map((e) =>
                          BarChartGroupData(x: e.key, barRods: [
                            BarChartRodData(toY: e.value, width: 20, borderRadius: BorderRadius.circular(4),
                              color: AppColors.accent.withOpacity(0.7), backDrawRodData: BackgroundBarChartRodData(show: true, toY: 40, color: AppColors.bg3)),
                          ]),
                        ).toList(),
                      )),
                    ),
                  ],
                ),
              ),
              // AI Analysis badge
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.psychology, color: AppColors.accentBlue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('AI Analysis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentBlue)),
                        SizedBox(height: 2),
                        Text('Consumption pattern is within normal range. No anomalies detected in the last 24 hours.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  final String label, value, unit, trend;
  final bool trendUp;
  const _ReadingCard({required this.label, required this.value, required this.unit, required this.trend, required this.trendUp});

  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text(unit, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text(trend, style: TextStyle(fontSize: 10, color: trendUp ? AppColors.red : AppColors.green)),
    ]),
  );
}
