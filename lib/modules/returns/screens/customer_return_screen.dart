import 'package:flutter/material.dart';
import '../../sales/repository/sales_repository.dart';
import '../repository/returns_repository.dart';
import '../../../core/auth/session/current_session.dart';

/// مرتجع عميل: بندخل رقم فاتورة، بيطلع أصنافها، ونختار صنف وكمية للإرجاع.
class CustomerReturnScreen extends StatefulWidget {
  const CustomerReturnScreen({super.key});

  @override
  State<CustomerReturnScreen> createState() => _CustomerReturnScreenState();
}

class _CustomerReturnScreenState extends State<CustomerReturnScreen> {
  final _salesRepository = SalesRepository();
  final _returnsRepository = ReturnsRepository();
  final _invoiceController = TextEditingController();

  int? _saleId;
  List<Map<String, dynamic>> _items = [];
  bool _searching = false;
  String? _error;

  Future<void> _search() async {
    final id = int.tryParse(_invoiceController.text.trim());
    if (id == null) {
      setState(() => _error = 'اكتب رقم فاتورة صحيح');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _items = [];
      _saleId = null;
    });

    final sale = await _salesRepository.getSaleById(id);
    if (sale == null) {
      setState(() {
        _searching = false;
        _error = 'مفيش فاتورة برقم #$id';
      });
      return;
    }
    final items = await _salesRepository.getSaleItems(id);
    setState(() {
      _saleId = id;
      _items = items;
      _searching = false;
    });
  }

  Future<void> _returnItem(Map<String, dynamic> item) async {
    final maxQty = (item['quantity'] as num).toDouble();
    final unitPrice = (item['unit_price'] as num).toDouble();
    final qtyController = TextEditingController(text: maxQty.toStringAsFixed(0));
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إرجاع ${item['product_name']}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الكمية المباعة في الفاتورة: ${maxQty.toStringAsFixed(0)}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'الكمية المرتجعة'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final parsed = double.tryParse(v ?? '');
                  if (parsed == null || parsed <= 0) return 'قيمة غير صحيحة';
                  if (parsed > maxQty) return 'الكمية أكبر من المباع';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'سبب الإرجاع (اختياري)'),
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
            child: const Text('تأكيد الإرجاع'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _returnsRepository.recordCustomerReturn(
      productId: item['product_id'] as int,
      quantity: double.parse(qtyController.text),
      unitPrice: unitPrice,
      referenceSaleId: _saleId,
      reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      processedBy: CurrentSession.instance.user?.name,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل المرتجع وإضافة الكمية للمخزون')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مرتجع عميل')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _invoiceController,
                    decoration: const InputDecoration(labelText: 'رقم الفاتورة'),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: const Text('بحث'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            if (_searching) const Center(child: CircularProgressIndicator()),
            if (_items.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      child: ListTile(
                        title: Text(item['product_name'] as String),
                        subtitle: Text(
                          'الكمية: ${(item['quantity'] as num).toStringAsFixed(0)}'
                          '  •  السعر: ${(item['unit_price'] as num).toStringAsFixed(2)}',
                        ),
                        trailing: OutlinedButton(
                          onPressed: () => _returnItem(item),
                          child: const Text('إرجاع'),
                        ),
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
