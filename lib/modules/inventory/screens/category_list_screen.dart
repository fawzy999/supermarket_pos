import 'package:flutter/material.dart';
import '../models/category.dart';
import '../repository/inventory_repository.dart';
import 'category_products_screen.dart';
import 'inventory_home_screen.dart';
import 'supplier_list_screen.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final _repository = InventoryRepository();
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final categories = await _repository.getCategoriesWithCounts();
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فئة جديدة'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم الفئة (مثلاً: زيوت، مكرونة، أرز)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
        ],
      ),
    );

    if (confirmed != true || nameController.text.trim().isEmpty) return;
    await _repository.addCategory(Category(name: nameController.text.trim()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'بحث في كل الأصناف',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryHomeScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: 'الموردين',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupplierListScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCategory,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('فئة جديدة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا توجد فئات حتى الآن\nدوس على "فئة جديدة" عشان تبدأ (زيوت، مكرونة، أرز...)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: _categories.map((category) {
                    final id = category['id'] as int?;
                    final name = category['name'] as String;
                    final count = category['product_count'] as int;
                    return Card(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryProductsScreen(categoryId: id, categoryName: name),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.category_outlined, size: 32),
                              const SizedBox(height: 8),
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('$count صنف', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
