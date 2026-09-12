import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../repository/supplier_repository.dart';
import '../repository/inventory_repository.dart';
import '../repository/purchase_order_repository.dart';
import '../../../core/auth/session/current_session.dart';
import '../../../core/utils/format_utils.dart';
import 'purchase_order_view_screen.dart';

/// عنصر واحد في طلب التوريد - صنف مسجّل بالكتالوج (productId != null)
/// أو صنف جديد غير مسجّل عندك أصلًا (بيتكتب اسمه يدويًا).
class _PoItem {
  final int? productId;
  final String name;
  final String? unit;
  double quantity;
  double unitPrice;

  _PoItem({this.productId, required this.name, this.unit, this.quantity = 1, this.unitPrice = 0});

  double get lineTotal => quantity * unitPrice;
}

/// شاشة "طلب توريد جديد" احترافية: اختيار مورد مسجّل أو إدخال بيانات
/// مورد جديد يدويًا، إضافة أصناف من الكتالوج أو أصناف جديدة (مع خيار
/// حفظها بالكتالوج)، ثم توليد الطلب كـ PDF جاهز للإرسال.
class PurchaseOrderFormScreen extends StatefulWidget {
  final Supplier? supplier;

  const PurchaseOrderFormScreen({super.key, this.supplier});

  @override
  State<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends State<PurchaseOrderFormScreen> {
  final _supplierRepository = SupplierRepository();
  final _inventoryRepository = InventoryRepository();
  final _poRepository = PurchaseOrderRepository();
  final _notesController = TextEditingController();

  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  bool _manualSupplier = false;
  final _manualNameController = TextEditingController();
  final _manualPhoneController = TextEditingController();
  final _manualEmailController = TextEditingController();
  final _manualAddressController = TextEditingController();

  final List<_PoItem> _items = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedSupplier = widget.supplier;
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await _supplierRepository.getAllSuppliers();
    setState(() {
      _suppliers = suppliers;
      // لازم نستخدم نفس الكائن (instance) الموجود في القايمة عشان
      // DropdownButtonFormField يقدر يلاقي القيمة المختارة فيها
      if (_selectedSupplier != null) {
        final match = suppliers.where((s) => s.id == _selectedSupplier!.id);
        _selectedSupplier = match.isNotEmpty ? match.first : null;
      }
      _loading = false;
    });
  }

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
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text('سعر الشراء المعتاد: ${p.purchasePrice.toStringAsFixed(2)} ج'),
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
      _items.add(_PoItem(
        productId: selected.id,
        name: selected.name,
        unit: selected.unit,
        quantity: 1,
        unitPrice: selected.purchasePrice,
      ));
    });
  }

  Future<void> _addNewItem() async {
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    bool saveToCatalog = false;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text('صنف جديد غير مسجّل بالكتالوج'),
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
                    controller: unitController,
                    decoration: const InputDecoration(labelText: 'الوحدة (كيلو، كيس، قطعة...)'),
                  ),
                  TextFormField(
                    controller: qtyController,
                    decoration: const InputDecoration(labelText: 'الكمية المطلوبة'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'قيمة غير صحيحة' : null,
                  ),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'السعر المتوقع'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'قيمة غير صحيحة' : null,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('احفظه في كتالوج المنتجات للاستخدام لاحقًا'),
                    value: saveToCatalog,
                    onChanged: (v) => dialogSetState(() => saveToCatalog = v ?? false),
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
      ),
    );
    if (confirmed != true) return;

    final name = nameController.text.trim();
    final unit = unitController.text.trim().isEmpty ? null : unitController.text.trim();
    final qty = double.parse(qtyController.text);
    final price = double.tryParse(priceController.text) ?? 0;

    int? newProductId;
    if (saveToCatalog) {
      newProductId = await _inventoryRepository.addProduct(Product(
        name: name,
        unit: unit,
        purchasePrice: price,
        salePrice: price,
        quantity: 0,
        reorderLevel: 0,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }

    setState(() {
      _items.add(_PoItem(productId: newProductId, name: name, unit: unit, quantity: qty, unitPrice: price));
    });
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  Future<void> _editItemQuantityOrPrice(int index) async {
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

  Future<void> _save() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ضيف صنف واحد على الأقل')));
      return;
    }

    String supplierName;
    String? supplierPhone, supplierEmail, supplierAddress;
    int? supplierId;

    if (_manualSupplier || _selectedSupplier == null) {
      supplierName = _manualNameController.text.trim();
      if (supplierName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسم المورد مطلوب')));
        return;
      }
      supplierPhone = _manualPhoneController.text.trim().isEmpty ? null : _manualPhoneController.text.trim();
      supplierEmail = _manualEmailController.text.trim().isEmpty ? null : _manualEmailController.text.trim();
      supplierAddress = _manualAddressController.text.trim().isEmpty ? null : _manualAddressController.text.trim();
    } else {
      supplierId = _selectedSupplier!.id;
      supplierName = _selectedSupplier!.companyName;
      supplierPhone = _selectedSupplier!.phone;
      supplierEmail = _selectedSupplier!.email;
      supplierAddress = _selectedSupplier!.address;
    }

    setState(() => _saving = true);
    final orderId = await _poRepository.createOrder(
      supplierId: supplierId,
      supplierName: supplierName,
      supplierPhone: supplierPhone,
      supplierEmail: supplierEmail,
      supplierAddress: supplierAddress,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdBy: CurrentSession.instance.user?.name,
      items: _items
          .map((i) => {
                'product_id': i.productId,
                'item_name': i.name,
                'unit': i.unit,
                'quantity': i.quantity,
                'unit_price': i.unitPrice,
              })
          .toList(),
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PurchaseOrderViewScreen(orderId: orderId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('طلب توريد جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('المورد', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('مورد مسجّل')),
              ButtonSegment(value: true, label: Text('بيانات يدوية')),
            ],
            selected: {_manualSupplier},
            onSelectionChanged: (s) => setState(() => _manualSupplier = s.first),
          ),
          const SizedBox(height: 12),
          if (!_manualSupplier)
            DropdownButtonFormField<Supplier>(
              initialValue: _selectedSupplier,
              decoration: const InputDecoration(labelText: 'اختر المورد'),
              items: _suppliers
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.companyName)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSupplier = v),
            )
          else ...[
            TextField(
              controller: _manualNameController,
              decoration: const InputDecoration(labelText: 'اسم المورد/الشركة'),
            ),
            TextField(
              controller: _manualPhoneController,
              decoration: const InputDecoration(labelText: 'التليفون'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _manualEmailController,
              decoration: const InputDecoration(labelText: 'الإيميل (اختياري)'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _manualAddressController,
              decoration: const InputDecoration(labelText: 'العنوان (اختياري)'),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Text('الأصناف', style: TextStyle(fontWeight: FontWeight.bold))),
              TextButton.icon(
                onPressed: _addItemFromCatalog,
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('من الكتالوج'),
              ),
              TextButton.icon(
                onPressed: _addNewItem,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('صنف جديد'),
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
                  onTap: () => _editItemQuantityOrPrice(index),
                  child: Text(
                    '${formatQuantity(item.quantity)} ${item.unit ?? ''} × ${item.unitPrice.toStringAsFixed(2)} ج  (تعديل)',
                    style: const TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${item.lineTotal.toStringAsFixed(2)} ج'),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeItem(index),
                    ),
                  ],
                ),
              );
            }),
          const Divider(height: 32),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('الإجمالي: ${_total.toStringAsFixed(2)} ج',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'جاري الحفظ...' : 'إنشاء طلب التوريد'),
          ),
        ],
      ),
    );
  }
}
