import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../repository/customer_repository.dart';
import 'customer_form_screen.dart';
import 'customer_profile_screen.dart';
import 'order_catalog_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _repository = CustomerRepository();
  List<Customer> _customers = [];
  double _totalOutstanding = 0;
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final customers = await _repository.getAllCustomers(searchQuery: _searchQuery);
    final total = await _repository.getTotalOutstandingBalance();
    setState(() {
      _customers = customers;
      _totalOutstanding = total;
      _loading = false;
    });
  }

  Future<void> _openForm() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerFormScreen()));
    _load();
  }

  Future<void> _openProfile(Customer customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CustomerProfileScreen(customer: customer)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العملاء'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'كتالوج الطلب',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderCatalogScreen())),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو رقم التليفون',
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
          : Column(
              children: [
                if (_totalOutstanding > 0)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'إجمالي المديونيات القائمة على العملاء: ${_totalOutstanding.toStringAsFixed(2)} ج',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                Expanded(
                  child: _customers.isEmpty
                      ? const Center(child: Text('لا يوجد عملاء مسجلين حتى الآن'))
                      : ListView.builder(
                          itemCount: _customers.length,
                          itemBuilder: (context, index) {
                            final customer = _customers[index];
                            return ListTile(
                              leading: CircleIcon(hasDebt: customer.hasDebt),
                              title: Text(customer.name),
                              subtitle: Text(customer.phone ?? 'بدون رقم تليفون'),
                              trailing: customer.balance != 0
                                  ? Text(
                                      '${customer.balance.toStringAsFixed(2)} ج',
                                      style: TextStyle(
                                        color: customer.hasDebt ? Colors.deepOrange : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                              onTap: () => _openProfile(customer),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        child: const Icon(Icons.person_add_alt_1_outlined),
      ),
    );
  }
}

class CircleIcon extends StatelessWidget {
  final bool hasDebt;
  const CircleIcon({super.key, required this.hasDebt});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: hasDebt ? Colors.orange.shade100 : Colors.grey.shade200,
      child: Icon(Icons.person_outline, color: hasDebt ? Colors.deepOrange : Colors.grey.shade700),
    );
  }
}
