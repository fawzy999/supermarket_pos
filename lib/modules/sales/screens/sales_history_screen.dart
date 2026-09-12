import 'package:flutter/material.dart';
import '../models/sale.dart';
import '../repository/sales_repository.dart';
import 'invoice_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _repository = SalesRepository();
  List<Sale> _sales = [];
  double _todayTotal = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sales = await _repository.getSalesHistory();
    final todayTotal = await _repository.getTodayTotal();
    setState(() {
      _sales = sales;
      _todayTotal = todayTotal;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل المبيعات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'إجمالي مبيعات اليوم: ${_todayTotal.toStringAsFixed(2)} ج',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _sales.isEmpty
                      ? const Center(child: Text('لا توجد فواتير حتى الآن'))
                      : ListView.builder(
                          itemCount: _sales.length,
                          itemBuilder: (context, index) {
                            final sale = _sales[index];
                            final paymentLabel = switch (sale.paymentMethod) {
                              'cash' => 'كاش',
                              'card' => 'فيزا/بطاقة',
                              'credit' => 'حساب عميل',
                              'rep_account' => 'حساب مندوب',
                              _ => 'فيزا/بطاقة',
                            };
                            return ListTile(
                              leading: const Icon(Icons.receipt_long),
                              title: Text('فاتورة #${sale.id}'),
                              subtitle: Text('${sale.date.substring(0, 16)}  •  $paymentLabel'),
                              trailing: Text(
                                '${sale.totalAmount.toStringAsFixed(2)} ج',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InvoiceScreen(saleId: sale.id!),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
