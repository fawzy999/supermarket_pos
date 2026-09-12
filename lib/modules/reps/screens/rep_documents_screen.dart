import 'package:flutter/material.dart';
import '../models/rep.dart';
import '../repository/rep_repository.dart';
import '../../../core/utils/document_picker.dart';
import '../../../core/widgets/document_preview.dart';

/// مستندات المندوب: بطاقة الرقم القومي، إثبات العنوان، الشهادة/المؤهل،
/// العقد، أو أي مستند إضافي - عدد غير محدود، كل مستند بنوع وعنوان وصورة.
class RepDocumentsScreen extends StatefulWidget {
  final Rep rep;

  const RepDocumentsScreen({super.key, required this.rep});

  @override
  State<RepDocumentsScreen> createState() => _RepDocumentsScreenState();
}

class _RepDocumentsScreenState extends State<RepDocumentsScreen> {
  static const _docTypes = {
    'national_id': 'بطاقة الرقم القومي',
    'address': 'إثبات العنوان / محل الإقامة',
    'certificate': 'الشهادة / المؤهل',
    'license': 'الرخصة',
    'contract': 'العقد مع السوبر ماركت',
    'other': 'مستند إضافي',
  };

  final _repository = RepRepository();
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final documents = await _repository.getDocumentsForRep(widget.rep.id!);
    setState(() {
      _documents = documents;
      _loading = false;
    });
  }

  Future<void> _addDocument() async {
    final pickedPath = await DocumentPicker.pick(context);
    if (pickedPath == null) return;

    String docType = 'other';
    DateTime? expiryDate;
    final titleController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text('بيانات المستند'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: docType,
                decoration: const InputDecoration(labelText: 'نوع المستند'),
                items: _docTypes.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => dialogSetState(() => docType = v ?? 'other'),
              ),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'عنوان (اختياري)'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(expiryDate == null
                    ? 'تاريخ انتهاء الصلاحية (اختياري)'
                    : 'ينتهي في: ${expiryDate!.toIso8601String().substring(0, 10)}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: expiryDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) dialogSetState(() => expiryDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    await _repository.addDocument(
      repId: widget.rep.id!,
      docType: docType,
      title: titleController.text.trim().isEmpty ? null : titleController.text.trim(),
      filePath: pickedPath,
      expiryDate: expiryDate?.toIso8601String(),
    );
    _load();
  }

  Future<void> _deleteDocument(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المستند'),
        content: const Text('هل تريد حذف هذا المستند؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteDocument(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مستندات ${widget.rep.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDocument,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('إضافة مستند'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(child: Text('لا توجد مستندات مرفوعة بعد'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    final path = doc['file_path'] as String;
                    final docType = _docTypes[doc['doc_type'] as String?] ?? 'مستند';
                    final expiryStr = doc['expiry_date'] as String?;
                    final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
                    final isExpired = expiry != null && expiry.isBefore(DateTime.now());
                    final isExpiringSoon =
                        expiry != null && !isExpired && expiry.isBefore(DateTime.now().add(const Duration(days: 30)));
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                DocumentPreview(path: path),
                                if (isExpired || isExpiringSoon)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Chip(
                                      label: Text(isExpired ? 'منتهي' : 'قريب الانتهاء', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                      backgroundColor: isExpired ? Colors.red : Colors.orange,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (doc['title'] as String?) ?? docType,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      Text(docType, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () => _deleteDocument(doc['id'] as int),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
