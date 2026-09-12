import 'package:flutter/material.dart';
import '../models/product.dart';
import '../repository/inventory_repository.dart';
import 'product_form_screen.dart';
import 'inventory_movements_screen.dart';

class InventoryHomeScreen extends StatefulWidget {
  const InventoryHomeScreen({super.key});

  @override
  State<InventoryHomeScreen> createState() => _InventoryHomeScreenState();
}

class _InventoryHomeScreenState extends State<InventoryHomeScreen> {
  final _repository = InventoryRepository();
  List<Product> _products = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final products = await _repository.getAllProducts(searchQuery: _searchQuery);
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _openForm({Product? product}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    // بنحدّث القائمة دايمًا عند الرجوع، مش بس لما يتحفظ الصنف نفسه،
    // عشان أي توريد جديد اتسجل من جوه شاشة التعديل يظهر فورًا هنا
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final lowStockCount = _products.where((p) => p.isLowStock).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث في كل الأصناف'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'سجل حركة المخزون',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryMovementsScreen()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو الباركود',
                prefixIcon: Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _loadProducts();
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (lowStockCount > 0)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'تنبيه: $lowStockCount صنف وصل لحد إعادة الطلب',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('لا توجد أصناف حتى الآن'))
                    : ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                              'الكمية: ${product.quantity.toStringAsFixed(0)}'
                              '  •  سعر البيع: ${product.salePrice.toStringAsFixed(2)}',
                            ),
                            trailing: product.isLowStock
                                ? const Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange)
                                : null,
                            onTap: () => _openForm(product: product),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
