import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/expense.dart';
import '../repository/accounting_repository.dart';
import '../services/accounting_report_pdf_service.dart';
import 'daily_closing_history_screen.dart';
import 'supplier_balances_screen.dart';
import 'rep_balances_screen.dart';
import '../../../core/store_settings/store_settings_repository.dart';
import '../../inventory/repository/supplier_repository.dart';
import '../../reps/repository/rep_repository.dart';
import 'smart_reports_screen.dart';
import 'reminders_screen.dart';
import 'ai_analysis_screen.dart';
import '../../../core/notifications/notification_service.dart';

class AccountingHomeScreen extends StatefulWidget {
  const AccountingHomeScreen({super.key});

  @override
  State<AccountingHomeScreen> createState() => _AccountingHomeScreenState();
}

class _AccountingHomeScreenState extends State<AccountingHomeScreen> {
  final _repository = AccountingRepository();
  final _storeRepository = StoreSettingsRepository();
  final _reportPdfService = AccountingReportPdfService();
  final _supplierRepository = SupplierRepository();
  final _repRepository = RepRepository();

  double _todayRevenue = 0;
  double _todayProfit = 0;
  double _monthRevenue = 0;
  double _monthProfit = 0;
  double _monthExpenses = 0;
  List<Expense> _expenses = [];
  List<Map<String, dynamic>> _cashierRevenue = [];
  double _totalSupplierPayable = 0;
  double _totalRepCustodyValue = 0;
  double _totalRepCashOwed = 0;
  int _dueRemindersCount = 0;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final todayStart = AccountingRepository.startOfToday();
    final monthStart = AccountingRepository.startOfMonth();

    final todayRevenue = await _repository.getRevenue(sinceDate: todayStart);
    final todayProfit = await _repository.getProfit(sinceDate: todayStart);
    final monthRevenue = await _repository.getRevenue(sinceDate: monthStart);
    final monthProfit = await _repository.getProfit(sinceDate: monthStart);
    final monthExpenses = await _repository.getTotalExpenses(sinceDate: monthStart);
    final expenses = await _repository.getExpenses(sinceDate: monthStart);
    final cashierRevenue = await _repository.getRevenueByCashier(sinceDate: monthStart);

    // الأرصدة: مستحق للموردين + بضاعة ومديونية نقدية على المناديب
    final totalSupplierPayable = await _supplierRepository.getTotalPayable();
    final repSummaries = await _repRepository.getAllRepsAccountSummaries();
    final totalRepCustodyValue =
        repSummaries.fold<double>(0, (sum, r) => sum + (r['custody_value'] as double));
    final totalRepCashOwed = repSummaries.fold<double>(0, (sum, r) => sum + (r['cash_owed'] as double));
    final dueInstallments = await _supplierRepository.getDueOrOverdueInstallments(withinDays: 3);
    final repsWithCashOwed = repSummaries.where((r) => (r['cash_owed'] as double) > 0).length;
    final expiringRepDocs = await _repRepository.getExpiringDocuments(withinDays: 30);
    final expiringSupplierDocs = await _supplierRepository.getExpiringDocuments(withinDays: 30);
    final repsMissingDocs = await _repRepository.getRepsMissingCoreDocuments();

    setState(() {
      _todayRevenue = todayRevenue;
      _todayProfit = todayProfit;
      _monthRevenue = monthRevenue;
      _monthProfit = monthProfit;
      _monthExpenses = monthExpenses;
      _expenses = expenses;
      _cashierRevenue = cashierRevenue;
      _totalSupplierPayable = totalSupplierPayable;
      _totalRepCustodyValue = totalRepCustodyValue;
      _totalRepCashOwed = totalRepCashOwed;
      _dueRemindersCount = dueInstallments.length +
          repsWithCashOwed +
          expiringRepDocs.length +
          expiringSupplierDocs.length +
          repsMissingDocs.length;
      _loading = false;
    });

    if (_dueRemindersCount > 0) {
      await NotificationService.instance.showNow(
        id: 1001,
        title: 'عندك $_dueRemindersCount تذكير محتاج انتباه',
        body: 'أقساط موردين مستحقة، مديونيات مناديب، أو مستندات قربت تنتهي - افتح "أدوات ذكية" لمراجعتها.',
      );
    }
  }

  Future<void> _openSmartTools() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('التقارير الذكية (واتساب/إيميل)'),
              subtitle: const Text('إرسال تقرير يومي/أسبوعي/شهري للمدير'),
              onTap: () => Navigator.pop(context, 'reports'),
            ),
            ListTile(
              leading: Badge(
                isLabelVisible: _dueRemindersCount > 0,
                label: Text('$_dueRemindersCount'),
                child: const Icon(Icons.notifications_active_outlined),
              ),
              title: const Text('التذكيرات'),
              subtitle: const Text('أقساط موردين مستحقة + مديونية مناديب'),
              onTap: () => Navigator.pop(context, 'reminders'),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('تحليل ذكي بالـ AI'),
              subtitle: const Text('تحليل أرقام المبيعات والأرباح'),
              onTap: () => Navigator.pop(context, 'ai'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;
    Widget screen = switch (choice) {
      'reports' => const SmartReportsScreen(),
      'reminders' => const RemindersScreen(),
      _ => const AiAnalysisScreen(),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  Future<String?> _pickReceiptImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('التقاط صورة الفاتورة'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 75, maxWidth: 1200);
    return picked?.path;
  }

  Future<void> _addExpense() async {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String? receiptPath;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text('إضافة مصروف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'البيان (مثلاً: إيجار، فاتورة كهرباء)'),
                ),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                if (receiptPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(receiptPath!), height: 120, fit: BoxFit.cover),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final path = await _pickReceiptImage();
                    if (path != null) dialogSetState(() => receiptPath = path);
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(receiptPath == null ? 'تصوير الفاتورة' : 'تغيير الصورة'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final amount = double.tryParse(amountController.text);
    if (descController.text.trim().isEmpty || amount == null) return;

    await _repository.addExpense(Expense(
      description: descController.text.trim(),
      amount: amount,
      date: DateTime.now().toIso8601String(),
      receiptImagePath: receiptPath,
    ));
    _load();
  }

  void _viewReceipt(String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(child: Image.file(File(path))),
      ),
    );
  }

  Future<File> _generateReport() async {
    final storeSettings = await _storeRepository.getSettings();
    return _reportPdfService.generate(
      todayRevenue: _todayRevenue,
      todayProfit: _todayProfit,
      monthRevenue: _monthRevenue,
      monthProfit: _monthProfit,
      monthExpenses: _monthExpenses,
      cashierRevenue: _cashierRevenue,
      expenses: _expenses,
      storeName: storeSettings['store_name'],
    );
  }

  Future<void> _shareReport() async {
    setState(() => _exporting = true);
    try {
      final file = await _generateReport();
      await Share.shareXFiles([XFile(file.path)], text: 'تقرير الحسابات');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _printReport() async {
    setState(() => _exporting = true);
    try {
      final file = await _generateReport();
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveReport() async {
    setState(() => _exporting = true);
    try {
      final file = await _generateReport();
      final documentsDir = await getApplicationDocumentsDirectory();
      final savedPath = '${documentsDir.path}/تقرير_الحسابات_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await file.copy(savedPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اتحفظ التقرير في: $savedPath')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final netThisMonth = _monthProfit - _monthExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحاسبة'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _dueRemindersCount > 0,
              label: Text('$_dueRemindersCount'),
              child: const Icon(Icons.smart_toy_outlined),
            ),
            tooltip: 'أدوات ذكية (تقارير، تذكيرات، AI)',
            onPressed: _openSmartTools,
          ),
          IconButton(
            icon: const Icon(Icons.lock_clock_outlined),
            tooltip: 'إقفال اليومية',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DailyClosingHistoryScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            enabled: !_exporting,
            tooltip: 'تصدير التقرير',
            icon: const Icon(Icons.ios_share_outlined),
            onSelected: (value) {
              if (value == 'share') _shareReport();
              if (value == 'print') _printReport();
              if (value == 'save') _saveReport();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'share', child: Text('مشاركة التقرير')),
              PopupMenuItem(value: 'print', child: Text('طباعة التقرير')),
              PopupMenuItem(value: 'save', child: Text('تنزيل التقرير')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('مصروف جديد'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionCard(
              title: 'اليوم',
              children: [
                _buildRow('إجمالي المبيعات', _todayRevenue),
                _buildRow('صافي الربح التقريبي', _todayProfit, highlight: true),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'الشهر الحالي',
              children: [
                _buildRow('إجمالي المبيعات', _monthRevenue),
                _buildRow('إجمالي الربح من المبيعات', _monthProfit),
                _buildRow('إجمالي المصروفات', _monthExpenses),
                const Divider(),
                _buildRow('صافي الربح بعد المصروفات', netThisMonth, highlight: true),
              ],
            ),
            const SizedBox(height: 16),
            Text('الأرصدة', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: const Text('إجمالي المستحق للموردين'),
                    trailing: Text(
                      '${_totalSupplierPayable.toStringAsFixed(2)} ج',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SupplierBalancesScreen()),
                      );
                      _load();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('إجمالي قيمة البضاعة تحت عهدة المناديب'),
                    trailing: Text(
                      '${_totalRepCustodyValue.toStringAsFixed(2)} ج',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RepBalancesScreen()),
                      );
                      _load();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.money_off),
                    title: const Text('إجمالي المديونية النقدية على المناديب'),
                    trailing: Text(
                      '${_totalRepCashOwed.toStringAsFixed(2)} ج',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RepBalancesScreen()),
                      );
                      _load();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_cashierRevenue.isNotEmpty) ...[
              Text('مبيعات كل كاشير هذا الشهر', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: _cashierRevenue.map((row) {
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(row['cashier_name'] as String),
                      trailing: Text('${(row['total'] as num).toStringAsFixed(2)} ج'),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('المصروفات هذا الشهر', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('لا توجد مصروفات مسجلة هذا الشهر'),
              )
            else
              ..._expenses.map((expense) => ListTile(
                    leading: expense.receiptImagePath != null && File(expense.receiptImagePath!).existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(expense.receiptImagePath!),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.receipt_outlined),
                    title: Text(expense.description),
                    subtitle: Text(expense.date.substring(0, 10)),
                    trailing: Text('${expense.amount.toStringAsFixed(2)} ج'),
                    onTap: expense.receiptImagePath != null
                        ? () => _viewReceipt(expense.receiptImagePath!)
                        : null,
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, double value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
          Text(
            '${value.toStringAsFixed(2)} ج',
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              fontSize: highlight ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
