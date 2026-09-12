import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/employee.dart';
import '../repository/employee_repository.dart';
import '../../../core/utils/document_picker.dart';
import '../../../core/widgets/document_preview.dart';

/// إضافة/تعديل بيانات موظف كاملة: الاسم، العنوان، التليفون، الرقم
/// القومي، المؤهل، الوظيفة، نوع الأجر (شهري/يومية)، بالإضافة لصورة
/// الموظف وصورة مستند الشهادة وبيان العنوان وصورة بطاقة الرقم القومي.
class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;

  const EmployeeFormScreen({super.key, this.employee});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = EmployeeRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _nationalIdController;
  late final TextEditingController _addressController;
  late final TextEditingController _positionController;
  late final TextEditingController _qualificationController;
  late final TextEditingController _salaryController;
  late final TextEditingController _notesController;

  String _salaryType = 'monthly';
  bool _active = true;
  String? _photoPath;
  String? _nationalIdImagePath;
  String? _qualificationDocPath;
  String? _addressProofPath;
  String? _contractDocPath;
  bool _saving = false;

  bool get _isEditing => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameController = TextEditingController(text: e?.name ?? '');
    _phoneController = TextEditingController(text: e?.phone ?? '');
    _nationalIdController = TextEditingController(text: e?.nationalId ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');
    _positionController = TextEditingController(text: e?.position ?? '');
    _qualificationController = TextEditingController(text: e?.qualification ?? '');
    _salaryController = TextEditingController(text: e != null ? e.baseSalary.toStringAsFixed(2) : '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _salaryType = e?.salaryType ?? 'monthly';
    _active = e?.active ?? true;
    _photoPath = e?.photoPath;
    _nationalIdImagePath = e?.nationalIdImagePath;
    _qualificationDocPath = e?.qualificationDocPath;
    _addressProofPath = e?.addressProofPath;
    _contractDocPath = e?.contractDocPath;
  }

  Future<String?> _pickImage() async {
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
    if (source == null) return null;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1400);
    return picked?.path;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final employee = Employee(
      id: widget.employee?.id,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      nationalId: _nationalIdController.text.trim().isEmpty ? null : _nationalIdController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      position: _positionController.text.trim().isEmpty ? null : _positionController.text.trim(),
      qualification: _qualificationController.text.trim().isEmpty ? null : _qualificationController.text.trim(),
      salaryType: _salaryType,
      baseSalary: double.tryParse(_salaryController.text.trim()) ?? 0,
      hireDate: widget.employee?.hireDate ?? DateTime.now().toIso8601String().substring(0, 10),
      photoPath: _photoPath,
      nationalIdImagePath: _nationalIdImagePath,
      qualificationDocPath: _qualificationDocPath,
      addressProofPath: _addressProofPath,
      contractDocPath: _contractDocPath,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      active: _active,
      createdAt: widget.employee?.createdAt ?? DateTime.now().toIso8601String(),
    );

    if (_isEditing) {
      await _repository.updateEmployee(employee);
      if (mounted) Navigator.pop(context, employee);
    } else {
      final id = await _repository.addEmployee(employee);
      if (mounted) Navigator.pop(context, Employee.fromMap({...employee.toMap(), 'id': id}));
    }
  }

  Widget _docPickerTile({
    required String label,
    required String? path,
    required ValueChanged<String?> onPicked,
  }) {
    return Card(
      child: ListTile(
        leading: DocumentLeadingThumbnail(path: path),
        title: Text(label),
        subtitle: Text(path != null ? (isPdfPath(path) ? 'مرفوع (PDF)' : 'مرفوعة') : 'غير مرفوعة'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'رفع/تغيير (صورة أو PDF)',
              onPressed: () async {
                final picked = await DocumentPicker.pick(context);
                if (picked != null) onPicked(picked);
              },
            ),
            if (path != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'حذف',
                onPressed: () => onPicked(null),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل بيانات موظف' : 'موظف جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: () async {
                  final picked = await _pickImage();
                  if (picked != null) setState(() => _photoPath = picked);
                },
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
            const SizedBox(height: 16),
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
              controller: _nationalIdController,
              decoration: const InputDecoration(labelText: 'الرقم القومي'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _positionController,
              decoration: const InputDecoration(labelText: 'الوظيفة'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qualificationController,
              decoration: const InputDecoration(labelText: 'المؤهل الدراسي'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _salaryType,
              decoration: const InputDecoration(labelText: 'نوع الأجر'),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('مرتب شهري')),
                DropdownMenuItem(value: 'daily', child: Text('يومية (أجر باليوم)')),
              ],
              onChanged: (v) => setState(() => _salaryType = v ?? 'monthly'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _salaryController,
              decoration: InputDecoration(
                labelText: _salaryType == 'monthly' ? 'المرتب الشهري الأساسي' : 'قيمة اليومية',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 16),
            const Text('المستندات', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _docPickerTile(
              label: 'صورة بطاقة الرقم القومي',
              path: _nationalIdImagePath,
              onPicked: (p) => setState(() => _nationalIdImagePath = p),
            ),
            _docPickerTile(
              label: 'صورة مستند الشهادة / المؤهل',
              path: _qualificationDocPath,
              onPicked: (p) => setState(() => _qualificationDocPath = p),
            ),
            _docPickerTile(
              label: 'بيان / إثبات العنوان',
              path: _addressProofPath,
              onPicked: (p) => setState(() => _addressProofPath = p),
            ),
            _docPickerTile(
              label: 'عقد العمل',
              path: _contractDocPath,
              onPicked: (p) => setState(() => _contractDocPath = p),
            ),
            const SizedBox(height: 8),
            if (_isEditing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'المستندات الإضافية (عقد، شهادات خبرة...) تتضاف من بروفايل الموظف بعد الحفظ',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
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
}
