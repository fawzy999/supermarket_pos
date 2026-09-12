import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/supplier.dart';
import '../models/supplier_contact.dart';
import '../repository/supplier_repository.dart';
import '../services/supplier_pdf_service.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/document_preview.dart';
import 'supplier_form_screen.dart';
import 'supplier_documents_screen.dart';
import 'supplier_account_screen.dart';
import 'supplier_contracts_screen.dart';
import 'purchase_order_form_screen.dart';
import 'purchase_order_list_screen.dart';

class SupplierProfileScreen extends StatefulWidget {
  final Supplier supplier;

  const SupplierProfileScreen({super.key, required this.supplier});

  @override
  State<SupplierProfileScreen> createState() => _SupplierProfileScreenState();
}

class _SupplierProfileScreenState extends State<SupplierProfileScreen> {
  final _repository = SupplierRepository();
  final _pdfService = SupplierPdfService();

  late Supplier _supplier;
  List<Map<String, dynamic>> _batches = [];
  List<SupplierContact> _contacts = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final refreshed = await _repository.getSupplierById(_supplier.id!);
    final batches = await _repository.getBatchesForSupplier(_supplier.id!);
    final contacts = await _repository.getContactsForSupplier(_supplier.id!);
    setState(() {
      _supplier = refreshed ?? _supplier;
      _batches = batches;
      _contacts = contacts;
      _loading = false;
    });
  }

  void _viewImage(String path) => openDocumentFile(context, path);

  Future<void> _openDocuments() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplierDocumentsScreen(supplier: _supplier)),
    );
  }

  Future<void> _openAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplierAccountScreen(supplier: _supplier)),
    );
    _load();
  }

  Future<void> _openContracts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplierContractsScreen(supplier: _supplier)),
    );
    _load();
  }

  Future<void> _openWhatsApp() async {
    final phone = _supplier.phone;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد رقم تليفون مسجل لهذا المورد')));
      return;
    }
    final text = 'مرحبًا ${_supplier.companyName}،';
    final opened = await WhatsAppHelper.openChat(phone: phone, text: text);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مقدرناش نفتح واتساب - تأكد إنه متثبت')));
    }
  }

  Future<void> _newPurchaseOrder() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PurchaseOrderFormScreen(supplier: _supplier)),
    );
  }

  Future<void> _openPurchaseOrders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PurchaseOrderListScreen(supplier: _supplier)),
    );
  }

  Future<void> _editSupplier() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplierFormScreen(supplier: _supplier)),
    );
    _load();
  }

  Future<void> _addOrEditContact({SupplierContact? contact}) async {
    final nameController = TextEditingController(text: contact?.name ?? '');
    final roleController = TextEditingController(text: contact?.role ?? '');
    final phoneController = TextEditingController(text: contact?.phone ?? '');
    final emailController = TextEditingController(text: contact?.email ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(contact == null ? 'إضافة شخص تواصل' : 'تعديل بيانات شخص'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                ),
                TextFormField(
                  controller: roleController,
                  decoration: const InputDecoration(labelText: 'الوظيفة (مندوب، محاسب...)'),
                ),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'التليفون'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'الإيميل'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newContact = SupplierContact(
      id: contact?.id,
      supplierId: _supplier.id!,
      name: nameController.text.trim(),
      role: roleController.text.trim().isEmpty ? null : roleController.text.trim(),
      phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
      email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
    );

    if (contact == null) {
      await _repository.addContact(newContact);
    } else {
      await _repository.updateContact(newContact);
    }
    _load();
  }

  Future<void> _deleteContact(SupplierContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف شخص التواصل'),
        content: Text('هل تريد حذف "${contact.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteContact(contact.id!);
    _load();
  }

  Future<File> _generatePdf() {
    return _pdfService.generate(
      supplier: _supplier,
      contacts: _contacts,
      recentBatches: _batches.take(20).toList(),
    );
  }

  Future<void> _shareSupplierSheet() async {
    setState(() => _busy = true);
    try {
      final file = await _generatePdf();
      await Share.shareXFiles([XFile(file.path)], text: 'بيانات المورد: ${_supplier.companyName}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printSupplierSheet() async {
    setState(() => _busy = true);
    try {
      final file = await _generatePdf();
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSupplierSheet() async {
    setState(() => _busy = true);
    try {
      final file = await _generatePdf();
      final documentsDir = await getApplicationDocumentsDirectory();
      final safeName = _supplier.companyName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
      final savedPath = '${documentsDir.path}/مورد_$safeName.pdf';
      await file.copy(savedPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اتحفظت في: $savedPath')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplier = _supplier;

    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.companyName),
        actions: [
          IconButton(icon: const Icon(Icons.chat_outlined), tooltip: 'فتح واتساب', onPressed: _openWhatsApp),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editSupplier),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (supplier.logoPath != null && File(supplier.logoPath!).existsSync())
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(supplier.logoPath!), width: 72, height: 72, fit: BoxFit.cover),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((supplier.contactPerson ?? '').isNotEmpty)
                                Text('المسؤول الرئيسي: ${supplier.contactPerson}'),
                              if ((supplier.phone ?? '').isNotEmpty) Text('التليفون: ${supplier.phone}'),
                              if ((supplier.email ?? '').isNotEmpty) Text('الإيميل: ${supplier.email}'),
                              if ((supplier.address ?? '').isNotEmpty) Text('العنوان: ${supplier.address}'),
                              if ((supplier.notes ?? '').isNotEmpty) Text('ملاحظات: ${supplier.notes}'),
                              const SizedBox(height: 8),
                              if (supplier.balance != 0)
                                Chip(
                                  label: Text(
                                    'مستحق للمورد: ${supplier.balance.toStringAsFixed(2)} ج',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: Colors.orange.shade100,
                                )
                              else
                                const Chip(label: Text('لا يوجد رصيد مستحق حاليًا')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // زرارات المستندات والحساب والعقود
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openDocuments,
                          icon: const Icon(Icons.folder_outlined),
                          label: const Text('المستندات'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openAccount,
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          label: const Text('الحساب'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openContracts,
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('العقود'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _newPurchaseOrder,
                          icon: const Icon(Icons.shopping_cart_outlined),
                          label: const Text('طلب توريد جديد'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openPurchaseOrders,
                          icon: const Icon(Icons.list_alt_outlined),
                          label: const Text('طلبات سابقة'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // شريط التصدير: مشاركة / طباعة / تنزيل - زي شاشة الفاتورة بالظبط
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _shareSupplierSheet,
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('مشاركة'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _printSupplierSheet,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('طباعة'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _saveSupplierSheet,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('تنزيل'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('أشخاص التواصل', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      TextButton.icon(
                        onPressed: () => _addOrEditContact(),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('إضافة'),
                      ),
                    ],
                  ),
                ),
                if (_contacts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('لا يوجد أشخاص تواصل مسجلين لهذا المورد'),
                  )
                else
                  ..._contacts.map((contact) => ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(contact.name),
                        subtitle: Text(
                          [
                            if (contact.role != null) contact.role,
                            if (contact.phone != null) contact.phone,
                            if (contact.email != null) contact.email,
                          ].join('  •  '),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _addOrEditContact(contact: contact);
                            if (value == 'delete') _deleteContact(contact);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('تعديل')),
                            PopupMenuItem(value: 'delete', child: Text('حذف')),
                          ],
                        ),
                      )),

                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('سجل التوريدات', style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                if (_batches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لا توجد توريدات مسجلة من المورد ده حتى الآن'),
                  )
                else
                  ..._batches.map((batch) {
                    final invoicePath = batch['invoice_image_path'] as String?;
                    final receiptPath = batch['receipt_image_path'] as String?;
                    return ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(batch['product_name'] as String),
                      subtitle: Text(
                        'الكمية: ${formatQuantity(batch['quantity_received'] as num)}'
                        '  •  تاريخ التوريد: ${(batch['supply_date'] as String).substring(0, 10)}'
                        '${batch['expiry_date'] != null ? '\nالصلاحية: ${(batch['expiry_date'] as String).substring(0, 10)}' : ''}',
                      ),
                      isThreeLine: batch['expiry_date'] != null,
                      trailing: (invoicePath != null || receiptPath != null)
                          ? Wrap(
                              spacing: 4,
                              children: [
                                if (invoicePath != null)
                                  IconButton(
                                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                                    tooltip: 'صورة الفاتورة',
                                    onPressed: () => _viewImage(invoicePath),
                                  ),
                                if (receiptPath != null)
                                  IconButton(
                                    icon: const Icon(Icons.inventory_outlined, size: 20),
                                    tooltip: 'صورة الاستلام',
                                    onPressed: () => _viewImage(receiptPath),
                                  ),
                              ],
                            )
                          : null,
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
