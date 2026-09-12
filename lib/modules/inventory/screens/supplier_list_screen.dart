import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/supplier.dart';
import '../repository/supplier_repository.dart';
import '../services/supplier_pdf_service.dart';
import 'supplier_form_screen.dart';
import 'supplier_profile_screen.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _repository = SupplierRepository();
  final _pdfService = SupplierPdfService();
  List<Supplier> _suppliers = [];
  bool _loading = true;
  bool _exporting = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final suppliers = await _repository.getAllSuppliers(searchQuery: _searchQuery);
    setState(() {
      _suppliers = suppliers;
      _loading = false;
    });
  }

  Future<void> _addSupplier() async {
    final newSupplier = await Navigator.push<Supplier>(
      context,
      MaterialPageRoute(builder: (_) => const SupplierFormScreen()),
    );
    // بعد ما يتحفظ المورد الجديد، ندخل بروفايله على طول عشان يقدر يضيف
    // مستنداته وباقي بياناته من غير ما يدور عليه في القائمة
    if (newSupplier != null && mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierProfileScreen(supplier: newSupplier)));
    }
    _load();
  }

  Future<void> _exportList(String action) async {
    if (_suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد موردين لتصديرهم')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final file = await _pdfService.generateList(_suppliers);
      switch (action) {
        case 'share':
          await Share.shareXFiles([XFile(file.path)], text: 'قائمة الموردين');
          break;
        case 'print':
          final bytes = await file.readAsBytes();
          await Printing.layoutPdf(onLayout: (_) async => bytes);
          break;
        case 'save':
          final documentsDir = await getApplicationDocumentsDirectory();
          final savedPath = '${documentsDir.path}/قائمة_الموردين.pdf';
          await file.copy(savedPath);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اتحفظت في: $savedPath')));
          }
          break;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموردين'),
        actions: [
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.ios_share_outlined),
                  tooltip: 'تصدير قائمة الموردين',
                  onSelected: _exportList,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'share', child: Text('مشاركة القائمة')),
                    PopupMenuItem(value: 'print', child: Text('طباعة القائمة')),
                    PopupMenuItem(value: 'save', child: Text('تنزيل / حفظ في الجهاز')),
                  ],
                ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو التليفون أو الإيميل',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSupplier,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('مورد جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? const Center(child: Text('لا يوجد موردين مسجلين حتى الآن'))
              : ListView.builder(
                  itemCount: _suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = _suppliers[index];
                    return ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(supplier.companyName),
                      subtitle: Text('${supplier.contactPerson ?? ''}  •  ${supplier.phone ?? ''}'),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SupplierProfileScreen(supplier: supplier)),
                        );
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}
