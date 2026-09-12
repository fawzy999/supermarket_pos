import 'package:flutter/material.dart';
import '../../inventory/models/product.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../models/cart_item.dart';
import '../repository/sales_repository.dart';
import '../../../core/widgets/barcode_scanner_button.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/settings/app_settings_repository.dart';
import 'sales_history_screen.dart';
import 'invoice_screen.dart';
import 'product_picker_screen.dart';
import '../../../core/auth/session/current_session.dart';
import '../../customers/models/customer.dart';
import '../../customers/screens/customer_picker_screen.dart';
import '../../reps/models/rep.dart';
import '../../reps/repository/rep_repository.dart';
import '../../../core/services/scan_sound_service.dart';

const List<double> _quickFractions = [0.25, 0.333, 0.5, 1, 2];
// ملحوظة: مش ممكن تبقى const لأن double مالوش "primitive equality" في
// دارت (بسبب NaN و -0.0)، فمابيصلحش يتستخدم كمفتاح في const Map/Set.
final Map<double, String> _quickFractionLabels = {
  0.25: '¼',
  0.333: '⅓',
  0.5: '½',
  1: '1',
  2: '2',
};

class SalesHomeScreen extends StatefulWidget {
  const SalesHomeScreen({super.key});

  @override
  State<SalesHomeScreen> createState() => _SalesHomeScreenState();
}

class _SalesHomeScreenState extends State<SalesHomeScreen> {
  final _inventoryRepository = InventoryRepository();
  final _salesRepository = SalesRepository();
  final _appSettingsRepository = AppSettingsRepository();
  final _repRepository = RepRepository();
  final _scanSoundService = ScanSoundService();

  final List<CartItem> _cart = [];
  List<Product> _searchResults = [];
  String _searchQuery = '';
  bool _processing = false;
  double _discountPercent = 0;

  double get _subtotal => _cart.fold(0, (sum, item) => sum + item.lineTotal);
  double get _discountAmount => _subtotal * (_discountPercent / 100);
  double get _cartTotal => _subtotal - _discountAmount;

  Future<void> _search(String query) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await _inventoryRepository.getAllProducts(searchQuery: query);
    setState(() => _searchResults = results);
  }

  Future<void> _addByBarcode(String barcode) async {
    final product = await _inventoryRepository.getProductByBarcode(barcode);
    if (product == null) {
      _scanSoundService.playError();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مفيش صنف بالباركود ده')),
        );
      }
      return;
    }
    _scanSoundService.playSuccess();
    _addToCart(product);
  }

  Future<void> _openProductPicker() async {
    final selected = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const ProductPickerScreen()),
    );
    if (selected != null) _addToCart(selected);
  }

  void _addToCart(Product product) {
    setState(() {
      final existingIndex =
          _cart.indexWhere((c) => c.type == CartItemType.product && c.product?.id == product.id);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity += 1;
      } else {
        _cart.add(CartItem(product: product));
      }
      _searchResults = [];
      _searchQuery = '';
    });
  }

  void _updateQuantity(int index, double delta) {
    setState(() {
      _cart[index].quantity += delta;
      if (_cart[index].quantity <= 0) {
        _cart.removeAt(index);
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  /// لوحة تعديل كمية دقيقة (تدعم الكسور) - مفيدة للبضاعة إلى بتتباع
  /// بالوزن زي الجبنة والخلاصة الطحينية (نص كيلو، ربع كيلو، إلخ)
  Future<void> _editQuantity(int index) async {
    final controller = TextEditingController(text: formatQuantity(_cart[index].quantity));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('كمية: ${_cart[index].displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'الكمية (تقبل كسور زي 0.5)'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _quickFractions
                  .map((f) => OutlinedButton(
                        onPressed: () => controller.text = formatQuantity(f),
                        child: Text(_quickFractionLabels[f] ?? formatQuantity(f)),
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.'));
              if (value != null && value > 0) Navigator.pop(context, value);
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
    if (result != null) setState(() => _cart[index].quantity = result);
  }

  /// إضافة صنف مش مسجّل بالمخزون (حاجة نادرة أو عرض لمرة واحدة) أو
  /// خدمة (زي التوصيل) - بيتحسبوا في الفاتورة من غير ما يمسّوا المخزون
  Future<void> _addManualOrService({required bool isService}) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isService ? 'إضافة خدمة' : 'إضافة صنف يدوي'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: isService ? 'اسم الخدمة (توصيل مثلًا)' : 'اسم الصنف'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'السعر'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final parsed = double.tryParse(v ?? '');
                  if (parsed == null || parsed <= 0) return 'قيمة غير صحيحة';
                  return null;
                },
              ),
              TextFormField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'الكمية'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final parsed = double.tryParse(v ?? '');
                  if (parsed == null || parsed <= 0) return 'قيمة غير صحيحة';
                  return null;
                },
              ),
            ],
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

    final name = nameController.text.trim();
    final price = double.parse(priceController.text);
    final qty = double.parse(qtyController.text);

    setState(() {
      _cart.add(isService
          ? CartItem.service(name: name, price: price, quantity: qty)
          : CartItem.manual(name: name, price: price, quantity: qty));
    });
  }

  /// خصم بنسبة على إجمالي الفاتورة - مسموح بيه ومحدود بأقصى نسبة من
  /// إعدادات الإدارة (شاشة "إعدادات الخصم" في لوحة التحكم)
  Future<void> _openDiscountDialog() async {
    final enabled = (await _appSettingsRepository.get(AppSettingsRepository.keyDiscountEnabled)) == '1';
    if (!enabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الخصم مش مفعّل حاليًا - فعّله من لوحة التحكم > إعدادات الخصم')),
        );
      }
      return;
    }
    final maxDiscountStr = await _appSettingsRepository.get(AppSettingsRepository.keyMaxDiscountPercent);
    final maxDiscount = double.tryParse(maxDiscountStr ?? '') ?? 10;

    final controller = TextEditingController(text: _discountPercent == 0 ? '' : formatQuantity(_discountPercent));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خصم على الفاتورة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'نسبة الخصم % (أقصى حد مسموح: $maxDiscount%)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 0.0), child: const Text('إلغاء الخصم')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
              if (value < 0 || value > maxDiscount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('أقصى نسبة خصم مسموحة $maxDiscount%')),
                );
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
    if (result != null) setState(() => _discountPercent = result);
  }

  /// فتح شاشة اختيار عميل حقيقي (بحث بالاسم أو التليفون + إمكانية إضافة
  /// عميل جديد من نفس الشاشة) - بترجع Customer أو null لو رجع من غير اختيار
  Future<Customer?> _pickCustomer() {
    return Navigator.push<Customer>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerPickerScreen()),
    );
  }

  /// سؤال اختياري "تحب تسجل عميل مع الفاتورة؟" - يفتح شاشة اختيار/إضافة
  /// عميل حقيقي لو حابب، أو يكمّل من غيره لو دوس "بدون عميل". مستخدم مع
  /// كل طرق الدفع إلا "حساب عميل" (ده لازم عميل فعلي بطبيعته)
  Future<Customer?> _askOptionalCustomer() async {
    final wantsCustomer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عميل الفاتورة'),
        content: const Text('تحب تسجل عميل مع الفاتورة دي؟ (تقدر تختار من المسجلين أو تضيف عميل جديد)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('بدون عميل')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('اختيار/إضافة عميل')),
        ],
      ),
    );
    if (wantsCustomer != true) return null;
    return _pickCustomer();
  }

  /// اختيار مندوب لتحويل مديونية الفاتورة عليه ("حساب مندوب")
  Future<Rep?> _pickRep() async {
    final reps = await _repRepository.getAllReps(activeOnly: true);
    if (!mounted) return null;
    if (reps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مفيش مناديب نشطين مسجلين - أضف مندوب من موديول المناديب الأول')),
      );
      return null;
    }
    return showDialog<Rep>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختار المندوب'),
        children: reps
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, r),
                  child: Text(r.name),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;

    final paymentMethod = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('طريقة الدفع'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'cash'),
            child: const Text('كاش'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'card'),
            child: const Text('فيزا / بطاقة'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'rep_account'),
            child: const Text('حساب مندوب'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'credit'),
            child: const Text('حساب عميل'),
          ),
        ],
      ),
    );

    if (paymentMethod == null) return;

    String? customerName;
    String? customerPhone;
    int? customerId;
    int? repId;

    if (paymentMethod == 'credit') {
      // "حساب عميل": لازم عميل فعلي (تختاره من المسجلين أو تضيفه دلوقتي)
      // عشان مديونية الفاتورة تتقيّد على حسابه - من غيره الفاتورة مالهاش معنى
      Customer? selectedCustomer;
      while (selectedCustomer == null) {
        selectedCustomer = await _pickCustomer();
        if (selectedCustomer == null) {
          final retry = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('لازم عميل'),
              content: const Text('"حساب عميل" لازم يكون مرتبط بعميل - اختار واحد من المسجلين أو أضف عميل جديد'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع لطريقة الدفع')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حاول تاني')),
              ],
            ),
          );
          if (retry != true) return;
        }
      }
      customerId = selectedCustomer.id;
      customerName = selectedCustomer.name;
      customerPhone = selectedCustomer.phone;
    } else if (paymentMethod == 'rep_account') {
      // "حساب مندوب": لازم تختار المندوب المسؤول عن توصيل الفاتورة دي
      final selectedRep = await _pickRep();
      if (selectedRep == null) return;
      repId = selectedRep.id;
      // العميل هنا اختياري بس (بيانات توصيل مفيدة، بس مش شرط لتسجيل المديونية)
      final selectedCustomer = await _askOptionalCustomer();
      customerId = selectedCustomer?.id;
      customerName = selectedCustomer?.name;
      customerPhone = selectedCustomer?.phone;
    } else {
      // كاش/فيزا: عميل اختياري بالكامل - لو حابب تسجله بيكون عميل حقيقي
      // من قائمة العملاء (تقدر تضيفه لو مش موجود) مش نص حر زي الأول
      final selectedCustomer = await _askOptionalCustomer();
      customerId = selectedCustomer?.id;
      customerName = selectedCustomer?.name;
      customerPhone = selectedCustomer?.phone;
    }

    setState(() => _processing = true);
    try {
      final saleId = await _salesRepository.checkout(
        cartItems: _cart,
        paymentMethod: paymentMethod,
        userId: CurrentSession.instance.user?.id,
        customerName: customerName,
        customerPhone: customerPhone,
        customerId: customerId,
        discountPercent: _discountPercent,
        repId: repId,
      );
      if (mounted) {
        setState(() {
          _cart.clear();
          _discountPercent = 0;
          _processing = false;
        });
        // فتح الفاتورة مباشرة بعد البيع
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InvoiceScreen(saleId: saleId)),
        );
      }
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'سجل المبيعات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو الباركود',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: const OutlineInputBorder(borderSide: BorderSide.none),
                      suffixIcon: BarcodeScanButton(onScanned: _addByBarcode),
                    ),
                    onChanged: _search,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.list_alt),
                  tooltip: 'اختيار من كل الأصناف',
                  onPressed: _openProductPicker,
                ),
              ],
            ),
          ),

          // أزرار الإضافات الإضافية: صنف يدوي، خدمة، خصم
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _addManualOrService(isService: false),
                  icon: const Icon(Icons.edit_note_outlined, size: 18),
                  label: const Text('صنف يدوي'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addManualOrService(isService: true),
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('خدمة (توصيل...)'),
                ),
                OutlinedButton.icon(
                  onPressed: _openDiscountDialog,
                  icon: const Icon(Icons.percent_outlined, size: 18),
                  label: Text(_discountPercent > 0 ? 'خصم ${formatQuantity(_discountPercent)}%' : 'خصم'),
                ),
              ],
            ),
          ),

          // نتائج البحث (تظهر بس وقت الكتابة)
          if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final product = _searchResults[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text('السعر: ${product.salePrice.toStringAsFixed(2)}'
                        '  •  متوفر: ${formatQuantity(product.quantity)}'),
                    onTap: () => _addToCart(product),
                  );
                },
              ),
            ),

          const Divider(height: 24),

          // السلة الحالية
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('السلة فاضية، ابحث عن صنف أو امسح باركود'))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      final typeLabel = switch (item.type) {
                        CartItemType.manual => ' (يدوي)',
                        CartItemType.service => ' (خدمة)',
                        CartItemType.product => '',
                      };
                      return ListTile(
                        title: Text('${item.displayName}$typeLabel'),
                        subtitle: GestureDetector(
                          onTap: () => _editQuantity(index),
                          child: Text(
                            '${item.unitPrice.toStringAsFixed(2)} × ${formatQuantity(item.quantity)}  (تعديل الكمية)',
                            style: const TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.type == CartItemType.product)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _updateQuantity(index, -1),
                              ),
                            if (item.type == CartItemType.product)
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => _updateQuantity(index, 1),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _removeFromCart(index),
                              ),
                            const SizedBox(width: 8),
                            Text('${item.lineTotal.toStringAsFixed(2)} ج'),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_discountPercent > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('الإجمالي قبل الخصم: ${_subtotal.toStringAsFixed(2)} ج')),
                      Text(
                        '- ${_discountAmount.toStringAsFixed(2)} ج (${formatQuantity(_discountPercent)}%)',
                        style: const TextStyle(color: Colors.deepOrange),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'الإجمالي: ${_cartTotal.toStringAsFixed(2)} ج',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  FilledButton(
                    onPressed: (_cart.isEmpty || _processing) ? null : _checkout,
                    child: Text(_processing ? 'جاري الحفظ...' : 'إتمام البيع'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
