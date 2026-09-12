import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// إشعارات محلية (Local Notifications) - بتظهر في شريط إشعارات
/// أندرويد زي أي تطبيق تاني. بتتفعّل لما التطبيق يكون شغال (foreground
/// أو background قريب)، مش بديل كامل لإشعارات تلقائية حتى لو التطبيق
/// مقفول تمامًا من كام يوم - ده محتاج جدولة دقيقة بصلاحيات خاصة في
/// أندرويد 12+ ومؤجل لحد ما يتأكد إنه شغال كويس على جهاز حقيقي.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    // أندرويد 13+ محتاج إذن صريح للإشعارات - بنطلبه مرة واحدة هنا
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  /// إشعار فوري (مش مجدول) - يظهر أول ما التطبيق يفتح ويكتشف حاجة محتاجة
  /// انتباه (أقساط مستحقة، مستندات قربت تنتهي، إلخ)
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();
    const androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'تذكيرات المحل',
      channelDescription: 'تذكيرات الأقساط والمستندات والمديونيات',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }
}
