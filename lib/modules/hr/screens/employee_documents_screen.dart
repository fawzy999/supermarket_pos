import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../repository/employee_repository.dart';
import '../../../core/utils/document_picker.dart';
import '../../../core/widgets/document_preview.dart';

/// مستندات إضافية للموظف (عقد عمل، شهادات خبرة، إلخ) - عدد غير محدود
/// من الملفات، كل واحد بعنوان وصورة، قابلة للإضافة أو الحذف في أي وقت.
class EmployeeDocumentsScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeDocumentsScreen({super.key, required this.employee});

  @override
  State<EmployeeDocumentsScreen> createState() => _EmployeeDocumentsScreenState();
}

class _EmployeeDocumentsScreenState extends State<EmployeeDocumentsScreen> {
  final _repository = EmployeeRepository();
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final documents = await _repository.getDocumentsForEmployee(widget.employee.id!);
    setState(() {
      _documents = documents;
      _loading = false;
    });
  }

  Future<void> _addDocument() async {
    final pickedPath = await DocumentPicker.pick(context);
    if (pickedPath == null) return;

    final titleController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عنوان المستند'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'مثال: عقد العمل، شهادة الخبرة...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (confirmed != true) return;

    await _repository.addDocument(
      employeeId: widget.employee.id!,
      title: titleController.text.trim().isEmpty ? null : titleController.text.trim(),
      filePath: pickedPath,
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
      appBar: AppBar(title: Text('مستندات ${widget.employee.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDocument,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('إضافة مستند'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(child: Text('لا توجد مستندات إضافية مرفوعة بعد'))
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
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Expanded(child: DocumentPreview(path: path)),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (doc['title'] as String?) ?? 'مستند',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
