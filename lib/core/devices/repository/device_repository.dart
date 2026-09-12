import 'dart:io';
import '../../database/app_database.dart';
import '../models/connected_device.dart';

/// إدارة سجل الأجهزة المتصلة بالمحل (طابعات، شاشات عرض العميل،
/// سكانرات...): إضافتها، تعديل بياناتها، تحديد الجهاز الافتراضي لكل
/// نوع، وفحص حالة الاتصال الفعلي لأجهزة الشبكة (واي فاي).
class DeviceRepository {
  final _db = AppDatabase.instance;

  Future<List<ConnectedDevice>> getAllDevices() async {
    final rows = await _db.database.query('connected_devices', orderBy: 'type, name');
    return rows.map((r) => ConnectedDevice.fromMap(r)).toList();
  }

  Future<ConnectedDevice?> getDeviceById(int id) async {
    final rows = await _db.database.query('connected_devices', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ConnectedDevice.fromMap(rows.first);
  }

  Future<int> addDevice(ConnectedDevice device) async {
    final id = await _db.database.insert('connected_devices', device.toMap());
    if (device.isDefault) await _clearOtherDefaults(device.type, id);
    return id;
  }

  Future<void> updateDevice(ConnectedDevice device) async {
    await _db.database.update(
      'connected_devices',
      device.toMap(),
      where: 'id = ?',
      whereArgs: [device.id],
    );
    if (device.isDefault) await _clearOtherDefaults(device.type, device.id!);
  }

  Future<void> deleteDevice(int id) => _db.database.delete('connected_devices', where: 'id = ?', whereArgs: [id]);

  Future<void> setAsDefault(int deviceId, String type) async {
    await _db.database.update(
      'connected_devices',
      {'is_default': 1},
      where: 'id = ?',
      whereArgs: [deviceId],
    );
    await _clearOtherDefaults(type, deviceId);
  }

  Future<void> _clearOtherDefaults(String type, int keepId) async {
    await _db.database.update(
      'connected_devices',
      {'is_default': 0},
      where: 'type = ? AND id != ?',
      whereArgs: [type, keepId],
    );
  }

  /// فحص حالة الاتصال الفعلي: بيشتغل فعليًا لأجهزة الواي فاي (بيحاول
  /// يفتح اتصال شبكة قصير على عنوان الـ IP)، وباقي الأنواع (بلوتوث/USB)
  /// بترجع "unknown" لأن الفحص التلقائي مش متاح ليها من غير درايفر خاص،
  /// والحالة بتتحدث يدويًا من شاشة الجهاز.
  Future<String> checkConnection(ConnectedDevice device) async {
    String newStatus;

    if (device.connectionType == 'wifi' && device.address != null && device.address!.trim().isNotEmpty) {
      try {
        final socket = await Socket.connect(
          device.address!.trim(),
          9100, // البورت القياسي لطابعات الشبكة (ESC/POS over TCP)
          timeout: const Duration(seconds: 3),
        );
        await socket.close();
        newStatus = 'connected';
      } catch (_) {
        newStatus = 'disconnected';
      }
    } else {
      newStatus = 'unknown';
    }

    await _db.database.update(
      'connected_devices',
      {'status': newStatus, 'last_checked_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [device.id],
    );
    return newStatus;
  }

  Future<void> setStatusManually(int deviceId, String status) async {
    await _db.database.update(
      'connected_devices',
      {'status': status, 'last_checked_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }
}
