import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/document.dart';
import '../../../repositories/document_repository.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_dialog.dart';
import '../../../widgets/common/app_text_field.dart';

class DocumentDetailsPage extends StatefulWidget {
  final Document document;

  const DocumentDetailsPage({super.key, required this.document});

  @override
  State<DocumentDetailsPage> createState() => _DocumentDetailsPageState();
}

class _DocumentDetailsPageState extends State<DocumentDetailsPage> {
  late Document _document;
  final DocumentRepository _repository = DocumentRepository();
  late TextEditingController _nameController;
  late TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _nameController = TextEditingController(text: _document.name);
    _dateController = TextEditingController(text: _formatDate(_document.expiryDate));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (e) {
      return dateStr;
    }
  }

  String _getStatusText(int days) {
    if (days < 0) return "منتهي";
    if (days <= 30) return "ينتهي خلال 30 يوماً";
    return "ساري";
  }

  Color _getStatusColor(int days) {
    if (days < 0) return AppColors.danger;
    if (days <= 30) return AppColors.warning;
    return AppColors.success;
  }

  IconData _getStatusIcon(int days) {
    if (days < 0) return Icons.error_outline;
    if (days <= 30) return Icons.warning_amber_rounded;
    return Icons.check_circle_outline;
  }

  Future<void> _selectDate() async {
    // بلا builder مخصص عمداً: منتقي التاريخ يرث ألوانه من ثيم التطبيق
    // الحالي (هوية الفندق) تلقائياً.
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_document.expiryDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final dateStr = picked.toString().split(' ')[0];
      setState(() {
        _dateController.text = _formatDate(dateStr);
        _document = Document(
          id: _document.id,
          hotelId: _document.hotelId,
          name: _document.name,
          expiryDate: dateStr,
          createdAt: _document.createdAt,
        );
      });
    }
  }

  Future<void> _renewDocument() async {
    await _selectDate();
    if (!mounted) return;
    await AppDialog.confirmAction(
      context: context,
      title: "تأكيد التجديد",
      message: "هل تريد تجديد هذا المستند بالتاريخ الجديد؟",
      onConfirm: () async {
        await _repository.updateDocument(_document);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم تجديد المستند بنجاح")),
          );
        }
      },
    );
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال اسم المستند")),
      );
      return;
    }

    if (!mounted) return;
    await AppDialog.confirmAction(
      context: context,
      title: "تأكيد حفظ التعديلات",
      message: "هل تريد حفظ التعديلات على هذا المستند؟",
      onConfirm: () async {
        final updatedDocument = Document(
          id: _document.id,
          hotelId: _document.hotelId,
          name: _nameController.text,
          expiryDate: _document.expiryDate,
          createdAt: _document.createdAt,
        );

        await _repository.updateDocument(updatedDocument);
        setState(() {
          _document = updatedDocument;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم حفظ التعديلات بنجاح")),
          );
        }
      },
    );
  }

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("حذف المستند", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("هل أنت متأكد من حذف هذا المستند نهائياً؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء", style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("حذف", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteDocument(_document.id!);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiry = DateTime.tryParse(_document.expiryDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int daysRemaining = 0;
    if (expiry != null) {
      daysRemaining = expiry.difference(today).inDays;
    }

    final statusText = _getStatusText(daysRemaining);
    final statusColor = _getStatusColor(daysRemaining);
    final statusIcon = _getStatusIcon(daysRemaining);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "تفاصيل المستند",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(statusText, statusColor, statusIcon, daysRemaining),
            const SizedBox(height: AppSizes.lg),
            Text("بيانات المستند", style: AppTextStyles.subtitle.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: AppSizes.md),
            AppCard(
              child: Column(
                children: [
                  _buildInputField(
                    label: "اسم المستند",
                    controller: _nameController,
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: AppSizes.md),
                  _buildDateField(),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            AppButton(
              text: "حفظ التعديلات",
              onPressed: _saveChanges,
              icon: Icons.save,
            ),
            const SizedBox(height: AppSizes.md),
            AppButton(
              text: "تجديد المستند",
              onPressed: _renewDocument,
              icon: Icons.refresh,
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: AppSizes.md),
            AppButton(
              text: "حذف المستند",
              onPressed: _deleteDocument,
              icon: Icons.delete_forever,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.danger,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String text, Color color, IconData icon, int days) {
    return AppCard(
      color: color.withOpacity(0.05),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppTextStyles.title.copyWith(color: color, fontSize: 18),
                ),
                Text(
                  days < 0 ? "منتهي منذ ${days.abs()} يوم" : "متبقي $days يوم على الانتهاء",
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSizes.xs),
        AppTextField(
          controller: controller,
          hint: label,
          icon: icon,
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "تاريخ الانتهاء",
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSizes.xs),
        GestureDetector(
          onTap: _selectDate,
          child: AbsorbPointer(
            child: AppTextField(
              controller: _dateController,
              hint: "اختر التاريخ",
              icon: Icons.calendar_today_outlined,
            ),
          ),
        ),
      ],
    );
  }
}
