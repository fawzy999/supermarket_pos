import 'package:flutter/material.dart';
import '../models/product.dart';
import '../repository/supply_batch_repository.dart';

class ProductBatchHistoryScreen extends StatefulWidget {
  final Product product;

  const ProductBatchHistoryScreen({super.key, required this.product});

  @override
  State<ProductBatchHistoryScreen> createState() => _ProductBatchHistoryScreenState();
}

class _ProductBatchHistoryScreenState extends State<ProductBatchHistoryScreen> {
  final _repository = SupplyBatchRepository();
  List<Map<String, dynamic>> _batches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final batches = await _repository.getBatchesForProduct(widget.product.id!);
    setState(() {
      _batches = batches;
      _loading = false;
    });
  }

  bool _isNearExpiry(String? expiryDate) {
    if (expiryDate == null) return false;
    final expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return false;
    return expiry.difference(DateTime.now()).inDays <= 7;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('توريدات ${widget.product.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _batches.isEmpty
              ? const Center(child: Text('لا توجد توريدات مسجلة لهذا الصنف'))
              : ListView.builder(
                  itemCount: _batches.length,
                  itemBuilder: (context, index) {
                    final batch = _batches[index];
                    final expiryDate = batch['expiry_date'] as String?;
                    final nearExpiry = _isNearExpiry(expiryDate);

                    return ListTile(
                      leading: Icon(
                        Icons.inventory_outlined,
                        color: nearExpiry ? Colors.orange : null,
                      ),
                      title: Text(
                        'الكمية المتبقية: ${(batch['remaining_quantity'] as num).toStringAsFixed(0)}'
                        ' من ${(batch['quantity_received'] as num).toStringAsFixed(0)}',
                      ),
                      subtitle: Text(
                        'المورد: ${batch['supplier_name'] ?? 'غير محدد'}\n'
                        'تاريخ التوريد: ${(batch['supply_date'] as String).substring(0, 10)}'
                        '${expiryDate != null ? '  •  الصلاحية: ${expiryDate.substring(0, 10)}' : ''}'
                        '${batch['received_by'] != null ? '\nالمستلم: ${batch['received_by']}' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: nearExpiry
                          ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
                          : null,
                    );
                  },
                ),
    );
  }
}
