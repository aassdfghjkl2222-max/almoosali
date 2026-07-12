import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/employee.dart';
import '../../../models/employee_advance.dart';
import '../../../models/employee_deduction.dart';
import '../../../models/employee_event.dart';
import '../../../models/hotel.dart';
import '../../../models/payroll_record.dart';
import '../../../repositories/employee_repository.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';

/// السجل الكامل لموظف واحد — قراءة فقط. يجمع سجل الحركة الوظيفي (append-only)
/// والرواتب والسلف والخصومات، وكلها بيانات حقيقية من نفس مصادر قسم الموظفين
/// الأصلي، بلا أي إمكانية تعديل أو حذف من هذه الشاشة.
class EmployeeDetailAnalysisPage extends StatefulWidget {
  final Hotel hotel;
  final Employee employee;
  final Color color;

  const EmployeeDetailAnalysisPage({super.key, required this.hotel, required this.employee, required this.color});

  @override
  State<EmployeeDetailAnalysisPage> createState() => _EmployeeDetailAnalysisPageState();
}

class _EmployeeDetailAnalysisPageState extends State<EmployeeDetailAnalysisPage> {
  final _repo = EmployeeRepository();
  bool _isLoading = true;
  List<EmployeeEvent> _events = [];
  List<PayrollRecord> _payroll = [];
  List<EmployeeAdvance> _advances = [];
  List<EmployeeDeduction> _deductions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.employee.id!;
    final results = await Future.wait([
      _repo.getEvents(id),
      _repo.getPayrollRecordsForEmployee(id),
      _repo.getAdvances(id),
      _repo.getDeductions(id),
    ]);
    if (!mounted) return;
    setState(() {
      _events = results[0] as List<EmployeeEvent>;
      _payroll = results[1] as List<PayrollRecord>;
      _advances = results[2] as List<EmployeeAdvance>;
      _deductions = results[3] as List<EmployeeDeduction>;
      _isLoading = false;
    });
  }

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    final e = widget.employee;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: e.name, hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildHeaderCard(),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("سجل الحركة الوظيفي (${_events.length})"),
                const SizedBox(height: AppSizes.sm),
                if (_events.isEmpty) _empty("لا توجد حركات مسجلة") else ..._events.map(_buildEventRow),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("سجل الرواتب (${_payroll.length})"),
                const SizedBox(height: AppSizes.sm),
                if (_payroll.isEmpty) _empty("لا توجد سجلات رواتب") else ..._payroll.map(_buildPayrollRow),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("السلف (${_advances.length})"),
                const SizedBox(height: AppSizes.sm),
                if (_advances.isEmpty) _empty("لا توجد سلف") else ..._advances.map(_buildAdvanceRow),
                const SizedBox(height: AppSizes.lg),
                _buildSectionHeader("الخصومات (${_deductions.length})"),
                const SizedBox(height: AppSizes.sm),
                if (_deductions.isEmpty) _empty("لا توجد خصومات") else ..._deductions.map(_buildDeductionRow),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) => Text(title, style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, fontSize: 15));

  Widget _empty(String msg) => Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(msg, style: AppTextStyles.caption)));

  Widget _buildHeaderCard() {
    final e = widget.employee;
    return AppCard(
      identityAccent: widget.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: widget.color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.badge_outlined, color: widget.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, style: AppTextStyles.title.copyWith(fontSize: 17, color: widget.color)),
                    Text(e.position, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: widget.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(Employee.statusLabel(e.status), style: TextStyle(color: widget.color, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const Divider(height: AppSizes.lg),
          Row(
            children: [
              Expanded(child: _metaStat("الرقم الوظيفي", e.employeeNumber ?? "غير محدد")),
              Expanded(child: _metaStat("الراتب الأساسي", _format(e.salary))),
              Expanded(child: _metaStat("تاريخ التعيين", e.hiredAt)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _buildEventRow(EmployeeEvent ev) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Icon(Icons.history, color: widget.color, size: 20),
        title: Text(EmployeeEvent.typeLabel(ev.eventType), style: AppTextStyles.bodyBold),
        subtitle: Text(
          "${ev.eventDate}${ev.reason != null ? ' · ${ev.reason}' : ''}${ev.performedBy != null ? ' · بواسطة: ${ev.performedBy}' : ''}",
          style: AppTextStyles.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildPayrollRow(PayrollRecord p) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Icon(Icons.payments_outlined, color: widget.color, size: 20),
        title: Text("راتب ${p.period}", style: AppTextStyles.bodyBold),
        subtitle: Text(p.status == 'paid' ? "مصروف" : "معتمد", style: AppTextStyles.caption),
        trailing: Text(_format(p.netSalary), style: AppTextStyles.bodyBold.copyWith(color: widget.color)),
      ),
    );
  }

  Widget _buildAdvanceRow(EmployeeAdvance a) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Icon(Icons.request_quote_outlined, color: widget.color, size: 20),
        title: Text(a.notes?.isNotEmpty == true ? a.notes! : "سلفة", style: AppTextStyles.bodyBold),
        subtitle: Text("${a.date} · ${a.isSettled ? 'مُسدَّدة' : 'غير مسدَّدة'}", style: AppTextStyles.caption),
        trailing: Text(_format(a.amount), style: AppTextStyles.bodyBold.copyWith(color: widget.color)),
      ),
    );
  }

  Widget _buildDeductionRow(EmployeeDeduction d) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: ListTile(
        leading: Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
        title: Text(d.name, style: AppTextStyles.bodyBold),
        subtitle: Text(d.notes ?? '', style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(_format(d.amount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.danger)),
      ),
    );
  }
}
