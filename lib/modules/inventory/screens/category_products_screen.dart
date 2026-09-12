import 'dart:io';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../repository/inventory_repository.dart';
import 'product_form_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final int? categoryId;
  final String categoryName;

  const CategoryProductsScreen({super.key, required this.categoryId, required this.categoryName});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final _repository = InventoryRepository();
  List<Product> _products = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products = await _repository.getProductsByCategory(widget.categoryId, searchQuery: _searchQuery);
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _openForm({Product? product}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: product, initialCategoryId: widget.categoryId),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث داخل الفئة دي',
                prefixIcon: Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _load();
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('لا توجد أصناف في الفئة دي حتى الآن'))
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: product.imagePath != null
                            ? FileImage(File(product.imagePath!))
                            : null,
                        child: product.imagePath == null
                            ? const Icon(Icons.inventory_2_outlined)
                            : null,
                      ),
                      title: Text(product.name),
                      subtitle: Text(
                        'الكمية: ${product.quantity.toStringAsFixed(0)}'
                        '  •  سعر البيع: ${product.salePrice.toStringAsFixed(2)}',
                      ),
                      trailing: product.isLowStock
                          ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
                          : null,
                      onTap: () => _openForm(product: product),
                    );
                  },
                ),
    );
  }
}
