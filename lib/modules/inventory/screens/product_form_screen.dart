import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../repository/inventory_repository.dart';
import '../../../core/widgets/barcode_scanner_button.dart';
import 'barcode_label_screen.dart';
import 'supply_batch_form_screen.dart';
import 'product_batch_history_screen.dart';
import 'inventory_movements_screen.dart';
import '../repository/supply_batch_repository.dart';

const List<String> _unitOptions = ['كيلو', 'جرام', 'قطعة', 'لتر'];
const List<String> _packagingOptions = ['بدون', 'صندوق', 'كيس', 'صفيحة', 'زجاجة'];
const String _customValue = '__custom__';

/// شاشة موحّدة للإضافة والتعديل
/// لو product == null بتشتغل في وضع "إضافة صنف جديد"
/// لو product متبعت بتشتغل في وضع "تعديل"
/// initialCategoryId: لو جاي من شاشة فئة معينة، بيحدد الفئة تلقائيًا لصنف جديد
class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final int? initialCategoryId;

  const ProductFormScreen({super.key, this.product, this.initialCategoryId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = InventoryRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _reorderLevelController;
  late final TextEditingController _customUnitController;
  late final TextEditingController _customPackagingController;
  late final TextEditingController _unitsPerPackageController;
  late final TextEditingController _innerCountController;
  late final TextEditingController _innerSizeController;

  late String _selectedUnit;
  late String _selectedPackaging;
  int? _selectedCategoryId;
  String? _imagePath;
  List<Category> _categories = [];
  bool _saving = false;
  bool _loadingCategories = true;
  Map<String, dynamic>? _latestBatch;
  Map<String, dynamic>? _nearestExpiryBatch;

  bool get _isEditing => widget.product != null;
  bool get _unitIsCustom => _selectedUnit == _customValue;
  bool get _packagingIsCustom => _selectedPackaging == _customValue;
  bool get _hasPackaging => _effectivePackaging != 'بدون';
  bool get _isPieceUnit => _effectiveUnit == 'قطعة';

  String get _effectiveUnit =>
      _unitIsCustom ? _customUnitController.text.trim() : _selectedUnit;
  String get _effectivePackaging =>
      _packagingIsCustom ? _customPackagingController.text.trim() : _selectedPackaging;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _purchasePriceController = TextEditingController(text: p?.purchasePrice.toString() ?? '');
    _salePriceController = TextEditingController(text: p?.salePrice.toString() ?? '');
    _quantityController = TextEditingController(text: p?.quantity.toString() ?? '0');
    _reorderLevelController = TextEditingController(text: p?.reorderLevel.toString() ?? '0');
    _unitsPerPackageController =
        TextEditingController(text: p?.unitsPerPackage?.toString() ?? '');
    _innerCountController = TextEditingController(text: p?.innerCount?.toString() ?? '');
    _innerSizeController = TextEditingController(text: p?.innerSize?.toString() ?? '');

    _selectedCategoryId = p?.categoryId ?? widget.initialCategoryId;
    _imagePath = p?.imagePath;

    final existingUnit = p?.unit;
    _selectedUnit = (existingUnit != null && _unitOptions.contains(existingUnit))
        ? existingUnit
        : (existingUnit != null ? _customValue : 'قطعة');
    _customUnitController =
        TextEditingController(text: _selectedUnit == _customValue ? existingUnit : '');

    final existingPackaging = p?.packagingType;
    _selectedPackaging =
        (existingPackaging != null && _packagingOptions.contains(existingPackaging))
            ? existingPackaging
            : (existingPackaging != null ? _customValue : 'بدون');
    _customPackagingController = TextEditingController(
        text: _selectedPackaging == _customValue ? existingPackaging : '');

    _loadCategories();
    if (_isEditing) {
      _refreshSupplyInfo();
    }
  }

  Future<void> _loadCategories() async {
    final categories = await _repository.getCategories();
    setState(() {
      _categories = categories;
      _loadingCategories = false;
    });
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 75, maxWidth: 1000);
    if (picked != null) {
      setState(() => _imagePath = picked.path);
    }
  }

  Future<void> _addCategoryQuick() async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فئة جديدة'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم الفئة'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
        ],
      ),
    );

    if (confirmed != true || nameController.text.trim().isEmpty) return;
    final newId = await _repository.addCategory(Category(name: nameController.text.trim()));
    await _loadCategories();
    setState(() => _selectedCategoryId = newId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _quantityController.dispose();
    _reorderLevelController.dispose();
    _customUnitController.dispose();
    _customPackagingController.dispose();
    _unitsPerPackageController.dispose();
    _innerCountController.dispose();
    _innerSizeController.dispose();
    super.dispose();
  }

  /// بيعيد جلب الكمية المحدّثة وآخر توريد وأقرب صلاحية من قاعدة البيانات
  /// (لازم نناديها كل ما نرجع من شاشة توريد جديد، عشان الشاشة متفضلش عارضة بيانات قديمة)
  Future<void> _refreshSupplyInfo() async {
    final productId = widget.product?.id;
    if (productId == null) return;

    final refreshedProduct = await _repository.getProductById(productId);
    if (refreshedProduct != null && mounted) {
      _quantityController.text = refreshedProduct.quantity.toString();
    }

    final batches = await SupplyBatchRepository().getBatchesForProduct(productId);
    Map<String, dynamic>? latest;
    Map<String, dynamic>? nearestExpiry;

    for (final batch in batches) {
      final supplyDate = batch['supply_date'] as String;
      if (latest == null || supplyDate.compareTo(latest['supply_date'] as String) > 0) {
        latest = batch;
      }
      final expiryDate = batch['expiry_date'] as String?;
      final remaining = (batch['remaining_quantity'] as num).toDouble();
      if (expiryDate != null && remaining > 0) {
        final currentNearest = nearestExpiry?['expiry_date'] as String?;
        if (currentNearest == null || expiryDate.compareTo(currentNearest) < 0) {
          nearestExpiry = batch;
        }
      }
    }

    if (mounted) {
      setState(() {
        _latestBatch = latest;
        _nearestExpiryBatch = nearestExpiry;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final product = Product(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      categoryId: _selectedCategoryId,
      imagePath: _imagePath,
      unit: _effectiveUnit.isEmpty ? null : _effectiveUnit,
      packagingType: _hasPackaging ? _effectivePackaging : null,
      unitsPerPackage: (_hasPackaging && _isPieceUnit)
          ? double.tryParse(_unitsPerPackageController.text)
          : null,
      innerCount: (_hasPackaging && !_isPieceUnit)
          ? double.tryParse(_innerCountController.text)
          : null,
      innerSize: (_hasPackaging && !_isPieceUnit)
          ? double.tryParse(_innerSizeController.text)
          : null,
      purchasePrice: double.parse(_purchasePriceController.text),
      salePrice: double.parse(_salePriceController.text),
      quantity: double.parse(_quantityController.text),
      reorderLevel: double.parse(_reorderLevelController.text),
      createdAt: widget.product?.createdAt ?? DateTime.now().toIso8601String(),
    );

    int savedId;
    final barcodeWasEmpty = product.barcode == null;

    if (_isEditing) {
      await _repository.updateProduct(product);
      savedId = product.id!;
    } else {
      savedId = await _repository.addProduct(product);
    }

    if (!mounted) return;

    // لو الباركود اتولّد تلقائيًا (كان فاضي)، نفتح شاشة الباركود مباشرة
    if (barcodeWasEmpty) {
      final savedProduct = await _repository.getProductById(savedId);
      if (savedProduct != null && mounted) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => BarcodeLabelScreen(product: savedProduct)),
        );
        return;
      }
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل صنف' : 'إضافة صنف جديد')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (_isEditing && (_latestBatch != null || _nearestExpiryBatch != null)) ...[
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('آخر توريد', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        if (_latestBatch != null) ...[
                          Text('المورد: ${_latestBatch!['supplier_name'] ?? 'غير محدد'}'),
                          Text('تاريخ التوريد: ${(_latestBatch!['supply_date'] as String).substring(0, 10)}'),
                          if (_latestBatch!['received_by'] != null)
                            Text('المستلم: ${_latestBatch!['received_by']}'),
                        ],
                        if (_nearestExpiryBatch != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'أقرب صلاحية: ${(_nearestExpiryBatch!['expiry_date'] as String).substring(0, 10)}'
                            '  (متبقي ${(_nearestExpiryBatch!['remaining_quantity'] as num).toStringAsFixed(0)})',
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      image: _imagePath != null
                          ? DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _imagePath == null
                        ? const Icon(Icons.add_a_photo_outlined, size: 32)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الصنف'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الصنف مطلوب' : null,
              ),
              const SizedBox(height: 12),
              if (!_loadingCategories)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(labelText: 'الفئة (اختياري)'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('بدون فئة')),
                          ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (value) => setState(() => _selectedCategoryId = value),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'إضافة فئة جديدة',
                      onPressed: _addCategoryQuick,
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'الباركود (سيبها فاضية عشان يتولّد تلقائي)',
                  suffixIcon: BarcodeScanButton(
                    onScanned: (value) => setState(() => _barcodeController.text = value),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purchasePriceController,
                decoration: const InputDecoration(labelText: 'سعر الشراء'),
                keyboardType: TextInputType.number,
                validator: _numberValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salePriceController,
                decoration: const InputDecoration(labelText: 'سعر البيع'),
                keyboardType: TextInputType.number,
                validator: _numberValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'الكمية'),
                keyboardType: TextInputType.number,
                validator: _numberValidator,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(labelText: 'وحدة القياس'),
                      items: [
                        ..._unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))),
                        const DropdownMenuItem(value: _customValue, child: Text('أخرى (اكتب بنفسك)')),
                      ],
                      onChanged: (value) => setState(() => _selectedUnit = value ?? 'قطعة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPackaging,
                      decoration: const InputDecoration(labelText: 'نوع العبوة'),
                      items: [
                        ..._packagingOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))),
                        const DropdownMenuItem(value: _customValue, child: Text('أخرى (اكتب بنفسك)')),
                      ],
                      onChanged: (value) => setState(() => _selectedPackaging = value ?? 'بدون'),
                    ),
                  ),
                ],
              ),
              if (_unitIsCustom || _packagingIsCustom) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_unitIsCustom)
                      Expanded(
                        child: TextFormField(
                          controller: _customUnitController,
                          decoration: const InputDecoration(labelText: 'اكتب وحدة القياس'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    if (_unitIsCustom && _packagingIsCustom) const SizedBox(width: 8),
                    if (_packagingIsCustom)
                      Expanded(
                        child: TextFormField(
                          controller: _customPackagingController,
                          decoration: const InputDecoration(labelText: 'اكتب نوع العبوة'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                  ],
                ),
              ],
              if (_hasPackaging && _isPieceUnit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitsPerPackageController,
                  decoration: InputDecoration(labelText: 'عدد $_effectiveUnit في ال$_effectivePackaging'),
                  keyboardType: TextInputType.number,
                ),
              ],
              if (_hasPackaging && !_isPieceUnit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _innerCountController,
                  decoration: InputDecoration(labelText: 'عدد العبوات الداخلية في ال$_effectivePackaging'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _innerSizeController,
                  decoration: InputDecoration(labelText: 'وزن/حجم العبوة الداخلية الواحدة ($_effectiveUnit)'),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _reorderLevelController,
                decoration: const InputDecoration(labelText: 'حد إعادة الطلب'),
                keyboardType: TextInputType.number,
                validator: _numberValidator,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupplyBatchFormScreen(product: widget.product!),
                      ),
                    );
                    // نحدّث الكمية وآخر توريد فورًا، عشان الشاشة متفضلش عارضة بيانات قديمة
                    await _refreshSupplyInfo();
                  },
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('تسجيل توريد جديد'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductBatchHistoryScreen(product: widget.product!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_outlined),
                  label: const Text('سجل التوريدات'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InventoryMovementsScreen(product: widget.product!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('سجل حركة المخزون (دخول/خروج بالتاريخ والوقت)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'الحقل مطلوب';
    if (double.tryParse(value) == null) return 'قيمة غير صحيحة';
    return null;
  }
}
