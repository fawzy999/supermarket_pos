import 'package:flutter/material.dart';
import '../models/connected_device.dart';
import '../repository/device_repository.dart';
import 'device_form_screen.dart';

/// شاشة إدارة الأجهزة المتصلة بالمحل: الطابعات، شاشات عرض العميل،
/// السكانرات. إضافة/تعديل/حذف، تحديد الجهاز الافتراضي لكل نوع، وفحص
/// حالة الاتصال (فحص فعلي لأجهزة الواي فاي، وتحديث يدوي لغيرها).
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _repository = DeviceRepository();
  List<ConnectedDevice> _devices = [];
  bool _loading = true;
  int? _checkingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final devices = await _repository.getAllDevices();
    setState(() {
      _devices = devices;
      _loading = false;
    });
  }

  Future<void> _addDevice() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const DeviceFormScreen()));
    if (saved == true) _load();
  }

  Future<void> _editDevice(ConnectedDevice device) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DeviceFormScreen(device: device)),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteDevice(ConnectedDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الجهاز'),
        content: Text('هل تريد حذف "${device.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteDevice(device.id!);
    _load();
  }

  Future<void> _checkConnection(ConnectedDevice device) async {
    setState(() => _checkingId = device.id);
    await _repository.checkConnection(device);
    if (mounted) {
      setState(() => _checkingId = null);
      if (device.connectionType != 'wifi') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الفحص التلقائي متاح لأجهزة الواي فاي بس - حدّث الحالة يدويًا')),
        );
      }
    }
    _load();
  }

  Future<void> _setManualStatus(ConnectedDevice device) async {
    final status = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('تحديث الحالة يدويًا'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'connected'), child: const Text('متصل')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'disconnected'), child: const Text('غير متصل')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'error'), child: const Text('فيه عطل')),
        ],
      ),
    );
    if (status == null) return;
    await _repository.setStatusManually(device.id!, status);
    _load();
  }

  String _typeLabel(String type) => switch (type) {
        'printer' => 'طابعة فواتير',
        'customer_display' => 'شاشة عرض عميل',
        'scanner' => 'قارئ باركود',
        _ => 'جهاز آخر',
      };

  String _connectionLabel(String type) => switch (type) {
        'bluetooth' => 'بلوتوث',
        'wifi' => 'واي فاي',
        _ => 'USB',
      };

  String _statusLabel(String status) => switch (status) {
        'connected' => 'متصل',
        'disconnected' => 'غير متصل',
        'error' => 'فيه عطل',
        _ => 'غير معروف',
      };

  Color _statusColor(String status) => switch (status) {
        'connected' => Colors.green,
        'disconnected' => Colors.red,
        'error' => Colors.deepOrange,
        _ => Colors.grey,
      };

  IconData _typeIcon(String type) => switch (type) {
        'printer' => Icons.print_outlined,
        'customer_display' => Icons.tv_outlined,
        'scanner' => Icons.qr_code_scanner_outlined,
        _ => Icons.devices_other_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأجهزة المتصلة')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDevice,
        icon: const Icon(Icons.add),
        label: const Text('جهاز جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? const Center(child: Text('لا توجد أجهزة مسجلة - اضغط "جهاز جديد" لإضافة طابعة أو شاشة عرض'))
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_typeIcon(device.type)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(device.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                          if (device.isDefault)
                                            const Chip(label: Text('افتراضي'), visualDensity: VisualDensity.compact),
                                        ],
                                      ),
                                      Text(
                                        '${_typeLabel(device.type)}  •  ${_connectionLabel(device.connectionType)}'
                                        '${(device.address ?? '').isNotEmpty ? '  •  ${device.address}' : ''}',
                                      ),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: Text(_statusLabel(device.status)),
                                  backgroundColor: _statusColor(device.status).withOpacity(0.15),
                                  labelStyle: TextStyle(color: _statusColor(device.status)),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _checkingId == device.id ? null : () => _checkConnection(device),
                                  icon: _checkingId == device.id
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.wifi_tethering, size: 16),
                                  label: const Text('فحص الاتصال'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _setManualStatus(device),
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  label: const Text('تحديث الحالة'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _editDevice(device),
                                  icon: const Icon(Icons.settings_outlined, size: 16),
                                  label: const Text('تعديل'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _deleteDevice(device),
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  label: const Text('حذف'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
