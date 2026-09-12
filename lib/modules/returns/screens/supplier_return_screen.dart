import 'package:flutter/material.dart';
import '../../inventory/models/product.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../../inventory/repository/supply_batch_repository.dart';
import '../repository/returns_repository.dart';
import '../../../core/auth/session/current_session.dart';

/// مرتجع مورد: نختار صنف، بعدين دفعة توريد بعينها منه (عشان نعرف نخصم من
/// المورد الصح ونحدّث الكمية المتبقية في الدفعة دي تحديدًا)، وبعدين الكمية.
class SupplierReturnScreen extends StatefulWidget {
  const SupplierReturnScreen({super.key});

  @override
  State<SupplierReturnScreen> createState() => _SupplierReturnScreenState();
}

class _SupplierReturnScreenState extends State<SupplierReturnScreen> {
  final _inventoryRepository = InventoryRepository();
  final _batchRepository = SupplyBatchRepository();
  final _returnsRepository = ReturnsRepository();

  String _searchQuery = '';
  List<Product> _searchResults = [];
  Product? _selectedProduct;
  List<Map<String, dynamic>> _batches = [];
  bool _loadingBatches = false;

  Future<void> _search(String query) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await _inventoryRepository.getAllProducts(searchQuery: query);
    setState(() => _searchResults = results);
  }

  Future<void> _selectProduct(Product product) async {
    setState(() {
      _selectedProduct = product;
      _searchResults = [];
      _searchQuery = '';
      _loadingBatches = true;
    });
    final batches = await _batchRepository.getBatchesForProduct(product.id!);
    setState(() {
      _batches = batches.where((b) => (b['remaining_quantity'] as num).toDouble() > 0).toList();
      _loadingBatches = false;
    });
  }

  Future<void> _returnFromBatch(Map<String, dynamic> batch) async {
    final maxQty = (batch['remaining_quantity'] as num).toDouble();
    final qtyController = TextEditingController(text: maxQty.toStringAsFixed(0));
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إرجاع للمورد: ${batch['supplier_name'] ?? 'غير محدد'}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الكمية المتاحة في هذه الدفعة: ${maxQty.toStringAsFixed(0)}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'الكمية المرتجعة للمورد'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final parsed = double.tryParse(v ?? '');
                  if (parsed == null || parsed <= 0) return 'قيمة غير صحيحة';
                  if (parsed > maxQty) return 'الكمية أكبر من المتاح في الدفعة';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'سبب الإرجاع (تلف/انتهاء صلاحية...)'),
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

    await _returnsRepository.recordSupplierReturn(
      productId: _selectedProduct!.id!,
      batchId: batch['id'] as int,
      supplierId: batch['supplier_id'] as int?,
      quantity: double.parse(qtyController.text),
      reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      processedBy: CurrentSession.instance.user?.name,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل المرتجع للمورد وخصم الكمية من المخزون')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مرتجع مورد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedProduct == null) ...[
              TextField(
                decoration: const InputDecoration(
                  hintText: 'ابحث عن الصنف',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
                onChanged: _search,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final product = _searchResults[index];
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text('المتاح: ${product.quantity.toStringAsFixed(0)}'),
                      onTap: () => _selectProduct(product),
                    );
                  },
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedProduct!.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedProduct = null;
                      _batches = [];
                    }),
                    child: const Text('تغيير الصنف'),
                  ),
                ],
              ),
              const Divider(),
              if (_loadingBatches) const Center(child: CircularProgressIndicator()),
              if (!_loadingBatches && _batches.isEmpty)
                const Expanded(
                  child: Center(child: Text('لا توجد دفعات توريد متاحة لهذا الصنف')),
                ),
              if (_batches.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _batches.length,
                    itemBuilder: (context, index) {
                      final batch = _batches[index];
                      final expiryDate = batch['expiry_date'] as String?;
                      return Card(
                        child: ListTile(
                          title: Text(
                            'الكمية المتبقية: ${(batch['remaining_quantity'] as num).toStringAsFixed(0)}'
                            ' من ${(batch['quantity_received'] as num).toStringAsFixed(0)}',
                          ),
                          subtitle: Text(
                            'المورد: ${batch['supplier_name'] ?? 'غير محدد'}\n'
                            'تاريخ التوريد: ${(batch['supply_date'] as String).substring(0, 10)}'
                            '${expiryDate != null ? '  •  الصلاحية: ${expiryDate.substring(0, 10)}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: OutlinedButton(
                            onPressed: () => _returnFromBatch(batch),
                            child: const Text('إرجاع'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
