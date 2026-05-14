// lib/features/zones/manage_zones_screen.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ManageZonesScreen extends StatefulWidget {
  const ManageZonesScreen({super.key});
  @override State<ManageZonesScreen> createState() => _ManageZonesScreenState();
}

class _ManageZonesScreenState extends State<ManageZonesScreen> {
  final _nameCtrl = TextEditingController();
  final _locCtrl = TextEditingController();

  final List<Map<String, dynamic>> _zones = [
    {'name': 'Office', 'location': 'Floor 1', 'active': true},
    {'name': 'Kitchen', 'location': 'Ground Floor', 'active': true},
    {'name': 'Server Room', 'location': 'Basement', 'active': true},
    {'name': 'Lobby', 'location': 'Ground Floor', 'active': true},
  ];

  void _addZone() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _zones.add({'name': name, 'location': _locCtrl.text.trim(), 'active': true});
      _nameCtrl.clear();
      _locCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Zone "$name" added successfully'),
      backgroundColor: AppColors.green,
    ));
  }

  @override
  void dispose() { _nameCtrl.dispose(); _locCtrl.dispose(); super.dispose(); }

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
              margin: const EdgeInsets.all(20),
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
                  ElevatedButton(onPressed: _addZone, child: const Text('Add Zone')),
                ],
              ),
            ),
            // Zones list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _zones.length,
                itemBuilder: (ctx, i) {
                  final z = _zones[i];
                  final active = z['active'] as bool;
                  return Container(
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
                          decoration: BoxDecoration(shape: BoxShape.circle, color: active ? AppColors.green : AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(z['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            if ((z['location'] as String).isNotEmpty)
                              Text(z['location'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ]),
                        ),
                        // Toggle
                        GestureDetector(
                          onTap: () => setState(() => _zones[i]['active'] = !active),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                            child: Icon(active ? Icons.visibility : Icons.visibility_off, size: 14, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Delete
                        GestureDetector(
                          onTap: () => setState(() => _zones.removeAt(i)),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                            child: const Icon(Icons.delete_outline, size: 14, color: AppColors.red),
                          ),
                        ),
                      ],
                    ),
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
