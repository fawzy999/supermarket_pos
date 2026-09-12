import 'package:flutter/material.dart';
import 'customer_return_screen.dart';
import 'supplier_return_screen.dart';
import 'returns_history_screen.dart';

class ReturnsHomeScreen extends StatelessWidget {
  const ReturnsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المرتجعات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_return_outlined, color: Colors.blue),
              title: const Text('مرتجع عميل'),
              subtitle: const Text('إرجاع صنف من فاتورة بيع سابقة وإعادته للمخزون'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerReturnScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined, color: Colors.purple),
              title: const Text('مرتجع مورد'),
              subtitle: const Text('إرجاع بضاعة تالفة أو منتهية لمورد من دفعة توريد محددة'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupplierReturnScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: const Text('سجل المرتجعات'),
              subtitle: const Text('كل مرتجعات العملاء والموردين بالتاريخ والوقت'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReturnsHistoryScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
