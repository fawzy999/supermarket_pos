import 'package:flutter/material.dart';
import '../models/connected_device.dart';
import '../repository/device_repository.dart';

/// إضافة/تعديل جهاز متصل: نوعه (طابعة/شاشة عرض عميل/سكانر/غير ذلك)،
/// طريقة الاتصال (بلوتوث/واي فاي/USB)، وعنوانه (MAC أو IP).
class DeviceFormScreen extends StatefulWidget {
  final ConnectedDevice? device;

  const DeviceFormScreen({super.key, this.device});

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = DeviceRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  String _type = 'printer';
  String _connectionType = 'bluetooth';
  bool _isDefault = false;
  bool _saving = false;

  bool get _isEditing => widget.device != null;

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _nameController = TextEditingController(text: d?.name ?? '');
    _addressController = TextEditingController(text: d?.address ?? '');
    _notesController = TextEditingController(text: d?.notes ?? '');
    _type = d?.type ?? 'printer';
    _connectionType = d?.connectionType ?? 'bluetooth';
    _isDefault = d?.isDefault ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final device = ConnectedDevice(
      id: widget.device?.id,
      name: _nameController.text.trim(),
      type: _type,
      connectionType: _connectionType,
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      isDefault: _isDefault,
      status: widget.device?.status ?? 'unknown',
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: widget.device?.createdAt ?? DateTime.now().toIso8601String(),
    );

    if (_isEditing) {
      await _repository.updateDevice(device);
    } else {
      await _repository.addDevice(device);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل جهاز' : 'جهاز جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم الجهاز'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'نوع الجهاز'),
              items: const [
                DropdownMenuItem(value: 'printer', child: Text('طابعة فواتير')),
                DropdownMenuItem(value: 'customer_display', child: Text('شاشة عرض العميل')),
                DropdownMenuItem(value: 'scanner', child: Text('قارئ باركود')),
                DropdownMenuItem(value: 'other', child: Text('جهاز آخر')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'printer'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _connectionType,
              decoration: const InputDecoration(labelText: 'طريقة الاتصال'),
              items: const [
                DropdownMenuItem(value: 'bluetooth', child: Text('بلوتوث')),
                DropdownMenuItem(value: 'wifi', child: Text('واي فاي / شبكة')),
                DropdownMenuItem(value: 'usb', child: Text('USB سلك')),
              ],
              onChanged: (v) => setState(() => _connectionType = v ?? 'bluetooth'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: _connectionType == 'wifi' ? 'عنوان الـ IP' : 'عنوان الـ MAC (اختياري)',
                hintText: _connectionType == 'wifi' ? 'مثال: 192.168.1.50' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('الجهاز الافتراضي لهذا النوع'),
              subtitle: const Text('هيبقى هو المستخدم تلقائيًا عند الطباعة أو العرض'),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
