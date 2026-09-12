import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sale.dart';
import '../repository/sales_repository.dart';
import '../services/invoice_pdf_service.dart';
import '../../../core/store_settings/store_settings_repository.dart';
import '../../../core/utils/format_utils.dart';

class InvoiceScreen extends StatefulWidget {
  final int saleId;

  const InvoiceScreen({super.key, required this.saleId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _salesRepository = SalesRepository();
  final _storeRepository = StoreSettingsRepository();
  final _pdfService = InvoicePdfService();

  Sale? _sale;
  List<Map<String, dynamic>> _items = [];
  Map<String, String?> _storeSettings = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sale = await _salesRepository.getSaleById(widget.saleId);
    final items = await _salesRepository.getSaleItems(widget.saleId);
    final storeSettings = await _storeRepository.getSettings();
    setState(() {
      _sale = sale;
      _items = items;
      _storeSettings = storeSettings;
      _loading = false;
    });
  }

  Future<File> _generatePdf() {
    return _pdfService.generate(sale: _sale!, items: _items, storeSettings: _storeSettings);
  }

  /// فتح قائمة المشاركة العادية في الموبايل - هتظهر فيها واتساب وأي تطبيق تاني مثبت
  Future<void> _shareInvoice() async {
    setState(() => _busy = true);
    try {
      final file = await _generatePdf();
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'فاتورة رقم #${_sale!.id}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// فتح شاشة الطباعة الرسمية (لو فيه طابعة متصلة بالموبايل عبر Bluetooth/WiFi)
  Future<void> _printInvoice() async {
    setState(() => _busy = true);
    try {
      final file = await _generatePdf();
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// حفظ نسخة دائمة من الملف في مساحة تخزين التطبيق (تفضل موجودة بعد إغلاق التطبيق)
  Future<void> _saveInvoice() async {
    setState(() => _busy = true);
    try {
      final file = await _generatePdf();
      final documentsDir = await getApplicationDocumentsDirectory();
      final savedPath = '${documentsDir.path}/فاتورة_${_sale!.id}.pdf';
      await file.copy(savedPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('اتحفظت الفاتورة في: $savedPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_sale == null) {
      return const Scaffold(body: Center(child: Text('الفاتورة غير موجودة')));
    }

    final sale = _sale!;
    final storeName = _storeSettings['store_name'];
    final storePhone = _storeSettings['store_phone'];
    final storeAddress = _storeSettings['store_address'];
    final storeLogoPath = _storeSettings['store_logo_path'];
    final paymentLabel = switch (sale.paymentMethod) {
      'cash' => 'كاش',
      'card' => 'فيزا/بطاقة',
      'credit' => 'حساب عميل',
      'rep_account' => 'حساب مندوب',
      _ => 'فيزا/بطاقة',
    };

    return Scaffold(
      appBar: AppBar(title: Text('فاتورة #${sale.id}')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        if (storeLogoPath != null)
                          CircleAvatar(radius: 36, backgroundImage: FileImage(File(storeLogoPath))),
                        const SizedBox(height: 8),
                        Text(
                          (storeName != null && storeName.trim().isNotEmpty) ? storeName : 'المحل',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (storeAddress != null && storeAddress.trim().isNotEmpty)
                          Text(storeAddress, style: const TextStyle(color: Colors.grey)),
                        if (storePhone != null && storePhone.trim().isNotEmpty)
                          Text(storePhone, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Divider(height: 32),
                  Text('فاتورة رقم: #${sale.id}'),
                  Text('التاريخ: ${sale.date.substring(0, 16).replaceFirst('T', ' ')}'),
                  Text('طريقة الدفع: $paymentLabel'),
                  if (sale.customerName != null && sale.customerName!.trim().isNotEmpty)
                    Text('العميل: ${sale.customerName}'),
                  if (sale.customerPhone != null && sale.customerPhone!.trim().isNotEmpty)
                    Text('تليفون العميل: ${sale.customerPhone}'),
                  const Divider(height: 32),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.5),
                    },
                    children: [
                      const TableRow(children: [
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('الصنف', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('كمية', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('سعر', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('إجمالي', style: TextStyle(fontWeight: FontWeight.bold))),
                      ]),
                      for (final item in _items)
                        TableRow(children: [
                          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(item['product_name'] as String? ?? '-')),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(formatQuantity(item['quantity'] as num))),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text((item['unit_price'] as num).toStringAsFixed(2))),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text((((item['quantity'] as num) * (item['unit_price'] as num))).toStringAsFixed(2)),
                          ),
                        ]),
                    ],
                  ),
                  const Divider(height: 32),
                  if (sale.discountPercent > 0) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('الإجمالي قبل الخصم: ${sale.subtotalAmount.toStringAsFixed(2)} ج'),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'الخصم (${formatQuantity(sale.discountPercent)}%): ${sale.discountAmount.toStringAsFixed(2)} ج',
                        style: const TextStyle(color: Colors.deepOrange),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'الإجمالي: ${sale.totalAmount.toStringAsFixed(2)} ج',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(child: Text('شكرًا لتعاملكم معنا', style: TextStyle(color: Colors.grey))),
                ],
              ),
            ),
          ),
          if (_busy)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _saveInvoice,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('حفظ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _printInvoice,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('طباعة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _shareInvoice,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('مشاركة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
