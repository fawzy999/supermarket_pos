import 'package:flutter/material.dart';
import 'module_definition.dart';
import '../../modules/inventory/screens/category_list_screen.dart';
import '../../modules/inventory/screens/expiry_alerts_screen.dart';
import '../../modules/inventory/screens/supplier_list_screen.dart';
import '../../modules/sales/screens/sales_home_screen.dart';
import '../../modules/accounting/screens/accounting_home_screen.dart';
import '../../modules/customers/screens/customer_list_screen.dart';
import '../../modules/returns/screens/returns_home_screen.dart';
import '../../modules/reps/screens/reps_home_screen.dart';
import '../../modules/hr/screens/employees_home_screen.dart';
import '../../modules/marketing/screens/offers_screen.dart';

/// السجل المركزي لكل الموديولات الموجودة في الكود.
///
/// لإضافة موديول جديد بعدين (CRM، HR، المشتريات المتقدمة...):
/// 1. أضف صف جديد هنا بنفس الشكل
/// 2. أضف صف مطابق في جدول `modules` بقاعدة البيانات
/// (module_repository هو اللي بيقرر إيه اللي يظهر فعليًا للمستخدم
/// حسب الترخيص والتفعيل - مش الملف ده)
class ModuleRegistry {
  static final List<ModuleDefinition> all = [
    ModuleDefinition(
      key: 'inventory',
      nameAr: 'المخزون',
      icon: Icons.inventory_2_outlined,
      minTier: 'basic',
      screenBuilder: () => const CategoryListScreen(),
    ),
    ModuleDefinition(
      key: 'sales',
      nameAr: 'المبيعات',
      icon: Icons.point_of_sale_outlined,
      minTier: 'basic',
      screenBuilder: () => const SalesHomeScreen(),
    ),
    ModuleDefinition(
      key: 'accounting',
      nameAr: 'المحاسبة',
      icon: Icons.receipt_long_outlined,
      minTier: 'pro',
      screenBuilder: () => const AccountingHomeScreen(),
    ),
    ModuleDefinition(
      key: 'returns',
      nameAr: 'المرتجعات',
      icon: Icons.assignment_return_outlined,
      minTier: 'pro',
      screenBuilder: () => const ReturnsHomeScreen(),
    ),
    ModuleDefinition(
      key: 'expiry_alerts',
      nameAr: 'تنبيهات الصلاحية',
      icon: Icons.warning_amber_outlined,
      minTier: 'basic',
      screenBuilder: () => const ExpiryAlertsScreen(),
    ),
    ModuleDefinition(
      key: 'customers',
      nameAr: 'العملاء',
      icon: Icons.people_alt_outlined,
      minTier: 'pro',
      screenBuilder: () => const CustomerListScreen(),
    ),
    ModuleDefinition(
      key: 'suppliers',
      nameAr: 'الموردين',
      icon: Icons.local_shipping_outlined,
      minTier: 'basic',
      screenBuilder: () => const SupplierListScreen(),
    ),
    ModuleDefinition(
      key: 'reps',
      nameAr: 'المناديب والشحن',
      icon: Icons.delivery_dining_outlined,
      minTier: 'pro',
      screenBuilder: () => const RepsHomeScreen(),
    ),
    ModuleDefinition(
      key: 'hr',
      nameAr: 'الموظفين',
      icon: Icons.badge_outlined,
      minTier: 'pro',
      screenBuilder: () => const EmployeesHomeScreen(),
    ),
    ModuleDefinition(
      key: 'marketing',
      nameAr: 'العروض التسويقية',
      icon: Icons.campaign_outlined,
      minTier: 'pro',
      screenBuilder: () => const OffersScreen(),
    ),
  ];
}
