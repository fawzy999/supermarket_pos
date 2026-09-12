import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../repository/supplier_repository.dart';
import '../repository/supply_batch_repository.dart';
import '../../../core/auth/session/current_session.dart';
import '../../../core/utils/document_picker.dart';
import '../../../core/widgets/document_preview.dart';

class SupplyBatchFormScreen extends StatefulWidget {
  final Product product;

  const SupplyBatchFormScreen({super.key, required this.product});

  @override
  State<SupplyBatchFormScreen> createState() => _SupplyBatchFormScreenState();
}

class _SupplyBatchFormScreenState extends State<SupplyBatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierRepository = SupplierRepository();
  final _batchRepository = SupplyBatchRepository();

  late final TextEditingController _quantityController;
  late final TextEditingController _receivedByController;
  final _notesController = TextEditingController();

  List<Supplier> _suppliers = [];
  int? _selectedSupplierId;
  DateTime _supplyDate = DateTime.now();
  DateTime? _expiryDate;
  String? _invoiceImagePath;
  String? _receiptImagePath;
  bool _loading = true;
  bool _saving = false;

  Widget _imagePickerTile({
    required String label,
    required String? path,
    required ValueChanged<String?> onPicked,
  }) {
    return Card(
      child: ListTile(
        leading: DocumentLeadingThumbnail(path: path),
        title: Text(label),
        subtitle: Text(path == null
            ? 'اختياري - مش مرفوعة'
            : (isPdfPath(path) ? 'مرفوعة (PDF)' : 'مرفوعة')),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'رفع/تغيير (صورة أو PDF)',
              onPressed: () async {
                final picked = await DocumentPicker.pick(context);
                if (picked != null) onPicked(picked);
              },
            ),
            if (path != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'حذف',
                onPressed: () => onPicked(null),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _receivedByController = TextEditingController(text: CurrentSession.instance.user?.name ?? '');
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await _supplierRepository.getAllSuppliers();
    setState(() {
      _suppliers = suppliers;
      _loading = false;
    });
  }

  Future<void> _addSupplierQuick() async {
    final companyController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مورد سريع'),
        content: TextField(
          controller: companyController,
          decoration: const InputDecoration(labelText: 'اسم الشركة/المحل'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
        ],
      ),
    );

    if (confirmed != true || companyController.text.trim().isEmpty) return;
    final newId = await _supplierRepository.addSupplier(Supplier(companyName: companyController.text.trim()));
    await _loadSuppliers();
    setState(() => _selectedSupplierId = newId);
  }

  Future<void> _pickSupplyDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _supplyDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _supplyDate = picked);
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await _batchRepository.recordSupplyBatch(
      productId: widget.product.id!,
      supplierId: _selectedSupplierId,
      quantity: double.parse(_quantityController.text),
      supplyDate: _supplyDate.toIso8601String(),
      expiryDate: _expiryDate?.toIso8601String(),
      receivedBy: _receivedByController.text.trim().isEmpty ? null : _receivedByController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      invoiceImagePath: _invoiceImagePath,
      receiptImagePath: _receiptImagePath,
    );

    if (mounted) Navigator.pop(context, true);
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text('توريد جديد - ${widget.product.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedSupplierId,
                    decoration: const InputDecoration(labelText: 'المورد (اختياري)'),
                    items: _suppliers
                        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.companyName)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedSupplierId = value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'إضافة مورد جديد',
                  onPressed: _addSupplierQuick,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(labelText: 'الكمية المستلمة (${widget.product.unit ?? ''})'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'الكمية مطلوبة';
                if (double.tryParse(v) == null) return 'قيمة غير صحيحة';
                return null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تاريخ التوريد'),
              subtitle: Text(_formatDate(_supplyDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickSupplyDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تاريخ الصلاحية (اختياري)'),
              subtitle: Text(_expiryDate != null ? _formatDate(_expiryDate!) : 'غير محدد'),
              trailing: const Icon(Icons.event_busy_outlined),
              onTap: _pickExpiryDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _receivedByController,
              decoration: const InputDecoration(labelText: 'اسم المستلم من المحل'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: 16),
            const Text('مستندات التوريدة (اختياري)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _imagePickerTile(
              label: 'صورة فاتورة المورد',
              path: _invoiceImagePath,
              onPicked: (p) => setState(() => _invoiceImagePath = p),
            ),
            _imagePickerTile(
              label: 'صورة استلام البضاعة',
              path: _receiptImagePath,
              onPicked: (p) => setState(() => _receiptImagePath = p),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'جاري الحفظ...' : 'تسجيل التوريد'),
            ),
          ],
        ),
      ),
    );
  }
}
