import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../repository/supplier_repository.dart';
import '../repository/inventory_repository.dart';
import '../../../core/utils/document_picker.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/document_preview.dart';

/// عنصر واحد في عقد التوريد - صنف مسجّل بالكتالوج (بفئته المأخوذة
/// وقت الإضافة) أو صنف يدوي غير مسجّل، بكميته وسعره وقت توقيع العقد.
class _ContractItem {
  final int? productId;
  final String name;
  final String? categoryName;
  final String? unit;
  double quantity;
  double unitPrice;

  _ContractItem({
    this.productId,
    required this.name,
    this.categoryName,
    this.unit,
    this.quantity = 1,
    this.unitPrice = 0,
  });

  double get lineTotal => quantity * unitPrice;
}

/// شاشة "عقد توريد جديد" احترافية: أصناف البضاعة وفئاتها وكمياتها
/// وأسعارها (مربوطة بالكتالوج أو يدوية)، مدة التوريد، ومرفقات عرض
/// السعر والعقد نفسه (صورة أو PDF) - كل ده بيتحفظ مع المورد.
class SupplierContractFormScreen extends StatefulWidget {
  final Supplier supplier;

  const SupplierContractFormScreen({super.key, required this.supplier});

  @override
  State<SupplierContractFormScreen> createState() => _SupplierContractFormScreenState();
}

class _SupplierContractFormScreenState extends State<SupplierContractFormScreen> {
  final _repository = SupplierRepository();
  final _inventoryRepository = InventoryRepository();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String? _quoteFilePath;
  String? _contractFilePath;

  final List<_ContractItem> _items = [];
  Map<int, String> _categoryNames = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await _inventoryRepository.getCategories();
    setState(() {
      _categoryNames = {for (final c in categories) if (c.id != null) c.id!: c.name};
      _loading = false;
    });
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _addItemFromCatalog() async {
    final searchController = TextEditingController();
    List<Product> results = [];

    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'ابحث عن صنف', prefixIcon: Icon(Icons.search)),
                    onChanged: (q) async {
                      final r = await _inventoryRepository.getAllProducts(searchQuery: q);
                      dialogSetState(() => results = r);
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final p = results[index];
                      final categoryName = p.categoryId != null ? _categoryNames[p.categoryId] : null;
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                          '${categoryName ?? 'غير مصنّف'}  •  سعر الشراء المعتاد: ${p.purchasePrice.toStringAsFixed(2)} ج',
                        ),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null) return;

    setState(() {
      _items.add(_ContractItem(
        productId: selected.id,
        name: selected.name,
        categoryName: selected.categoryId != null ? _categoryNames[selected.categoryId] : null,
        unit: selected.unit,
        quantity: 1,
        unitPrice: selected.purchasePrice,
      ));
    });
  }

  Future<void> _addManualItem() async {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final unitController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('صنف بضاعة غير مسجّل بالكتالوج'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'اسم الصنف'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'فئة/نوعية البضاعة (اختياري)'),
                ),
                TextFormField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: 'الوحدة (كيلو، كيس، قطعة...)'),
                ),
                TextFormField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'الكمية'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'قيمة غير صحيحة' : null,
                ),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'سعر الوحدة وقت التوريد'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'قيمة غير صحيحة' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _items.add(_ContractItem(
        name: nameController.text.trim(),
        categoryName: categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
        unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
        quantity: double.parse(qtyController.text),
        unitPrice: double.tryParse(priceController.text) ?? 0,
      ));
    });
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  Future<void> _editItem(int index) async {
    final item = _items[index];
    final qtyController = TextEditingController(text: formatQuantity(item.quantity));
    final priceController = TextEditingController(text: item.unitPrice.toStringAsFixed(2));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'الكمية'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'السعر'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تحديث')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      item.quantity = double.tryParse(qtyController.text) ?? item.quantity;
      item.unitPrice = double.tryParse(priceController.text) ?? item.unitPrice;
    });
  }

  double get _total => _items.fold(0, (sum, item) => sum + item.lineTotal);

  Future<void> _pickQuote() async {
    final picked = await DocumentPicker.pick(context, pdfLabel: 'اختيار ملف PDF لعرض السعر');
    if (picked != null) setState(() => _quoteFilePath = picked);
  }

  Future<void> _pickContractFile() async {
    final picked = await DocumentPicker.pick(context, pdfLabel: 'اختيار ملف PDF للعقد');
    if (picked != null) setState(() => _contractFilePath = picked);
  }

  Widget _attachmentTile({
    required String label,
    required String? path,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Card(
      child: ListTile(
        leading: path != null
            ? SizedBox(width: 44, height: 44, child: DocumentPreview(path: path))
            : const Icon(Icons.attach_file_outlined),
        title: Text(label),
        subtitle: Text(path != null ? (isPdfPath(path) ? 'مرفوع (PDF)' : 'مرفوعة') : 'غير مرفوع'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(icon: const Icon(Icons.upload_file_outlined), tooltip: 'رفع/تغيير', onPressed: onPick),
            if (path != null) IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'حذف', onPressed: onClear),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ضيف صنف بضاعة واحد على الأقل')),
      );
      return;
    }

    setState(() => _saving = true);

    await _repository.createContract(
      supplierId: widget.supplier.id!,
      title: _titleController.text.trim(),
      totalAmount: _total,
      startDate: _startDate.toIso8601String(),
      endDate: _endDate?.toIso8601String(),
      durationLabel: _durationController.text.trim().isEmpty ? null : _durationController.text.trim(),
      quoteFilePath: _quoteFilePath,
      contractFilePath: _contractFilePath,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      items: _items
          .map((i) => {
                'product_id': i.productId,
                'item_name': i.name,
                'category_name': i.categoryName,
                'unit': i.unit,
                'quantity': i.quantity,
                'unit_price': i.unitPrice,
              })
          .toList(),
    );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text('عقد توريد جديد - ${widget.supplier.companyName}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'عنوان/وصف العقد'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            const Text('مدة التوريد', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تاريخ بداية العقد'),
              subtitle: Text(_formatDate(_startDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تاريخ نهاية العقد (اختياري)'),
              subtitle: Text(_endDate != null ? _formatDate(_endDate!) : 'غير محدد'),
              trailing: const Icon(Icons.event_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _endDate = picked);
              },
            ),
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'مدة التوريد بالوصف (مثال: توريد أسبوعي لمدة 6 أشهر)',
              ),
            ),
            const Divider(height: 32),
            Row(
              children: [
                const Expanded(child: Text('أصناف البضاعة', style: TextStyle(fontWeight: FontWeight.bold))),
                TextButton.icon(
                  onPressed: _addItemFromCatalog,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('من الكتالوج'),
                ),
                TextButton.icon(
                  onPressed: _addManualItem,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('صنف يدوي'),
                ),
              ],
            ),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('لسه مفيش أصناف مضافة'),
              )
            else
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: GestureDetector(
                    onTap: () => _editItem(index),
                    child: Text(
                      '${item.categoryName ?? 'غير مصنّف'}  •  '
                      '${formatQuantity(item.quantity)} ${item.unit ?? ''} × ${item.unitPrice.toStringAsFixed(2)} ج  (تعديل)',
                      style: const TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${item.lineTotal.toStringAsFixed(2)} ج'),
                      IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _removeItem(index)),
                    ],
                  ),
                );
              }),
            const Divider(height: 32),
            const Text('المرفقات', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _attachmentTile(
              label: 'عرض السعر من المورد',
              path: _quoteFilePath,
              onPick: _pickQuote,
              onClear: () => setState(() => _quoteFilePath = null),
            ),
            _attachmentTile(
              label: 'صورة/ملف العقد الموقّع',
              path: _contractFilePath,
              onPick: _pickContractFile,
              onClear: () => setState(() => _contractFilePath = null),
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'الإجمالي: ${_total.toStringAsFixed(2)} ج',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      // زرار الحفظ ثابت فوق حافة الشاشة السفلية - نفس تعديل زراير
      // الحفظ التانية في التطبيق عشان يفضل ظاهر ومتاح للضغط دايمًا
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جاري الحفظ...' : 'حفظ العقد'),
        ),
      ),
    );
  }
}
