import 'package:flutter/material.dart';
import '../repository/returns_repository.dart';

class ReturnsHistoryScreen extends StatefulWidget {
  const ReturnsHistoryScreen({super.key});

  @override
  State<ReturnsHistoryScreen> createState() => _ReturnsHistoryScreenState();
}

class _ReturnsHistoryScreenState extends State<ReturnsHistoryScreen> {
  final _repository = ReturnsRepository();
  List<Map<String, dynamic>> _returns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final returns = await _repository.getReturnsHistory();
    setState(() {
      _returns = returns;
      _loading = false;
    });
  }

  String _formatDateTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل المرتجعات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _returns.isEmpty
              ? const Center(child: Text('لا توجد مرتجعات مسجلة'))
              : ListView.builder(
                  itemCount: _returns.length,
                  itemBuilder: (context, index) {
                    final r = _returns[index];
                    final isCustomer = r['type'] == 'customer';
                    return ListTile(
                      leading: Icon(
                        isCustomer ? Icons.assignment_return_outlined : Icons.local_shipping_outlined,
                        color: isCustomer ? Colors.blue : Colors.purple,
                      ),
                      title: Text(
                        '${r['product_name']}  •  ${isCustomer ? 'مرتجع عميل' : 'مرتجع مورد'}',
                      ),
                      subtitle: Text(
                        '${_formatDateTime(r['date'] as String)}'
                        '${!isCustomer && r['supplier_name'] != null ? '  •  المورد: ${r['supplier_name']}' : ''}'
                        '${isCustomer && r['reference_sale_id'] != null ? '  •  فاتورة #${r['reference_sale_id']}' : ''}'
                        '${r['reason'] != null ? '\nالسبب: ${r['reason']}' : ''}',
                      ),
                      isThreeLine: r['reason'] != null,
                      trailing: Text(
                        (r['quantity'] as num).toStringAsFixed(0),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
    );
  }
}
