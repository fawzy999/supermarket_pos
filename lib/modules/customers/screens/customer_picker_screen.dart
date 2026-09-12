import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../repository/customer_repository.dart';

/// شاشة اختيار عميل مسجّل (تُستخدم في البيع الآجل وفي مرتجعات العملاء).
/// بترجع الـ Customer المختار، أو تسمح بإضافة عميل جديد سريعًا لو مش موجود.
class CustomerPickerScreen extends StatefulWidget {
  const CustomerPickerScreen({super.key});

  @override
  State<CustomerPickerScreen> createState() => _CustomerPickerScreenState();
}

class _CustomerPickerScreenState extends State<CustomerPickerScreen> {
  final _repository = CustomerRepository();
  List<Customer> _customers = [];
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
    setState(() {
      _customers = customers;
      _loading = false;
    });
  }

  Future<void> _quickAdd() async {
    final nameController = TextEditingController(text: _searchQuery);
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عميل جديد'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم العميل'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'رقم التليفون'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final id = await _repository.addCustomer(Customer(
      name: nameController.text.trim(),
      phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    ));

    if (mounted) {
      Navigator.pop(
        context,
        Customer(id: id, name: nameController.text.trim(), createdAt: DateTime.now().toIso8601String()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختيار عميل'),
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
          : _customers.isEmpty
              ? const Center(child: Text('مفيش عملاء مطابقين - تقدر تضيف عميل جديد'))
              : ListView.builder(
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final customer = _customers[index];
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(customer.name),
                      subtitle: Text(customer.phone ?? ''),
                      trailing: customer.balance > 0
                          ? Text('${customer.balance.toStringAsFixed(2)} ج',
                              style: const TextStyle(color: Colors.deepOrange))
                          : null,
                      onTap: () => Navigator.pop(context, customer),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _quickAdd,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('عميل جديد'),
      ),
    );
  }
}
