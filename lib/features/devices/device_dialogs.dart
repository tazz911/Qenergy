// lib/features/devices/device_dialogs.dart
// Add-device and device-details dialogs, used by Zone Detail and Devices screens.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';

void _snack(BuildContext context, String text, {Color color = AppColors.green}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
}

/// Shows a form to add a meter/sensor. If [zoneId] is null the user picks a zone.
Future<void> showAddDeviceDialog(BuildContext context, {String? zoneId, List<ZoneModel> zones = const []}) {
  final nameCtrl = TextEditingController();
  final serialCtrl = TextEditingController();
  String type = 'meter';
  String? selectedZone = zoneId ?? (zones.isNotEmpty ? zones.first.zoneId : null);
  String? error;
  bool saving = false;

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      Future<void> save() async {
        final name = nameCtrl.text.trim();
        final serial = serialCtrl.text.trim();
        if (name.isEmpty || serial.isEmpty || selectedZone == null) {
          setD(() => error = 'Please fill in name, serial number and zone.');
          return;
        }
        setD(() { saving = true; error = null; });
        try {
          await SupabaseService().addDevice(selectedZone!, name, type, serial);
          if (ctx.mounted) Navigator.pop(ctx);
          if (context.mounted) _snack(context, 'Device "$name" added');
        } on PostgrestException catch (e) {
          setD(() {
            saving = false;
            error = e.code == '23505' ? 'This serial number is already used.' : e.message;
          });
        } catch (_) {
          setD(() { saving = false; error = 'Network error. Try again.'; });
        }
      }

      return AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Add device', style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Device name (e.g. Kitchen meter)')),
            const SizedBox(height: 10),
            TextField(controller: serialCtrl, style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Serial number (e.g. ESP32-001)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: type,
              dropdownColor: AppColors.bg3,
              style: const TextStyle(color: AppColors.textPrimary),
              items: const [
                DropdownMenuItem(value: 'meter', child: Text('Smart meter')),
                DropdownMenuItem(value: 'ESP32', child: Text('ESP32')),
                DropdownMenuItem(value: 'sensor', child: Text('Sensor')),
              ],
              onChanged: (v) => setD(() => type = v ?? 'meter'),
            ),
            if (zoneId == null) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedZone,
                hint: const Text('Choose zone'),
                dropdownColor: AppColors.bg3,
                style: const TextStyle(color: AppColors.textPrimary),
                items: zones.map((z) => DropdownMenuItem(value: z.zoneId, child: Text(z.zoneName))).toList(),
                onChanged: (v) => setD(() => selectedZone = v),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saving...' : 'Add', style: const TextStyle(color: AppColors.accent)),
          ),
        ],
      );
    }),
  );
}

/// Shows serial number + secret API key (needed by the meter) and lets the user
/// switch the device on/off or delete it.
Future<void> showDeviceDetailsDialog(BuildContext context, DeviceModel device, {String? zoneName}) {
  final svc = SupabaseService();

  Widget row(String k, String v, {bool copy = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90, child: Text(k, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      Expanded(child: SelectableText(v, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
      if (copy)
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: v));
            _snack(context, 'Copied');
          },
          child: const Padding(padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.copy, size: 14, color: AppColors.accent)),
        ),
    ]),
  );

  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(device.deviceName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (zoneName != null) row('Zone', zoneName),
        row('Type', device.deviceType),
        row('Serial', device.serialNumber, copy: true),
        row('API key', device.apiKey, copy: true),
        row('Status', device.isActive ? 'Active' : 'Inactive'),
        row('Last seen', device.lastSeenAt == null ? 'Never' : timeAgo(device.lastSeenAt!)),
        const SizedBox(height: 8),
        const Text('The meter needs the serial number and API key to send readings. Keep the key secret.',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ]),
      actions: [
        TextButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: ctx,
              builder: (c) => AlertDialog(
                backgroundColor: AppColors.card,
                title: const Text('Delete device?', style: TextStyle(color: AppColors.textPrimary)),
                content: const Text('All its readings and alerts will also be deleted.',
                    style: TextStyle(color: AppColors.textSecondary)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete', style: TextStyle(color: AppColors.red))),
                ],
              ),
            );
            if (ok != true) return;
            await svc.deleteDevice(device.deviceId);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) _snack(context, 'Device deleted', color: AppColors.red);
          },
          child: const Text('Delete', style: TextStyle(color: AppColors.red)),
        ),
        TextButton(
          onPressed: () async {
            await svc.updateDevice(device.deviceId, status: device.isActive ? 'inactive' : 'active');
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(device.isActive ? 'Deactivate' : 'Activate'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.accent))),
      ],
    ),
  );
}
