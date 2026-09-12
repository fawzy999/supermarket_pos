import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import '../store_settings/store_settings_repository.dart';

class BackupRepository {
  final _db = AppDatabase.instance;
  final _storeRepository = StoreSettingsRepository();

  /// بينسخ ملف قاعدة البيانات الحالي لملف مؤقت بيحمل تاريخ اليوم، جاهز للمشاركة
  Future<File> exportBackup() async {
    final sourceFile = File(_db.databasePath);
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().substring(0, 10);
    final backupFile = File('${tempDir.path}/نسخة_احتياطية_$timestamp.db');
    await sourceFile.copy(backupFile.path);

    await _storeRepository.setSetting('last_backup_at', DateTime.now().toIso8601String());
    return backupFile;
  }

  /// بيستبدل قاعدة البيانات الحالية بملف نسخة احتياطية مختار
  /// تحذير: ده بيمسح كل البيانات الحالية ويستبدلها بالكامل
  Future<void> importBackup(String pickedFilePath) async {
    final dbPath = _db.databasePath;

    // لازم نقفل الاتصال الحالي الأول قبل ما نلمس الملف
    await _db.close();

    final pickedFile = File(pickedFilePath);
    await pickedFile.copy(dbPath);

    await _db.reopen();
  }

  Future<String?> getLastBackupTime() async {
    final settings = await _storeRepository.getSettings();
    return settings['last_backup_at'];
  }
}
