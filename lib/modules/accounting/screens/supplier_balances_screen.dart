import 'package:flutter/material.dart';
import '../../inventory/models/supplier.dart';
import '../../inventory/repository/supplier_repository.dart';
import '../../inventory/screens/supplier_account_screen.dart';

/// كل الموردين اللي ليهم رصيد مستحق (سواء موجب - محل مديون بيه - أو أي
/// رصيد تاني)، مرتبين من الأكبر للأصغر، مع رابط مباشر لحساب كل مورد.
class SupplierBalancesScreen extends StatefulWidget {
  const SupplierBalancesScreen({super.key});

  @override
  State<SupplierBalancesScreen> createState() => _SupplierBalancesScreenState();
}

class _SupplierBalancesScreenState extends State<SupplierBalancesScreen> {
  final _repository = SupplierRepository();
  List<Supplier> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final suppliers = await _repository.getSuppliersWithBalance();
    setState(() {
      _suppliers = suppliers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _suppliers.fold<double>(0, (sum, s) => sum + (s.balance > 0 ? s.balance : 0));

    return Scaffold(
      appBar: AppBar(title: const Text('أرصدة الموردين')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إجمالي المستحق لكل الموردين'),
                          const SizedBox(height: 4),
                          Text('${total.toStringAsFixed(2)} ج',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  if (_suppliers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لا يوجد أي رصيد مستحق لأي مورد حاليًا'),
                    )
                  else
                    ..._suppliers.map((supplier) => ListTile(
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: Text(supplier.companyName),
                          trailing: Text(
                            '${supplier.balance.toStringAsFixed(2)} ج',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: supplier.balance > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SupplierAccountScreen(supplier: supplier)),
                            );
                            _load();
                          },
                        )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
