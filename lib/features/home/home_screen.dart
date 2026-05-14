// lib/features/home/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart' as app;
import '../zones/zone_detail_screen.dart';
import '../zones/manage_zones_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Simulated live data (replace with real Firestore streams)
  double _voltage = 229.4, _current = 18.3, _power = 4.2, _totalKwh = 124.7;
  Timer? _timer;

  final _zones = [
    {'name': 'Office', 'kwh': 32.4, 'status': 'Normal', 'statusType': 'normal', 'icon': Icons.business},
    {'name': 'Kitchen', 'kwh': 28.1, 'status': 'High Load', 'statusType': 'warn', 'icon': Icons.kitchen},
    {'name': 'Server Room', 'kwh': 41.8, 'status': 'Normal', 'statusType': 'normal', 'icon': Icons.storage},
    {'name': 'Lobby', 'kwh': 22.4, 'status': 'Anomaly', 'statusType': 'alert', 'icon': Icons.door_front_door},
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
        _voltage = 228 + (2 * (DateTime.now().millisecond / 1000));
        _current = 17 + (3 * (DateTime.now().millisecond / 1000));
        _power = 4.0 + (0.5 * (DateTime.now().millisecond / 1000));
        _totalKwh += 0.01;
      });
      }
    });
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header()),
            SliverToBoxAdapter(child: _TotalCard()),
            SliverToBoxAdapter(child: _SectionHeader('Zones', 'Manage', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageZonesScreen())))),
            SliverToBoxAdapter(child: _ZonesList()),
            SliverToBoxAdapter(child: _ChartCard()),
            SliverToBoxAdapter(child: _SectionHeader('Recent Alerts', 'See all', onTap: () {})),
            SliverToBoxAdapter(child: _AlertsPreview()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
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

  Widget _Header() {
    final user = context.watch<app.AuthProvider>().user;
    final fullName = user?.fullName ?? '';
    final firstName = fullName.split(' ').where((p) => p.isNotEmpty).firstOrNull ?? 'there';
    final initials = fullName.isNotEmpty ? _initials(fullName) : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good Morning, $firstName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Building A — ${_zones.length} zones active', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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

  Widget _TotalCard() => Container(
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
          Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.green)),
          const SizedBox(width: 6),
          const Text('Total consumption today', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        RichText(text: TextSpan(children: [
          TextSpan(text: _totalKwh.toStringAsFixed(1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: AppColors.accent, fontFamily: 'JetBrainsMono')),
          const TextSpan(text: ' kWh', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'SpaceGrotesk')),
        ])),
        const SizedBox(height: 16),
        Row(children: [
          _MiniStat('Voltage', '${_voltage.toStringAsFixed(1)} V', AppColors.accentBlue),
          const SizedBox(width: 12),
          _MiniStat('Current', '${_current.toStringAsFixed(1)} A', AppColors.accentAmber),
          const SizedBox(width: 12),
          _MiniStat('Power', '${_power.toStringAsFixed(1)} kW', AppColors.accent),
        ]),
      ],
    ),
  );

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

  Widget _ZonesList() => SizedBox(
    height: 140,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _zones.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (ctx, i) {
        final z = _zones[i];
        final sType = z['statusType'] as String;
        final color = sType == 'normal' ? AppColors.green : sType == 'warn' ? AppColors.orange : AppColors.red;
        final bgColor = color.withOpacity(0.12);
        return GestureDetector(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => ZoneDetailScreen(zoneName: z['name'] as String))),
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
                child: Icon(z['icon'] as IconData, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(z['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text('${z['kwh']} kWh', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
                child: Text(z['status'] as String, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
        );
      },
    ),
  );

  Widget _ChartCard() => Container(
    margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Energy consumption (24h)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: LineChart(LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 4,
                getTitlesWidget: (v, _) => Text('${v.toInt()}h', style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)))),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: [const FlSpot(0,2.1),const FlSpot(2,1.8),const FlSpot(4,1.4),const FlSpot(6,1.2),const FlSpot(8,3.2),const FlSpot(10,5.8),const FlSpot(12,6.4),const FlSpot(14,5.9),const FlSpot(16,6.8),const FlSpot(18,5.2),const FlSpot(20,4.1),const FlSpot(22,3.8)],
                isCurved: true, color: AppColors.accent, barWidth: 2, dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: AppColors.accent.withOpacity(0.08)),
              ),
            ],
          )),
        ),
      ],
    ),
  );

  Widget _AlertsPreview() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        _AlertRow(Icons.warning_amber_rounded, AppColors.red, 'Voltage Anomaly', 'Lobby — Zone 4 · ESP32-004', 'High', '2 min ago'),
        const SizedBox(height: 10),
        _AlertRow(Icons.bolt, AppColors.orange, 'Overload Warning', 'Kitchen — Zone 2 · ESP32-002', 'Medium', '18 min ago'),
      ],
    ),
  );

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
