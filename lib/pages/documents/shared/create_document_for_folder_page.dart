import 'package:flutter/material.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/document.dart';
import '../../../models/document_attachment.dart';
import '../../../models/document_type.dart';
import '../../../models/employee.dart';
import '../../../models/hotel.dart';
import '../../../repositories/document_repository.dart';
import '../../../repositories/employee_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../services/attachment_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_dialog.dart';
import '../../../widgets/common/app_text_field.dart';
import 'employee_picker_sheet.dart';

/// إنشاء مستند جديد بالكامل غير موجود في النظام بعد، وربطه فوراً بالمجلد
/// الحالي (مرجع واحد، بلا أي نسخ). المستند بعد حفظه يُصبح قابلاً للربط من
/// أي مجلد آخر لاحقاً عبر "إضافة مستند" → LinkExistingDocumentsPage — عامة
/// لأي مجلد بغض النظر عن دورة حياته (دائم/موسمي/مستندات موظفين).
///
/// [ownerType] يحدد الجهة المالكة للمستند الجديد: [Document.ownerTypeHotel]
/// (الافتراضي — يعرض اختيار نطاق الفنادق كما كان) أو
/// [Document.ownerTypeEmployee] (يستبدل نطاق الفنادق باختيار موظف واحد؛
/// الفندق يُشتَق تلقائياً من فندق الموظف الحالي، لأن كل موظف تابع لفندق واحد
/// دوماً — راجع Employee.hotelId).
class CreateDocumentForFolderPage extends StatefulWidget {
  final DocumentType folder;
  final String ownerType;
  const CreateDocumentForFolderPage({super.key, required this.folder, this.ownerType = Document.ownerTypeHotel});

  @override
  State<CreateDocumentForFolderPage> createState() => _CreateDocumentForFolderPageState();
}

class _CreateDocumentForFolderPageState extends State<CreateDocumentForFolderPage> {
  final _documentRepository = DocumentRepository();
  final _hotelRepository = HotelRepository();
  final _employeeRepository = EmployeeRepository();

  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _notesController = TextEditingController();

  bool get _isEmployeeOwner => widget.ownerType == Document.ownerTypeEmployee;

  List<Hotel> _hotels = [];
  String _hotelScope = Document.hotelScopeAll;
  int? _selectedHotelId;

  List<Employee> _employees = [];
  Employee? _selectedEmployee;

  bool _isLoading = true;
  bool _isSaving = false;

  ({String path, String name})? _pickedFile;
  String? _pickedFileType;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _hotels = await _hotelRepository.getAllHotels();
    if (_isEmployeeOwner) _employees = await _employeeRepository.getAllEmployees();
    if (mounted) setState(() => _isLoading = false);
  }

  String _hotelNameFor(int? hotelId) {
    for (final h in _hotels) {
      if (h.id == hotelId) return h.arabicName;
    }
    return "—";
  }

  Future<void> _pickEmployee() async {
    final result = await showEmployeePicker(
      context,
      employees: _employees,
      hotelNames: {for (final h in _hotels) if (h.id != null) h.id!: h.arabicName},
      title: "اختيار الموظف",
    );
    if (result == null || result == 0) return;
    for (final e in _employees) {
      if (e.id == result) {
        setState(() => _selectedEmployee = e);
        break;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _expiryDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => controller.text = picked.toString().split(' ')[0]);
  }

  Future<void> _pickImage() async {
    final picked = await AttachmentService.pickImages(folder: 'document_attachments');
    if (picked.isEmpty) return;
    setState(() {
      _pickedFile = picked.first;
      _pickedFileType = DocumentAttachment.detectFileType(picked.first.name);
    });
  }

  Future<void> _pickPdf() async {
    final picked = await AttachmentService.pickPdf(folder: 'document_attachments');
    if (picked == null) return;
    setState(() {
      _pickedFile = picked;
      _pickedFileType = 'pdf';
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال اسم المستند")));
      return;
    }
    if (_isEmployeeOwner && _selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار الموظف")));
      return;
    }
    if (!_isEmployeeOwner && _hotelScope == Document.hotelScopeSingle && _selectedHotelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار الفندق")));
      return;
    }
    if (widget.folder.requiresRenewal && _expiryDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("هذا المجلد يحتاج إلى تجديد، يرجى تحديد تاريخ الانتهاء")));
      return;
    }

    await AppDialog.confirmAction(
      context: context,
      title: "تأكيد الحفظ",
      message: "هل تريد حفظ هذا المستند؟ سيُصبح متاحاً للربط من أي مجلد آخر لاحقاً دون تكرار.",
      onConfirm: () async {
        setState(() => _isSaving = true);

        final int? documentHotelId;
        final Document document;
        if (_isEmployeeOwner) {
          final employee = _selectedEmployee!;
          documentHotelId = employee.hotelId;
          document = Document(
            hotelId: documentHotelId,
            ownerType: Document.ownerTypeEmployee,
            ownerId: employee.id,
            hotelScope: Document.hotelScopeSingle,
            documentTypeId: widget.folder.id,
            name: name,
            documentNumber: _numberController.text.trim().isEmpty ? null : _numberController.text.trim(),
            expiryDate: _expiryDateController.text.trim(),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            createdAt: DateTime.now().toIso8601String(),
          );
        } else {
          final primaryHotelId = _hotelScope == Document.hotelScopeSingle ? _selectedHotelId : null;
          documentHotelId = primaryHotelId;
          document = Document(
            hotelId: primaryHotelId,
            ownerType: Document.ownerTypeHotel,
            ownerId: primaryHotelId,
            hotelScope: _hotelScope,
            documentTypeId: widget.folder.id,
            name: name,
            documentNumber: _numberController.text.trim().isEmpty ? null : _numberController.text.trim(),
            expiryDate: _expiryDateController.text.trim(),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            createdAt: DateTime.now().toIso8601String(),
          );
        }

        final documentId = await _documentRepository.addDocument(document);
        await _documentRepository.linkDocumentToFolder(documentId, widget.folder.id!);

        if (_pickedFile != null && _pickedFileType != null) {
          await _documentRepository.addAttachment(DocumentAttachment(
            documentId: documentId,
            hotelId: documentHotelId ?? 0,
            filePath: _pickedFile!.path,
            fileType: _pickedFileType!,
            fileName: _pickedFile!.name,
            createdAt: DateTime.now().toIso8601String(),
          ));
        }

        if (mounted) Navigator.pop(context, true);
      },
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إنشاء مستند جديد", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(child: Text("سيُضاف إلى مجلد: ${widget.folder.name}", style: AppTextStyles.bodyBold)),
                    ],
                  ),
                ),
                if (_isEmployeeOwner) ...[
                  const SizedBox(height: AppSizes.md),
                  _buildEmployeeSection(),
                ],
                const SizedBox(height: AppSizes.md),
                AppCard(
                  child: Column(
                    children: [
                      AppTextField(controller: _nameController, hint: "اسم المستند", icon: Icons.description_outlined),
                      const SizedBox(height: AppSizes.md),
                      AppTextField(controller: _numberController, hint: "رقم المستند (اختياري)", icon: Icons.numbers_outlined),
                      const SizedBox(height: AppSizes.md),
                      _buildFileTypeIndicator(),
                      const SizedBox(height: AppSizes.md),
                      _buildDateField(
                        widget.folder.requiresRenewal ? "تاريخ الانتهاء (إجباري)" : "تاريخ الانتهاء (اختياري)",
                        _expiryDateController,
                      ),
                      const SizedBox(height: AppSizes.md),
                      AppTextField(controller: _notesController, hint: "ملاحظات (اختياري)", icon: Icons.notes_outlined, maxLines: 3),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                if (!_isEmployeeOwner) _buildScopeSection(),
                if (!_isEmployeeOwner) const SizedBox(height: AppSizes.md),
                _buildFilePicker(),
                const SizedBox(height: AppSizes.xl),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text("حفظ"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                const SizedBox(height: AppSizes.md),
              ],
            ),
    );
  }

  Widget _buildFileTypeIndicator() {
    final label = _pickedFileType == null ? "لم يُختر ملف بعد" : _pickedFileType!.toUpperCase();
    final isPdf = _pickedFileType == 'pdf';
    return Row(
      children: [
        Icon(isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSizes.sm),
        Text("نوع الملف: $label", style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return GestureDetector(
      onTap: () => _pickDate(controller),
      child: AbsorbPointer(
        child: AppTextField(controller: controller, hint: label, icon: Icons.calendar_today_outlined),
      ),
    );
  }

  Widget _buildEmployeeSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("الموظف والفندق", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: _pickEmployee,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  const Icon(Icons.person_outline),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      _selectedEmployee?.name ?? "اختيار الموظف",
                      style: _selectedEmployee == null ? AppTextStyles.caption : AppTextStyles.bodyBold.copyWith(fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          if (_selectedEmployee != null) ...[
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Icon(Icons.apartment_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text("الفندق: ${_hotelNameFor(_selectedEmployee!.hotelId)}", style: AppTextStyles.caption),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// يحدِّد هل المستند "عام" (لا يتبع فندقاً، hotelId=null) أو "خاص بفندق
  /// واحد" فقط — خيار ثنائي بسيط بدل نطاقات متعددة الفنادق القديمة، حتى
  /// يطابق مبدأ "عام أو خاص بفندق واحد" في تصميم النظام الجديد.
  Widget _buildScopeSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("هل هذا المستند عام أم خاص بفندق؟", style: AppTextStyles.bodyBold),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text("عام (لا يتبع فندقاً)"),
            subtitle: const Text("يخص الشركة بالكامل، مثل السجل التجاري أو العنوان الوطني", style: AppTextStyles.caption),
            value: Document.hotelScopeAll,
            groupValue: _hotelScope,
            onChanged: (v) => setState(() => _hotelScope = v!),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text("خاص بفندق واحد"),
            value: Document.hotelScopeSingle,
            groupValue: _hotelScope,
            onChanged: (v) => setState(() => _hotelScope = v!),
          ),
          if (_hotelScope == Document.hotelScopeSingle) ...[
            const Divider(height: 1),
            const SizedBox(height: AppSizes.sm),
            if (_hotels.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: AppSizes.sm), child: Text("لا توجد فنادق مسجَّلة", style: AppTextStyles.caption))
            else
              ..._hotels.map((h) => RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(h.arabicName),
                    value: h.id!,
                    groupValue: _selectedHotelId,
                    onChanged: (v) => setState(() => _selectedHotelId = v),
                  )),
          ],
        ],
      ),
    );
  }

  Widget _buildFilePicker() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("المرفق (PDF أو صورة — اختياري الآن)", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text("صورة"),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text("PDF"),
                ),
              ),
            ],
          ),
          if (_pickedFile != null) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Icon(_pickedFileType == 'pdf' ? Icons.picture_as_pdf : Icons.image, size: 20),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(child: Text(_pickedFile!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      _pickedFile = null;
                      _pickedFileType = null;
                    }),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
