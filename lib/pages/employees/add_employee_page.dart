import 'package:flutter/material.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/formatters/thousands_separator_formatter.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/employee.dart';
import '../../models/hotel.dart';
import '../../repositories/employee_repository.dart';
import '../../services/payroll_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_text_field.dart';

class AddEmployeePage extends StatefulWidget {
  final Hotel hotel;
  final Employee? employee; // إن وُجد، فهذا تعديل لموظف حالي
  const AddEmployeePage({super.key, required this.hotel, this.employee});

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  final _repository = EmployeeRepository();
  final _payrollService = PayrollService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _salaryController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _hiredAt = DateTime.now();
  bool _isLoading = false;

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    if (e != null) {
      _nameController.text = e.name;
      _phoneController.text = e.phone ?? '';
      _positionController.text = e.position;
      _salaryController.text = e.salary == 0 ? '' : e.salary.toStringAsFixed(0);
      _notesController.text = e.notes ?? '';
      _hiredAt = DateTime.tryParse(e.hiredAt) ?? DateTime.now();
    }
  }

  String get _formattedHiredAt =>
      "${_hiredAt.year}-${_hiredAt.month.toString().padLeft(2, '0')}-${_hiredAt.day.toString().padLeft(2, '0')}";

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty || (!_isEdit && _positionController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال الاسم والوظيفة")));
      return;
    }
    if (!mounted) return;
    await AppDialog.confirmAction(
      context: context,
      title: _isEdit ? "تأكيد حفظ التعديلات" : "تأكيد إضافة الموظف",
      message: _isEdit ? "هل تريد حفظ تعديلات بيانات هذا الموظف؟" : "هل تريد إضافة هذا الموظف؟",
      onConfirm: _performSave,
    );
  }

  Future<void> _performSave() async {
    setState(() => _isLoading = true);

    try {
      if (!_isEdit) {
        final employee = Employee(
          hotelId: widget.hotel.id,
          name: _nameController.text.trim(),
          position: _positionController.text.trim(),
          salary: ThousandsSeparatorInputFormatter.parse(_salaryController.text) ?? 0,
          hiredAt: _formattedHiredAt,
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        final id = await _repository.addEmployee(employee);
        // تسجيل حركة "تعيين" في السجل الوظيفي أمر إضافي بعد نجاح حفظ الموظف نفسه؛
        // فشل تسجيلها (نادراً) يجب ألا يمنع اعتبار عملية الإضافة ناجحة.
        try {
          final saved = await _repository.getEmployeeById(id);
          if (saved != null) await _payrollService.hireEmployee(saved);
        } catch (_) {}
      } else {
        // في وضع التعديل: الاسم والجوال والملاحظات فقط يُحفظون مباشرة.
        // الراتب/الوظيفة يُعدَّلان حصراً عبر إجراءات صفحة الموظف (مع تسجيل الحركة).
        final updated = widget.employee!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        await _repository.updateEmployee(updated);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEdit ? "تعديل بيانات الموظف" : "إضافة موظف جديد"),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          const Text("البيانات الأساسية", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.md),
          AppTextField(controller: _nameController, hint: "الاسم", icon: Icons.person_outline),
          const SizedBox(height: AppSizes.md),
          AppTextField(
            controller: _phoneController,
            hint: "رقم الجوال",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSizes.md),
          if (_isEdit) ...[
            _buildReadOnlyField("الوظيفة الحالية", widget.employee!.position, Icons.badge_outlined),
            const SizedBox(height: AppSizes.md),
            _buildReadOnlyField("الراتب الأساسي الحالي", widget.employee!.salary.toStringAsFixed(0), Icons.payments_outlined),
            const SizedBox(height: AppSizes.xs),
            Text(
              "لتعديل الراتب أو الوظيفة استخدم إجراءات صفحة الموظف (تُسجَّل القيمة القديمة والجديدة تلقائياً في سجل الحركة).",
              style: AppTextStyles.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ] else ...[
            AppTextField(controller: _positionController, hint: "الوظيفة", icon: Icons.badge_outlined),
            const SizedBox(height: AppSizes.md),
            _buildDatePicker(identityColor),
            const SizedBox(height: AppSizes.md),
            AppTextField(
              controller: _salaryController,
              hint: "الراتب الأساسي",
              icon: Icons.payments_outlined,
              formatThousands: true,
            ),
          ],
          const SizedBox(height: AppSizes.md),
          AppTextField(controller: _notesController, hint: "ملاحظات (اختياري)", icon: Icons.notes_outlined, maxLines: 3),
          const SizedBox(height: AppSizes.xl),
          AppButton(
            text: _isEdit ? "حفظ التعديلات" : "إضافة الموظف",
            onPressed: _save,
            isLoading: _isLoading,
            backgroundColor: identityColor,
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                Text(value, style: AppTextStyles.bodyBold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(Color identityColor) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _hiredAt,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) setState(() => _hiredAt = date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: identityColor, size: 20),
            const SizedBox(width: AppSizes.sm),
            Text("تاريخ المباشرة: $_formattedHiredAt", style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }
}
