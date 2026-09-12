import 'package:flutter/material.dart';
import '../../inventory/models/product.dart';
import '../../inventory/repository/inventory_repository.dart';

/// شاشة تصفح كامل المخزون - بديل لكتابة اسم الصنف
/// بترجع المنتج اللي اختاره الكاشير عند الضغط عليه
class ProductPickerScreen extends StatefulWidget {
  const ProductPickerScreen({super.key});

  @override
  State<ProductPickerScreen> createState() => _ProductPickerScreenState();
}

class _ProductPickerScreenState extends State<ProductPickerScreen> {
  final _repository = InventoryRepository();
  List<Product> _products = [];
  bool _loading = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await _repository.getAllProducts();
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filter.trim().isEmpty
        ? _products
        : _products
            .where((p) => p.name.toLowerCase().contains(_filter.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر صنف'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'فلترة سريعة داخل القائمة',
                prefixIcon: Icon(Icons.filter_list),
                filled: true,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              onChanged: (value) => setState(() => _filter = value),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : visible.isEmpty
              ? const Center(child: Text('لا توجد أصناف'))
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final product = visible[index];
                    final outOfStock = product.quantity <= 0;
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text(
                        'السعر: ${product.salePrice.toStringAsFixed(2)}'
                        '  •  متوفر: ${product.quantity.toStringAsFixed(0)}',
                      ),
                      enabled: !outOfStock,
                      trailing: outOfStock
                          ? const Text('نفد المخزون', style: TextStyle(color: Colors.red))
                          : const Icon(Icons.add_circle_outline),
                      onTap: outOfStock ? null : () => Navigator.pop(context, product),
                    );
                  },
                ),
    );
  }
}
