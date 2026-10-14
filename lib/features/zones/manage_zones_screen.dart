// lib/features/zones/manage_zones_screen.dart
// Add / edit / activate / delete / search zones — all saved in Supabase.
import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class ManageZonesScreen extends StatefulWidget {
  const ManageZonesScreen({super.key});
  @override State<ManageZonesScreen> createState() => _ManageZonesScreenState();
}

class _ManageZonesScreenState extends State<ManageZonesScreen> {
  final _svc = SupabaseService();
  final _nameCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  late final Stream<List<ZoneModel>> _zones$;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _zones$ = _svc.zonesStream(_svc.currentUser!.id);
  }

  @override
  void dispose() { _nameCtrl.dispose(); _locCtrl.dispose(); _searchCtrl.dispose(); super.dispose(); }

  void _snack(String text, {Color color = AppColors.green}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _addZone() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Please enter a zone name', color: AppColors.red);
      return;
    }
    final loc = _locCtrl.text.trim();
    setState(() => _saving = true);
    try {
      await _svc.addZone(_svc.currentUser!.id, name, loc.isEmpty ? null : loc);
      _nameCtrl.clear();
      _locCtrl.clear();
      if (mounted) _snack('Zone "$name" added successfully');
    } catch (_) {
      if (mounted) _snack('Could not save. Check your internet.', color: AppColors.red);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _editZone(ZoneModel z) async {
    final nameCtrl = TextEditingController(text: z.zoneName);
    final locCtrl = TextEditingController(text: z.location ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Edit zone', style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Zone name')),
          const SizedBox(height: 10),
          TextField(controller: locCtrl, style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Location (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true),
              child: const Text('Save', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    await _svc.updateZone(z.zoneId, zoneName: nameCtrl.text.trim(), location: locCtrl.text.trim());
    if (mounted) _snack('Zone updated');
  }

  Future<void> _deleteZone(ZoneModel z) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Delete "${z.zoneName}"?', style: const TextStyle(color: AppColors.textPrimary)),
        content: const Text('Its devices, readings and alerts will also be deleted.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.deleteZone(z.zoneId);
    if (mounted) _snack('Zone deleted', color: AppColors.red);
  }

  Widget _IconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Icon(icon, size: 14, color: color),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
        title: const Text('Manage Zones'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Add zone form
            Container(
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add new zone', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(hintText: 'Zone name (e.g. Meeting Room)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _locCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(hintText: 'Location (optional)'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _saving ? null : _addZone, child: Text(_saving ? 'Saving...' : 'Add Zone')),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Search zones', prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textTertiary)),
              ),
            ),
            // Zones list (live from database)
            Expanded(
              child: StreamBuilder<List<ZoneModel>>(
                stream: _zones$,
                builder: (ctx, snap) {
                  if (snap.hasError) {
                    return const Center(child: Text('Could not load zones.', style: TextStyle(color: AppColors.red)));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                  }
                  final q = _searchCtrl.text.trim().toLowerCase();
                  final zones = snap.data!.where((z) =>
                      q.isEmpty || z.zoneName.toLowerCase().contains(q) || (z.location ?? '').toLowerCase().contains(q)).toList();
                  if (zones.isEmpty) {
                    return Center(child: Text(q.isEmpty ? 'No zones yet. Add your first zone above.' : 'No zones match "$q".',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: zones.length,
                    itemBuilder: (ctx, i) {
                      final z = zones[i];
                      return GestureDetector(
                        onTap: () => _editZone(z),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: z.isActive ? AppColors.green : AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(z.zoneName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  if ((z.location ?? '').isNotEmpty)
                                    Text(z.location!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ]),
                              ),
                              // Active / inactive
                              _IconBtn(z.isActive ? Icons.visibility : Icons.visibility_off, AppColors.textSecondary,
                                  () => _svc.updateZone(z.zoneId, status: z.isActive ? 'inactive' : 'active')),
                              const SizedBox(width: 8),
                              _IconBtn(Icons.delete_outline, AppColors.red, () => _deleteZone(z)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
