import 'dart:io';
import 'package:flutter/material.dart';
import 'core/modules_registry/module_registry.dart';
import 'core/modules_registry/module_repository.dart';
import 'core/modules_registry/module_definition.dart';
import 'core/store_settings/store_settings_repository.dart';
import 'core/store_settings/store_settings_screen.dart';
import 'core/auth/screens/login_screen.dart';
import 'core/auth/screens/user_management_screen.dart';
import 'core/auth/session/current_session.dart';
import 'core/auth/repository/shift_repository.dart';
import 'core/auth/repository/closing_cycle_repository.dart';
import 'core/auth/screens/shift_history_screen.dart';
import 'core/auth/screens/cash_pickup_screen.dart';
import 'core/auth/screens/handover_receive_screen.dart';
import 'modules/accounting/repository/daily_closing_repository.dart';
import 'core/backup/backup_screen.dart';
import 'core/admin/repository/permission_repository.dart';
import 'core/admin/screens/admin_dashboard_screen.dart';
import 'core/licensing/screens/license_gate.dart';

class SupermarketPosApp extends StatelessWidget {
  const SupermarketPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سوبر ماركت Codex',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'Cairo',
      ),
      home: const LicenseGate(),
    );
  }
}

/// الشاشة الرئيسية: بتعرض اسم/لوجو المحل + الموديولات المرخّصة والمفعّلة
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with WidgetsBindingObserver {
  final _moduleRepository = ModuleRepository();
  final _storeRepository = StoreSettingsRepository();
  final _permissionRepository = PermissionRepository();
  final _shiftRepository = ShiftRepository();
  final _closingCycleRepository = ClosingCycleRepository();
  List<ModuleDefinition> _availableModules = [];
  String? _storeName;
  String? _storeLogoPath;
  bool _loading = true;
  bool _canCollectCash = false;
  bool _closingOverdue = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// بيسجل حدث فتح/قفل التطبيق في سجل الوردية الحالية (معلوماتي بس - مالوش
  /// أي تأثير على إقفال الوردية نفسها)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = CurrentSession.instance;
    if (!session.isLoggedIn) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _shiftRepository.logAppEvent(event: 'close', shiftId: session.shiftId, userId: session.user?.id);
    } else if (state == AppLifecycleState.resumed) {
      _shiftRepository.logAppEvent(event: 'open', shiftId: session.shiftId, userId: session.user?.id);
      _checkClosingCycle();
    }
  }

  Future<void> _loadAll() async {
    // إقفال أي أيام سابقة لسه مفتوحة - بيحقق فكرة "إقفال اليومية" تلقائيًا
    await DailyClosingRepository().autoCloseUnclosedPastDays();

    final activeModules = await _moduleRepository.getActiveModules(ModuleRegistry.all);
    final session = CurrentSession.instance;
    final modules = await _permissionRepository.filterModulesForUser(
      userId: session.user?.id ?? -1,
      isAdmin: session.isAdmin,
      activeModules: activeModules,
    );
    final canCollectCash = await _permissionRepository.canCollectCash(
      userId: session.user?.id ?? -1,
      isAdmin: session.isAdmin,
    );
    final storeSettings = await _storeRepository.getSettings();
    final overdue = await _closingCycleRepository.isOverdue();
    setState(() {
      _availableModules = modules;
      _storeName = storeSettings['store_name'];
      _storeLogoPath = storeSettings['store_logo_path'];
      _canCollectCash = canCollectCash;
      _closingOverdue = overdue;
      _loading = false;
    });
  }

  Future<void> _checkClosingCycle() async {
    final overdue = await _closingCycleRepository.isOverdue();
    if (mounted) setState(() => _closingOverdue = overdue);
  }

  /// دورة الإقفال الإجباري وصلت - لازم تسليم/استلام الحسابات دلوقتي قبل ما
  /// يقدر أي حد يكمّل. المستلم ممكن يكون أي حد (نفس المستخدم الحالي، أو حد
  /// تاني هيسجل دخول بعد كده) - المهم إن الوردية تتقفل والحسابات تتأكد.
  Future<void> _goToMandatoryHandover() async {
    final session = CurrentSession.instance;
    final shiftId = session.shiftId;
    final user = session.user;
    if (shiftId == null || user == null) return;

    final shift = await _shiftRepository.getShift(shiftId);
    if (shift == null || !mounted) return;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HandoverReceiveScreen(
          newUser: user,
          openShift: shift,
          previousUserName: user.name,
          isMandatoryCycle: true,
        ),
      ),
    );
  }

  /// "إغلاق الوردية": تسليم عهدة فعلي - بيعرض ملخص الوردية ولازم تأكيد
  /// التسليم، وبعدها الوردية بتتقفل رسميًا (logout_time بيتسجل)
  Future<void> _closeShift() async {
    final session = CurrentSession.instance;
    final shiftId = session.shiftId;
    final userId = session.user?.id;
    final loginTime = session.shiftLoginTime;

    if (shiftId != null && userId != null && loginTime != null) {
      final summary = await _shiftRepository.getShiftSummary(userId, loginTime, null);

      if (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('ملخص الوردية - تسليم العهدة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('عدد الفواتير: ${summary['invoice_count']}'),
                const SizedBox(height: 8),
                Text('إجمالي الكاش: ${(summary['cash_total'] as double).toStringAsFixed(2)} ج',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('إجمالي الفيزا/البطاقة: ${(summary['card_total'] as double).toStringAsFixed(2)} ج'),
                const Divider(),
                Text('الإجمالي الكلي: ${(summary['total'] as double).toStringAsFixed(2)} ج',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تم التسليم، إغلاق الوردية'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      await _shiftRepository.endShift(
        shiftId,
        invoiceCount: summary['invoice_count'] as int,
        cashTotal: summary['cash_total'] as double,
        cardTotal: summary['card_total'] as double,
        totalAmount: summary['total'] as double,
      );
      await _shiftRepository.logAppEvent(event: 'close', shiftId: shiftId, userId: userId);
    }

    session.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  /// "خروج من التطبيق": قفل سريع بس - مش بيلمس الوردية خالص، تفضل مفتوحة
  /// بكل حساباتها. أول حد يدخل بعده (لو مستخدم مختلف) هيتحول تلقائيًا
  /// لشاشة استلام العهدة الإجبارية قبل ما يقدر يشتغل.
  Future<void> _exitAppOnly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خروج من التطبيق'),
        content: const Text(
          'ده هيقفل التطبيق بس من غير إغلاق الوردية - الوردية والحسابات هتفضل زي ما هي، '
          'ولو دخلت بنفس اليوزر تاني هتكمّل نفسها. لو دخل مستخدم مختلف هيتطلب منه تأكيد استلام العهدة الأول.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('خروج من التطبيق')),
        ],
      ),
    );
    if (confirmed != true) return;

    final session = CurrentSession.instance;
    await _shiftRepository.logAppEvent(event: 'close', shiftId: session.shiftId, userId: session.user?.id);
    session.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasStoreName = _storeName != null && _storeName!.trim().isNotEmpty;
    final isAdmin = CurrentSession.instance.isAdmin;
    // الإقفال الإجباري بيطبّق على أي حد (حتى الأدمن) - المستلم ممكن يكون أي
    // حد، المهم إن الحسابات تتقفل كل دورة
    final showLockScreen = _closingOverdue;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black,
            backgroundImage: (_storeLogoPath != null)
                ? FileImage(File(_storeLogoPath!))
                : const AssetImage('assets/branding/codex_logo.png') as ImageProvider,
          ),
        ),
        title: Text(hasStoreName ? _storeName! : 'سوبر ماركت Codex'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.dashboard_customize_outlined),
              tooltip: 'لوحة التحكم الإدارية',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                );
                _loadAll();
              },
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'إدارة المستخدمين',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                );
              },
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.schedule_outlined),
              tooltip: 'سجل الورديات',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShiftHistoryScreen()),
                );
              },
            ),
          if (_canCollectCash)
            IconButton(
              icon: const Icon(Icons.point_of_sale_outlined),
              tooltip: 'استلام نقدية من الخزنة',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CashPickupScreen()),
                );
                _loadAll();
              },
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.backup_outlined),
              tooltip: 'النسخ الاحتياطي',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BackupScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'إعدادات المحل',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreSettingsScreen()),
              );
              _loadAll();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.logout),
            tooltip: 'خروج',
            onSelected: (value) {
              if (value == 'close_shift') _closeShift();
              if (value == 'exit_app') _exitAppOnly();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'close_shift',
                child: ListTile(
                  leading: Icon(Icons.point_of_sale_outlined),
                  title: Text('إغلاق الوردية'),
                  subtitle: Text('تسليم عهدة كامل'),
                ),
              ),
              PopupMenuItem(
                value: 'exit_app',
                child: ListTile(
                  leading: Icon(Icons.exit_to_app),
                  title: Text('خروج من التطبيق فقط'),
                  subtitle: Text('من غير إغلاق الوردية'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: showLockScreen
          ? _buildLockScreen()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'مسجل دخول: ${CurrentSession.instance.user?.name ?? ''}'
                    '  (${CurrentSession.instance.isAdmin ? 'أدمن' : 'كاشير'})',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: _availableModules.isEmpty
                      ? const Center(child: Text('لا توجد موديولات مفعّلة حاليًا'))
                      : GridView.count(
                          padding: const EdgeInsets.all(16),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: _availableModules.map((module) {
                            return Card(
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => module.screenBuilder()),
                                  );
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(module.icon, size: 36),
                                    const SizedBox(height: 8),
                                    Text(module.nameAr),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildLockScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_clock_outlined, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text(
              'وصلت مدة الإقفال الإجباري',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'لازم تسليم/استلام الحسابات دلوقتي قبل ما تكمّل البيع - أي حد يقدر يعمل ده '
              '(نفسك، زميلك، أو المدير)، المهم الوردية تتقفل والحسابات تتأكد.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _goToMandatoryHandover,
                icon: const Icon(Icons.point_of_sale_outlined),
                label: const Text('تسليم/استلام الحسابات الآن'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أو ممكن أي حد يعمل "استلام نقدية من الخزنة" لو عنده الصلاحية - وده بيفك القفل برضه.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
