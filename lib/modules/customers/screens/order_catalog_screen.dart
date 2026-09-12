import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../inventory/models/product.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../models/customer.dart';

/// كتالوج طلب مبسّط: تختار الأصناف المتاحة اللي عايز تعرضها، والتطبيق
/// بيبني رسالة نصية بالأسماء والأسعار جاهزة للمشاركة - بديل بسيط
/// لـ"اطلب دلوقتي" من غير أي تطبيق أو موقع منفصل. لو اتفتحت من بروفايل
/// عميل معين، فيه زرار إضافي يبعتها على واتساب العميل ده مباشرة.
class OrderCatalogScreen extends StatefulWidget {
  final Customer? customer;

  const OrderCatalogScreen({super.key, this.customer});

  @override
  State<OrderCatalogScreen> createState() => _OrderCatalogScreenState();
}

class _OrderCatalogScreenState extends State<OrderCatalogScreen> {
  final _repository = InventoryRepository();
  List<Product> _products = [];
  final Set<int> _selectedIds = {};
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products = await _repository.getAllProducts(searchQuery: _searchQuery);
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  String _buildCatalogText() {
    final selected = _products.where((p) => _selectedIds.contains(p.id)).toList();
    final buffer = StringBuffer('قائمة الأصناف المتاحة:\n\n');
    for (final product in selected) {
      buffer.writeln('- ${product.name}: ${product.salePrice.toStringAsFixed(2)} ج');
    }
    buffer.write('\nابعتلنا اللي عايزه ونجهزهولك.');
    return buffer.toString();
  }

  Future<void> _share() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختار صنف واحد على الأقل الأول')));
      return;
    }
    await Share.share(_buildCatalogText());
  }

  Future<void> _sendToCustomer() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختار صنف واحد على الأقل الأول')));
      return;
    }
    final phone = widget.customer?.phone;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد رقم تليفون مسجل لهذا العميل')));
      return;
    }
    await WhatsAppHelper.openChat(phone: phone, text: _buildCatalogText());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer != null ? 'كتالوج لـ ${widget.customer!.name}' : 'كتالوج الطلب'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث عن صنف',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('لا توجد أصناف'))
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return CheckboxListTile(
                      value: _selectedIds.contains(product.id),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedIds.add(product.id!);
                          } else {
                            _selectedIds.remove(product.id);
                          }
                        });
                      },
                      title: Text(product.name),
                      subtitle: Text('${product.salePrice.toStringAsFixed(2)} ج'),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('مشاركة الكتالوج'),
                ),
              ),
              if (widget.customer != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sendToCustomer,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('إرسال على واتساب'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
