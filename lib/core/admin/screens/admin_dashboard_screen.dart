import 'package:flutter/material.dart';
import '../../auth/screens/user_management_screen.dart';
import '../../auth/screens/shift_history_screen.dart';
import '../../backup/backup_screen.dart';
import '../../devices/screens/devices_screen.dart';
import '../../store_settings/store_settings_screen.dart';
import '../../../modules/hr/screens/employees_home_screen.dart';
import '../../../modules/sales/screens/discount_settings_screen.dart';
import '../../../modules/sales/screens/scan_sound_settings_screen.dart';
import '../../auth/screens/cash_pickup_screen.dart';
import '../../auth/screens/cash_checkpoints_history_screen.dart';
import '../../auth/screens/mandatory_closing_settings_screen.dart';
import '../../licensing/screens/license_generator_screen.dart';
import 'modules_toggle_screen.dart';
import 'user_permissions_screen.dart';

/// لوحة التحكم الإدارية الموحّدة: كل أدوات إدارة النظام في مكان واحد -
/// المستخدمين وصلاحياتهم، تفعيل/تعطيل الموديولات، الموظفين، الأجهزة
/// المتصلة، سجل الورديات، النسخ الاحتياطي، وإعدادات المحل.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_DashboardItem>[
      _DashboardItem(
        'المستخدمين',
        'إضافة كاشير جدد، تفعيل/تعطيل الحسابات',
        Icons.people_outline,
        (context) => const UserManagementScreen(),
      ),
      _DashboardItem(
        'صلاحيات المستخدمين',
        'تحديد الموديولات المسموحة لكل كاشير',
        Icons.admin_panel_settings_outlined,
        (context) => const UserPermissionsScreen(),
      ),
      _DashboardItem(
        'تفعيل/تعطيل الموديولات',
        'التحكم في أي موديول يظهر بالشاشة الرئيسية',
        Icons.dashboard_customize_outlined,
        (context) => const ModulesToggleScreen(),
      ),
      _DashboardItem(
        'الموظفين',
        'بياناتهم، حضورهم، ومرتباتهم',
        Icons.badge_outlined,
        (context) => const EmployeesHomeScreen(),
      ),
      _DashboardItem(
        'الأجهزة المتصلة',
        'الطابعات، شاشات عرض العميل، والسكانرات',
        Icons.devices_other_outlined,
        (context) => const DevicesScreen(),
      ),
      _DashboardItem(
        'سجل الورديات',
        'ورديات الكاشير وملخص كل وردية',
        Icons.schedule_outlined,
        (context) => const ShiftHistoryScreen(),
      ),
      _DashboardItem(
        'النسخ الاحتياطي',
        'تصدير/استيراد نسخة كاملة من بيانات المحل',
        Icons.backup_outlined,
        (context) => const BackupScreen(),
      ),
      _DashboardItem(
        'إعدادات المحل',
        'اسم المحل، اللوجو، بيانات التواصل',
        Icons.store_outlined,
        (context) => const StoreSettingsScreen(),
      ),
      _DashboardItem(
        'إعدادات الخصم',
        'تفعيل الخصم في نقطة البيع وأقصى نسبة مسموحة',
        Icons.percent_outlined,
        (context) => const DiscountSettingsScreen(),
      ),
      _DashboardItem(
        'استلام نقدية من الخزنة',
        'تسجيل استلام الكاش الفعلي من الدرج',
        Icons.point_of_sale_outlined,
        (context) => const CashPickupScreen(),
      ),
      _DashboardItem(
        'سجل استلام الخزنة',
        'كل نقاط الاستلام السابقة والفروقات',
        Icons.receipt_long_outlined,
        (context) => const CashCheckpointsHistoryScreen(),
      ),
      _DashboardItem(
        'الإقفال الإجباري',
        'كل كام ساعة لازم إغلاق وردية أو استلام خزنة',
        Icons.lock_clock_outlined,
        (context) => const MandatoryClosingSettingsScreen(),
      ),
      _DashboardItem(
        'إعدادات صوت الباركود',
        'تفعيل/تعطيل صوت نجاح وفشل قراءة الباركود ومستوى الصوت',
        Icons.volume_up_outlined,
        (context) => const ScanSoundSettingsScreen(),
      ),
      _DashboardItem(
        'أداة المطوّر',
        'توليد كود تفعيل لعميل جديد (محمي بكلمة سر خاصة)',
        Icons.vpn_key_outlined,
        (context) => const LicenseGeneratorGateScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة التحكم الإدارية')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: item.screenBuilder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 32),
                    const SizedBox(height: 8),
                    Text(item.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function(BuildContext) screenBuilder;

  _DashboardItem(this.title, this.subtitle, this.icon, this.screenBuilder);
}
