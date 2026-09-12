import 'package:flutter/material.dart';

/// وصف كامل لأي موديول في النظام (مخزون، مبيعات، محاسبة...)
/// أي موديول جديد بيتضاف هيكون بس نسخة جديدة من الكلاس ده
/// في module_registry.dart
class ModuleDefinition {
  final String key; // معرف فريد يطابق module_key في قاعدة البيانات
  final String nameAr; // الاسم المعروض بالعربي
  final IconData icon;
  final String minTier; // 'basic' أو 'pro' - أقل باقة تشمل الموديول ده
  final Widget Function() screenBuilder; // الشاشة الرئيسية للموديول

  const ModuleDefinition({
    required this.key,
    required this.nameAr,
    required this.icon,
    required this.screenBuilder,
    this.minTier = 'basic',
  });
}
