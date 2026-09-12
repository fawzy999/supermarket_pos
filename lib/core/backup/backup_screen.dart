import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'backup_repository.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _repository = BackupRepository();
  String? _lastBackupTime;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackupTime();
  }

  Future<void> _loadLastBackupTime() async {
    final time = await _repository.getLastBackupTime();
    setState(() => _lastBackupTime = time);
  }

  Future<void> _exportAndShare() async {
    setState(() => _busy = true);
    try {
      final file = await _repository.exportBackup();
      await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية من بيانات المحل');
      _loadLastBackupTime();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromFile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استيراد نسخة احتياطية'),
        content: const Text(
          'تحذير: كل البيانات الحالية على الجهاز ده هتتمسح وتتستبدل بالكامل ببيانات النسخة المختارة. متأكد إنك عايز تكمل؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، استبدل البيانات'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;

    setState(() => _busy = true);
    try {
      await _repository.importBackup(result.files.single.path!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم استيراد النسخة الاحتياطية بنجاح. أعد فتح التطبيق.')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('آخر نسخة احتياطية', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        _lastBackupTime != null
                            ? _lastBackupTime!.substring(0, 16).replaceFirst('T', '  ')
                            : 'لسه معملتش نسخة احتياطية',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _exportAndShare,
                icon: const Icon(Icons.upload_outlined),
                label: const Text('تصدير ومشاركة نسخة احتياطية'),
              ),
              const SizedBox(height: 8),
              const Text(
                'هتقدر تبعتها لنفسك على واتساب، أو تحفظها في جوجل درايف يدويًا من قائمة المشاركة',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _busy ? null : _importFromFile,
                icon: const Icon(Icons.download_outlined),
                label: const Text('استيراد نسخة احتياطية'),
              ),
              const SizedBox(height: 8),
              const Text(
                'استخدمها لو بتنقل بياناتك لجهاز جديد أو حصل عطل وعايز ترجع لآخر نسخة محفوظة',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          if (_busy)
            Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
