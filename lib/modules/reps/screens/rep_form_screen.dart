import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/rep.dart';
import '../repository/rep_repository.dart';
import '../../../core/utils/document_picker.dart';
import '../../../core/widgets/document_preview.dart';

/// أنواع مستندات المندوب - نفس القائمة المستخدمة في شاشة المستندات
/// الكاملة (rep_documents_screen.dart) عشان الاتنين يفضلوا متطابقين.
const _repDocTypes = {
  'national_id': 'بطاقة الرقم القومي',
  'address': 'إثبات العنوان / محل الإقامة',
  'certificate': 'الشهادة / المؤهل',
  'license': 'الرخصة',
  'contract': 'العقد مع السوبر ماركت',
  'other': 'مستند إضافي',
};

/// إضافة/تعديل بيانات مندوب: الاسم، صورته، تليفونه، الرقم القومي،
/// العنوان، وملاحظات - قابلة للتعديل في أي وقت من بروفايله.
class RepFormScreen extends StatefulWidget {
  final Rep? rep;

  const RepFormScreen({super.key, this.rep});

  @override
  State<RepFormScreen> createState() => _RepFormScreenState();
}

class _RepFormScreenState extends State<RepFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = RepRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _nationalIdController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  String? _photoPath;
  bool _active = true;
  bool _saving = false;

  // مستندات المندوب: في وضع التعديل بنحملهم من قاعدة البيانات مباشرة،
  // وفي وضع الإضافة بنخزنهم مؤقتًا (pending) لحد ما المندوب يتحفظ
  // ويبقى له id، وبعدين بنرحّلهم كلهم دفعة واحدة.
  List<Map<String, dynamic>> _existingDocuments = [];
  final List<Map<String, String?>> _pendingDocuments = [];
  bool _loadingDocuments = false;

  bool get _isEditing => widget.rep != null;

  @override
  void initState() {
    super.initState();
    final r = widget.rep;
    _nameController = TextEditingController(text: r?.name ?? '');
    _phoneController = TextEditingController(text: r?.phone ?? '');
    _emailController = TextEditingController(text: r?.email ?? '');
    _nationalIdController = TextEditingController(text: r?.nationalId ?? '');
    _addressController = TextEditingController(text: r?.address ?? '');
    _notesController = TextEditingController(text: r?.notes ?? '');
    _photoPath = r?.photoPath;
    _active = r?.active ?? true;
    if (_isEditing) _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocuments = true);
    final docs = await _repository.getDocumentsForRep(widget.rep!.id!);
    setState(() {
      _existingDocuments = docs;
      _loadingDocuments = false;
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
                items: _repDocTypes.entries
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
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final title = titleController.text.trim().isEmpty ? null : titleController.text.trim();
    final expiryIso = expiryDate?.toIso8601String();

    if (_isEditing) {
      // في وضع التعديل، المندوب له id بالفعل، فبنحفظ المستند على طول
      await _repository.addDocument(
        repId: widget.rep!.id!,
        docType: docType,
        title: title,
        filePath: pickedPath,
        expiryDate: expiryIso,
      );
      _loadDocuments();
    } else {
      // في وضع الإضافة، لسه معندناش id، فبنخزنه مؤقتًا لحد ما نحفظ المندوب
      setState(() {
        _pendingDocuments.add({
          'doc_type': docType,
          'title': title,
          'file_path': pickedPath,
          'expiry_date': expiryIso,
        });
      });
    }
  }

  Future<void> _deleteExistingDocument(int id) async {
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
    _loadDocuments();
  }

  void _removePendingDocument(int index) {
    setState(() => _pendingDocuments.removeAt(index));
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 75, maxWidth: 800);
    if (picked != null) setState(() => _photoPath = picked.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final rep = Rep(
      id: widget.rep?.id,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      nationalId: _nationalIdController.text.trim().isEmpty ? null : _nationalIdController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      photoPath: _photoPath,
      active: _active,
      createdAt: widget.rep?.createdAt ?? DateTime.now().toIso8601String(),
    );

    if (_isEditing) {
      await _repository.updateRep(rep);
      if (mounted) Navigator.pop(context, rep);
    } else {
      final id = await _repository.addRep(rep);
      // بعد ما اتحفظ المندوب وبقى له id، نرحّل كل المستندات اللي
      // اتضافت مؤقتًا وهو لسه ما اتحفظش
      for (final doc in _pendingDocuments) {
        await _repository.addDocument(
          repId: id,
          docType: doc['doc_type']!,
          title: doc['title'],
          filePath: doc['file_path']!,
          expiryDate: doc['expiry_date'],
        );
      }
      if (mounted) Navigator.pop(context, Rep.fromMap({...rep.toMap(), 'id': id}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل بيانات مندوب' : 'مندوب جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                    image: (_photoPath != null && File(_photoPath!).existsSync())
                        ? DecorationImage(image: FileImage(File(_photoPath!)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: (_photoPath == null || !File(_photoPath!).existsSync())
                      ? const Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.grey)
                      : null,
                ),
              ),
            ),
            Center(
              child: TextButton(onPressed: _pickPhoto, child: const Text('صورة المندوب')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'الاسم بالكامل'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'التليفون'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'الإيميل (اختياري)'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nationalIdController,
              decoration: const InputDecoration(labelText: 'الرقم القومي (اختياري)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('نشط'),
              subtitle: const Text('المندوب غير النشط بيفضل بياناته وسجله، بس مش هيظهر في الاختيارات الجديدة'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 16),
            _buildDocumentsSection(),
          ],
        ),
      ),
      // زرار الحفظ ثابت فوق حافة الشاشة السفلية (خارج الليست) عشان يفضل
      // ظاهر ومتاح للضغط عليه حتى في الموبايلات إللي عندها زرار/إيموجستشر
      // نظام تشغيل في الأسفل - SafeArea بتضيف مسافة إضافية تلقائيًا لو لازم
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
        ),
      ),
    );
  }

  /// قسم المستندات جوه الفورم نفسه: بطاقة الرقم القومي، الشهادة/المؤهل،
  /// الرخصة، إثبات محل الإقامة، العقد مع السوبر ماركت، وأي مستند إضافي -
  /// عدد غير محدود من الصور، وشغالة سواء وانت بتضيف مندوب جديد أو بتعدل
  /// واحد موجود (في حالة الإضافة بتترحّل تلقائيًا بعد الحفظ).
  Widget _buildDocumentsSection() {
    final totalCount = _existingDocuments.length + _pendingDocuments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'مستندات المندوب${totalCount > 0 ? ' ($totalCount)' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: _addDocument,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('إضافة'),
            ),
          ],
        ),
        Text(
          'بطاقة الرقم القومي، الشهادة، الرخصة، إثبات محل الإقامة، العقد مع السوبر ماركت، '
          'أو أي مستند إضافي - تقدر تضيف أكتر من مستند بنفس النوع، صورة أو ملف PDF.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (_loadingDocuments)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else if (totalCount == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('لسه مفيش مستندات مضافة'),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              final isExisting = index < _existingDocuments.length;
              final path = isExisting
                  ? _existingDocuments[index]['file_path'] as String
                  : _pendingDocuments[index - _existingDocuments.length]['file_path']!;
              final docTypeKey = isExisting
                  ? _existingDocuments[index]['doc_type'] as String?
                  : _pendingDocuments[index - _existingDocuments.length]['doc_type'];
              final docTypeLabel = _repDocTypes[docTypeKey] ?? 'مستند';

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                      child: Column(
                        children: [
                          Expanded(child: DocumentPreview(path: path)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              docTypeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: InkWell(
                      onTap: () => isExisting
                          ? _deleteExistingDocument(_existingDocuments[index]['id'] as int)
                          : _removePendingDocument(index - _existingDocuments.length),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
