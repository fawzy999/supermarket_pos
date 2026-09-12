import 'package:flutter/material.dart';
import '../../customers/models/customer.dart';
import '../../customers/screens/customer_picker_screen.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../models/rep.dart';
import '../repository/rep_repository.dart';

class _ExternalSaleCartItem {
  final int productId;
  final String productName;
  double quantity;
  double unitPrice;
  final double availableInCustody;

  _ExternalSaleCartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.availableInCustody,
  });

  double get lineTotal => quantity * unitPrice;
}

/// تسجيل فاتورة بيع خارجي من عهدة المندوب (مش من مخزون المحل مباشرة)
/// لعميل - كاش أو آجل مربوط بحساب عميل مسجّل في موديول العملاء.
class RepExternalSaleScreen extends StatefulWidget {
  final Rep rep;

  const RepExternalSaleScreen({super.key, required this.rep});

  @override
  State<RepExternalSaleScreen> createState() => _RepExternalSaleScreenState();
}

class _RepExternalSaleScreenState extends State<RepExternalSaleScreen> {
  final _repository = RepRepository();
  final _inventoryRepository = InventoryRepository();

  List<Map<String, dynamic>> _custodyBalance = [];
  final List<_ExternalSaleCartItem> _cart = [];
  bool _loading = true;
  bool _saving = false;

  double get _total => _cart.fold(0, (sum, item) => sum + item.lineTotal);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final balance = await _repository.getCustodyBalance(widget.rep.id!);
    setState(() {
      _custodyBalance = balance;
      _loading = false;
    });
  }

  Future<void> _addItem() async {
    if (_custodyBalance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مفيش بضاعة في عهدة المندوب - اسحب بضاعة الأول')),
      );
      return;
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختر صنف من عهدته'),
        children: _custodyBalance
            .map((row) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, row),
                  child: Text('${row['product_name']}  (معاه: ${(row['remaining'] as num).toStringAsFixed(0)})'),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;

    final productId = selected['product_id'] as int;
    final available = (selected['remaining'] as num).toDouble();
    final product = await _inventoryRepository.getProductById(productId);

    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController(text: (product?.salePrice ?? 0).toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(selected['product_name'] as String),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'الكمية'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final parsed = double.tryParse(v ?? '');
                  if (parsed == null || parsed <= 0) return 'قيمة غير صحيحة';
                  return null;
                },
              ),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'سعر البيع للوحدة'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final parsed = double.tryParse(v ?? '');
                  if (parsed == null || parsed < 0) return 'قيمة غير صحيحة';
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

    setState(() {
      _cart.add(_ExternalSaleCartItem(
        productId: productId,
        productName: selected['product_name'] as String,
        quantity: double.parse(quantityController.text),
        unitPrice: double.parse(priceController.text),
        availableInCustody: available,
      ));
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;

    final paymentMethod = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('طريقة الدفع'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'cash'), child: const Text('كاش')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'credit'), child: const Text('آجل (على حساب عميل)')),
        ],
      ),
    );
    if (paymentMethod == null) return;

    int? customerId;
    String? customerName;
    String? customerPhone;

    if (paymentMethod == 'credit') {
      final selectedCustomer = await Navigator.push<Customer>(
        context,
        MaterialPageRoute(builder: (_) => const CustomerPickerScreen()),
      );
      if (selectedCustomer == null) return;
      customerId = selectedCustomer.id;
      customerName = selectedCustomer.name;
      customerPhone = selectedCustomer.phone;
    } else {
      final nameController = TextEditingController();
      final phoneController = TextEditingController();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('بيانات العميل (اختياري)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم العميل')),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'التليفون'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('متابعة')),
          ],
        ),
      );
      customerName = nameController.text.trim().isEmpty ? null : nameController.text.trim();
      customerPhone = phoneController.text.trim().isEmpty ? null : phoneController.text.trim();
    }

    setState(() => _saving = true);
    try {
      await _repository.recordExternalSale(
        repId: widget.rep.id!,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        paymentMethod: paymentMethod,
        items: _cart
            .map((item) => {
                  'product_id': item.productId,
                  'quantity': item.quantity,
                  'unit_price': item.unitPrice,
                })
            .toList(),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('بيع خارجي - ${widget.rep.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _cart.isEmpty
                      ? const Center(child: Text('اضغط "إضافة صنف" لبدء فاتورة بيع خارجي'))
                      : ListView.builder(
                          itemCount: _cart.length,
                          itemBuilder: (context, index) {
                            final item = _cart[index];
                            final exceeds = item.quantity > item.availableInCustody;
                            return ListTile(
                              title: Text(item.productName),
                              subtitle: Text(
                                '${item.unitPrice.toStringAsFixed(2)} × ${item.quantity.toStringAsFixed(0)}'
                                '${exceeds ? '  •  الكمية أكتر من اللي معاه!' : ''}',
                                style: exceeds ? const TextStyle(color: Colors.red) : null,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${item.lineTotal.toStringAsFixed(2)} ج'),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => setState(() => _cart.removeAt(index)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة صنف'),
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'الإجمالي: ${_total.toStringAsFixed(2)} ج',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton(
                onPressed: (_cart.isEmpty || _saving) ? null : _checkout,
                child: Text(_saving ? 'جاري الحفظ...' : 'إتمام البيع'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
