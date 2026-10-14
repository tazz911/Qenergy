// lib/features/devices/devices_screen.dart
// All meters/sensors of the user across every zone, with search.
import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import 'device_dialogs.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});
  @override State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _svc = SupabaseService();
  final _searchCtrl = TextEditingController();
  List<DeviceModel> _devices = [];
  List<ZoneModel> _zones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_svc.getAllDevices(), _svc.getZones()]);
      if (!mounted) return;
      setState(() {
        _devices = results[0] as List<DeviceModel>;
        _zones = results[1] as List<ZoneModel>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    if (_zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add a zone first (Settings → Manage Zones).'), backgroundColor: AppColors.orange));
      return;
    }
    await showAddDeviceDialog(context, zones: _zones);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final zoneNames = {for (final z in _zones) z.zoneId: z.zoneName};
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = _devices.where((d) => q.isEmpty
        || d.deviceName.toLowerCase().contains(q)
        || d.serialNumber.toLowerCase().contains(q)
        || (zoneNames[d.zoneId] ?? '').toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
        title: const Text('Devices & Meters'),
        actions: [IconButton(icon: const Icon(Icons.add, color: AppColors.accent), onPressed: _add)],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Search by name, serial or zone',
                  prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textTertiary)),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: list.isEmpty
                        ? ListView(children: [
                            Padding(
                              padding: const EdgeInsets.all(40),
                              child: Text(_devices.isEmpty ? 'No devices yet. Tap + to add your first meter.' : 'No devices match "$q".',
                                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ),
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: list.length,
                            itemBuilder: (ctx, i) {
                              final d = list[i];
                              final online = isOnline(d);
                              return GestureDetector(
                                onTap: () async {
                                  await showDeviceDetailsDialog(context, d, zoneName: zoneNames[d.zoneId]);
                                  _load();
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                                  child: Row(children: [
                                    Icon(Icons.electric_meter_outlined, size: 20, color: online ? AppColors.green : AppColors.textTertiary),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(d.deviceName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                      Text('${zoneNames[d.zoneId] ?? 'Zone'} · ${d.serialNumber} · ${d.deviceType}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ])),
                                    Text(!d.isActive ? 'Inactive' : online ? 'Online' : 'Offline',
                                        style: TextStyle(fontSize: 11, color: online ? AppColors.green : AppColors.textTertiary)),
                                  ]),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ]),
      ),
    );
  }
}
