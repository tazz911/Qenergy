// lib/features/home/main_shell.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/format.dart';
import '../../core/theme/app_theme.dart';
import 'home_screen.dart';
import '../analytics/analytics_screen.dart';
import '../alerts/alerts_screen.dart';
import '../settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  late final Stream<List<AlertModel>> _alerts$ = SupabaseService().alertsStream().asBroadcastStream();
  StreamSubscription<List<AlertModel>>? _notifySub;
  late final List<Widget> _pages = [
    HomeScreen(onSeeAllAlerts: () => setState(() => _index = 2)),
    const AnalyticsScreen(),
    const AlertsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final notifier = NotificationService.instance..reset();
    notifier.init().then((_) {
      if (context.read<AuthProvider>().user?.pushNotifications ?? true) notifier.requestPermission();
    });
    // M7F2: pop up a notification + in-app message for every new alert.
    _notifySub = _alerts$.listen((alerts) {
      final fresh = notifier.handle(alerts, context.read<AuthProvider>().user);
      if (fresh.isEmpty || !mounted) return;
      final a = fresh.first;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: severityColor(a.severity).withOpacity(0.95),
          duration: const Duration(seconds: 6),
          content: Text(fresh.length == 1 ? '${alertTitle(a.alertType)}: ${a.message}' : '${fresh.length} new alerts - ${a.message}',
              style: const TextStyle(color: Colors.white)),
          action: SnackBarAction(label: 'VIEW', textColor: Colors.white, onPressed: () => setState(() => _index = 2)),
        ));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    super.dispose();
  }

  Widget _alertIcon(IconData icon, int open) =>
      open == 0 ? Icon(icon) : Badge(label: Text('$open'), child: Icon(icon));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg2,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: StreamBuilder<List<AlertModel>>(
          stream: _alerts$,
          builder: (context, snap) {
            final open = (snap.data ?? []).where((a) => !a.isAcknowledged).length;
            return NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 72,
              destinations: [
                const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Analytics'),
                NavigationDestination(
                  icon: _alertIcon(Icons.notifications_outlined, open),
                  selectedIcon: _alertIcon(Icons.notifications, open),
                  label: 'Alerts',
                ),
                const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
              ],
            );
          },
        ),
      ),
    );
  }
}
