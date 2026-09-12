import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../repository/purchase_order_repository.dart';
import 'purchase_order_view_screen.dart';

/// سجل طلبات التوريد السابقة لمورد معين.
class PurchaseOrderListScreen extends StatefulWidget {
  final Supplier supplier;

  const PurchaseOrderListScreen({super.key, required this.supplier});

  @override
  State<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  final _repository = PurchaseOrderRepository();
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await _repository.getOrdersForSupplier(widget.supplier.id!);
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('طلبات التوريد - ${widget.supplier.companyName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('لا توجد طلبات توريد مسجلة لهذا المورد بعد'))
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return ListTile(
                      leading: const Icon(Icons.shopping_cart_outlined),
                      title: Text('طلب #${order['id']}'),
                      subtitle: Text((order['date'] as String).substring(0, 16).replaceFirst('T', ' ')),
                      trailing: Text('${(order['total_amount'] as num).toStringAsFixed(2)} ج'),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PurchaseOrderViewScreen(orderId: order['id'] as int)),
                        );
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}
