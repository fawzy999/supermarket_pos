import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../repository/purchase_order_repository.dart';
import '../services/purchase_order_pdf_service.dart';
import '../../../core/store_settings/store_settings_repository.dart';
import '../../../core/settings/app_settings_repository.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/services/email_service.dart';

/// عرض طلب توريد بعد إنشائه: نفس شكل الفاتورة - مشاركة (واتساب مع
/// الملف مرفق فعليًا من قائمة المشاركة)، طباعة، تنزيل، أو إرسال مباشر
/// بالإيميل لو بيانات SMTP والمورد متوفرة.
class PurchaseOrderViewScreen extends StatefulWidget {
  final int orderId;

  const PurchaseOrderViewScreen({super.key, required this.orderId});

  @override
  State<PurchaseOrderViewScreen> createState() => _PurchaseOrderViewScreenState();
}

class _PurchaseOrderViewScreenState extends State<PurchaseOrderViewScreen> {
  final _repository = PurchaseOrderRepository();
  final _storeRepository = StoreSettingsRepository();
  final _appSettingsRepository = AppSettingsRepository();
  final _pdfService = PurchaseOrderPdfService();
  final _emailService = EmailService();

  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  Map<String, String?> _storeSettings = {};
  String? _managerName;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order = await _repository.getOrderById(widget.orderId);
    final items = await _repository.getItemsForOrder(widget.orderId);
    final storeSettings = await _storeRepository.getSettings();
    final managerName = await _appSettingsRepository.get(AppSettingsRepository.keyManagerName);
    setState(() {
      _order = order;
      _items = items;
      _storeSettings = storeSettings;
      _managerName = managerName;
      _loading = false;
    });
  }

  Future<File> _generatePdf() {
    return _pdfService.generate(
      order: _order!,
      items: _items,
      storeSettings: _storeSettings,
      managerName: _managerName,
    );
  }

  Future<void> _shareOrder() async {
    setState(() => _busy = true);
    try {
      final file = await _generatePdf();
      await Share.shareXFiles([XFile(file.path)], text: 'طلب توريد رقم #${_order!['id']}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printOrder() async {
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

  Future<void> _saveOrder() async {
    setState(() => _busy = true);
    try {
      final file = await _generatePdf();
      final documentsDir = await getApplicationDocumentsDirectory();
      final savedPath = '${documentsDir.path}/طلب_توريد_${_order!['id']}.pdf';
      await file.copy(savedPath);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اتحفظ في: $savedPath')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emailOrder() async {
    final supplierEmail = _order!['supplier_email'] as String?;
    if (supplierEmail == null || supplierEmail.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد إيميل مسجل لهذا المورد')));
      return;
    }
    final smtpSettings = await _appSettingsRepository.getAll([
      AppSettingsRepository.keySmtpHost,
      AppSettingsRepository.keySmtpPort,
      AppSettingsRepository.keySmtpUsername,
      AppSettingsRepository.keySmtpPassword,
    ]);
    final host = smtpSettings[AppSettingsRepository.keySmtpHost];
    final port = int.tryParse(smtpSettings[AppSettingsRepository.keySmtpPort] ?? '');
    final username = smtpSettings[AppSettingsRepository.keySmtpUsername];
    final password = smtpSettings[AppSettingsRepository.keySmtpPassword];
    if (host == null || port == null || username == null || password == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لازم تظبط بيانات الإيميل (SMTP) الأول من "التقارير الذكية" > الإعدادات')),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final file = await _generatePdf();
      await _emailService.send(
        host: host,
        port: port,
        username: username,
        password: password,
        to: supplierEmail,
        subject: 'طلب توريد رقم #${_order!['id']}',
        body: 'مرفق طلب توريد رقم #${_order!['id']} - برجاء تأكيد الطلب والموعد المتوقع للتوريد.',
        attachment: file,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اتبعت الإيميل بنجاح')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ في الإرسال: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_order == null) {
      return const Scaffold(body: Center(child: Text('الطلب غير موجود')));
    }

    final order = _order!;
    final storeName = _storeSettings['store_name'];
    final storeAddress = _storeSettings['store_address'];
    final storePhone = _storeSettings['store_phone'];
    final storeLogoPath = _storeSettings['store_logo_path'];
    final totalAmount = (order['total_amount'] as num).toDouble();

    return Scaffold(
      appBar: AppBar(title: Text('طلب توريد #${order['id']}')),
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
                        if (storeLogoPath != null && File(storeLogoPath).existsSync())
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
                  Text('طلب توريد رقم: #${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('التاريخ: ${(order['date'] as String).substring(0, 16).replaceFirst('T', ' ')}'),
                  if (_managerName != null && _managerName!.trim().isNotEmpty)
                    Text('المدير المسؤول: $_managerName'),
                  const Divider(height: 24),
                  const Text('بيانات المورد', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('الاسم: ${order['supplier_name'] ?? '-'}'),
                  if ((order['supplier_phone'] as String?)?.trim().isNotEmpty ?? false)
                    Text('التليفون: ${order['supplier_phone']}'),
                  if ((order['supplier_email'] as String?)?.trim().isNotEmpty ?? false)
                    Text('الإيميل: ${order['supplier_email']}'),
                  if ((order['supplier_address'] as String?)?.trim().isNotEmpty ?? false)
                    Text('العنوان: ${order['supplier_address']}'),
                  const Divider(height: 32),
                  // ترتيب الأعمدة معكوس عمدًا (الإجمالي أول عنصر في القايمة، الصنف
                  // آخر عنصر) عشان الجدول ده مش داخل سياق RTL حقيقي، فالعمود
                  // الأول في القايمة بيظهر فعليًا في أقصى يسار الشاشة - وعلى
                  // كده "الصنف" (آخر عنصر) بيظهر في أقصى يمين الشاشة كما طلب أحمد
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.5),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1.2),
                      3: FlexColumnWidth(1.2),
                      4: FlexColumnWidth(3),
                    },
                    children: [
                      const TableRow(children: [
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('إجمالي', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('سعر', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('كمية', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('الوحدة', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('الصنف', style: TextStyle(fontWeight: FontWeight.bold))),
                      ]),
                      for (final item in _items)
                        TableRow(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text((((item['quantity'] as num) * (item['unit_price'] as num))).toStringAsFixed(2)),
                          ),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text((item['unit_price'] as num).toStringAsFixed(2))),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(formatQuantity(item['quantity'] as num))),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text((item['unit'] as String?) ?? '-')),
                          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(item['item_name'] as String)),
                        ]),
                    ],
                  ),
                  const Divider(height: 32),
                  if ((order['notes'] as String?)?.trim().isNotEmpty ?? false) ...[
                    Text('ملاحظات: ${order['notes']}'),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'الإجمالي: ${totalAmount.toStringAsFixed(2)} ج',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _saveOrder,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('حفظ'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _printOrder,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('طباعة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _shareOrder,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('مشاركة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _emailOrder,
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('إرسال بالإيميل للمورد'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
