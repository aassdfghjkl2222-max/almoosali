import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/formatters/thousands_separator_formatter.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/employee.dart';
import '../../models/employee_advance.dart';
import '../../models/employee_allowance.dart';
import '../../models/employee_deduction.dart';
import '../../models/employee_document.dart';
import '../../models/employee_event.dart';
import '../../models/hotel.dart';
import '../../models/payroll_record.dart';
import '../../repositories/employee_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../services/payroll_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../common/transaction_review_page.dart';
import 'add_employee_page.dart';

class EmployeeDetailsPage extends StatefulWidget {
  final Hotel hotel;
  final Employee employee;
  const EmployeeDetailsPage({super.key, required this.hotel, required this.employee});

  @override
  State<EmployeeDetailsPage> createState() => _EmployeeDetailsPageState();
}

class _EmployeeDetailsData {
  final Employee employee;
  final SalaryBreakdown breakdown;
  final PayrollRecord? latestPayroll;
  final List<EmployeeAllowance> allowances;
  final List<EmployeeDeduction> deductions;
  final List<EmployeeAdvance> advances;
  final List<EmployeeDocument> documents;
  final List<EmployeeEvent> events;
  final List<PayrollRecord> payrollHistory;
  final List<Hotel> allHotels;
  final List<int> pendingApprovalHotelIds;

  _EmployeeDetailsData({
    required this.employee,
    required this.breakdown,
    required this.latestPayroll,
    required this.allowances,
    required this.deductions,
    required this.advances,
    required this.documents,
    required this.events,
    required this.payrollHistory,
    required this.allHotels,
    required this.pendingApprovalHotelIds,
  });
}

class _MovementEntry {
  final String date;
  final String title;
  final String subtitle;
  final double amount;
  final Color color;
  _MovementEntry({required this.date, required this.title, required this.subtitle, required this.amount, required this.color});
}

class _EmployeeDetailsPageState extends State<EmployeeDetailsPage> with SingleTickerProviderStateMixin {
  final _repository = EmployeeRepository();
  final _hotelRepository = HotelRepository();
  final _payrollService = PayrollService();
  late TabController _tabController;
  late Employee _employee;
  late Future<_EmployeeDetailsData> _future;
  final _fmt = NumberFormat("#,##0.00");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _employee = widget.employee;
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = _loadData();
    });
  }

  Future<_EmployeeDetailsData> _loadData() async {
    final employee = await _repository.getEmployeeById(_employee.id!) ?? _employee;
    _employee = employee;
    final breakdown = await _payrollService.calculateBreakdown(employee);
    final latestPayroll = await _repository.getLatestPayrollForEmployee(employee.id!);
    final allowances = await _repository.getAllowances(employee.id!);
    final deductions = await _repository.getDeductions(employee.id!);
    final advances = await _repository.getAdvances(employee.id!);
    final documents = await _repository.getDocuments(employee.id!);
    final events = await _repository.getEvents(employee.id!);
    final payrollHistory = await _repository.getPayrollRecordsForEmployee(employee.id!);
    final allHotels = await _hotelRepository.getAllHotels();
    final pendingApprovalHotelIds = (await _payrollService.hotelsPendingApprovalThisPeriod(employee))
        .where((id) => id != employee.hotelId)
        .toList();
    return _EmployeeDetailsData(
      employee: employee,
      breakdown: breakdown,
      latestPayroll: latestPayroll,
      allowances: allowances,
      deductions: deductions,
      advances: advances,
      documents: documents,
      events: events,
      payrollHistory: payrollHistory,
      allHotels: allHotels,
      pendingApprovalHotelIds: pendingApprovalHotelIds,
    );
  }

  Color get _identityColor => HotelVisualIdentity.colorForHotel(widget.hotel);

  Hotel? _findHotel(List<Hotel> hotels, int? id) {
    if (id == null) return null;
    for (final h in hotels) {
      if (h.id == id) return h;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: _employee.name, hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: _identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "البيانات الحالية"),
            Tab(text: "سجل الحركة"),
            Tab(text: "الحركة المالية"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: "تعديل البيانات",
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddEmployeePage(hotel: widget.hotel, employee: _employee)),
              );
              if (result == true) _load();
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleLifecycleAction,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'transfer', child: Text("نقل الموظف")),
              const PopupMenuItem(value: 'promote', child: Text("ترقية")),
              const PopupMenuItem(value: 'salary', child: Text("تعديل الراتب")),
              const PopupMenuItem(value: 'position', child: Text("تعديل الوظيفة")),
              if (_employee.status != Employee.statusSuspended)
                const PopupMenuItem(value: 'suspend', child: Text("إيقاف مؤقت")),
              if (_employee.status == Employee.statusSuspended)
                const PopupMenuItem(value: 'return', child: Text("عودة للعمل")),
              const PopupMenuItem(value: 'resign', child: Text("استقالة")),
              const PopupMenuItem(value: 'terminate', child: Text("إنهاء خدمة")),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'archive', child: Text("أرشفة الموظف", style: TextStyle(color: AppColors.danger))),
            ],
          ),
        ],
      ),
      body: FutureBuilder<_EmployeeDetailsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }
          if (snapshot.hasError) {
            return Center(child: Text("حدث خطأ: ${snapshot.error}"));
          }
          final data = snapshot.data!;
          return TabBarView(
            controller: _tabController,
            children: [
              _buildCurrentDataTab(data),
              _buildEventHistoryTab(data),
              _buildFinancialMovementTab(data),
            ],
          );
        },
      ),
    );
  }

  // ========================= التبويب الأول: البيانات الحالية =========================

  Widget _buildCurrentDataTab(_EmployeeDetailsData data) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        _buildProfileCard(data),
        const SizedBox(height: AppSizes.md),
        _buildPayslipCard(data),
        const SizedBox(height: AppSizes.md),
        _buildPayrollActionsCard(data),
        const SizedBox(height: AppSizes.lg),
        _buildDocumentsSection(data.documents),
        const SizedBox(height: AppSizes.lg),
        _buildAllowancesSection(data.allowances),
        const SizedBox(height: AppSizes.lg),
        _buildDeductionsSection(data.deductions),
        const SizedBox(height: AppSizes.lg),
        _buildAdvancesSection(data.advances),
      ],
    );
  }

  Widget _buildProfileCard(_EmployeeDetailsData data) {
    final e = data.employee;
    final currentHotel = _findHotel(data.allHotels, e.hotelId);
    return AppCard(
      identityAccent: _identityColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.position, style: AppTextStyles.bodyBold.copyWith(color: _identityColor)),
                    if (e.employeeNumber != null)
                      Text(e.employeeNumber!, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _buildStatusBadge(e.status),
            ],
          ),
          const Divider(height: AppSizes.lg),
          _buildInfoRow(Icons.phone_outlined, "رقم الجوال", e.phone?.isNotEmpty == true ? e.phone! : "غير مسجل"),
          const SizedBox(height: AppSizes.sm),
          _buildInfoRow(Icons.apartment_outlined, "الفندق الحالي", currentHotel?.arabicName ?? "—"),
          const SizedBox(height: AppSizes.sm),
          _buildInfoRow(Icons.calendar_today_outlined, "تاريخ المباشرة", e.hiredAt),
          if (e.notes?.isNotEmpty == true) ...[
            const SizedBox(height: AppSizes.sm),
            _buildInfoRow(Icons.notes_outlined, "ملاحظات", e.notes!),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case Employee.statusSuspended:
        color = AppColors.warning;
        break;
      case Employee.statusResigned:
      case Employee.statusTerminated:
        color = AppColors.danger;
        break;
      default:
        color = AppColors.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(Employee.statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSizes.sm),
        Text("$label: ", style: AppTextStyles.caption),
        Expanded(child: Text(value, style: AppTextStyles.body)),
      ],
    );
  }

  // ------------------------- كشف الراتب -------------------------

  Widget _buildPayslipCard(_EmployeeDetailsData data) {
    final b = data.breakdown;
    return AppCard(
      color: _identityColor,
      child: Column(
        children: [
          const Text("صافي الراتب الحالي", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            "${_fmt.format(b.netSalary)} ر.س",
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "محسوب على ${b.daysWorked} من ${b.totalDaysInPeriod} يوماً لهذا الشهر",
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const Divider(color: Colors.white24, height: AppSizes.lg),
          _payslipRow("الراتب الأساسي الكامل", b.baseSalary),
          if (b.daysWorked < b.totalDaysInPeriod) _payslipRow("الراتب المستحق (جزئي)", b.proratedBase, positive: true),
          _payslipRow("مجموع البدلات", b.allowancesTotal, positive: true),
          _payslipRow("مجموع الخصومات", -b.deductionsTotal, positive: false),
          _payslipRow("السلف غير المسددة", -b.advancesTotal, positive: false),
        ],
      ),
    );
  }

  Widget _payslipRow(String label, double amount, {bool? positive}) {
    final prefix = amount < 0 ? "-" : (positive == true ? "+" : "");
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text("$prefix${_fmt.format(amount.abs())}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ------------------------- اعتماد وصرف الرواتب -------------------------

  List<PayrollRecord> _otherUnpaidApproved(_EmployeeDetailsData data) {
    return data.payrollHistory.where((p) => p.status == PayrollRecord.statusApproved && p.id != data.latestPayroll?.id).toList();
  }

  Widget _buildPayrollActionsCard(_EmployeeDetailsData data) {
    final payroll = data.latestPayroll;
    final readyToPay = payroll != null && payroll.status == PayrollRecord.statusApproved;

    return AppCard(
      identityAccent: _identityColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (readyToPay) ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                const SizedBox(width: 6),
                Text("راتب ${payroll.period} معتمد وجاهز للصرف (${_fmt.format(payroll.netSalary)} ر.س)", style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
          ] else if (payroll != null && payroll.status == PayrollRecord.statusPaid) ...[
            Row(
              children: [
                const Icon(Icons.history, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text("آخر صرف: ${payroll.period} عبر ${payroll.paymentSource ?? ''} بتاريخ ${(payroll.paidAt ?? '').split('T').first}", style: AppTextStyles.caption)),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: readyToPay ? null : () => _openApprovalReview(data),
                  icon: const Icon(Icons.task_alt),
                  label: const Text("اعتماد الرواتب"),
                  style: OutlinedButton.styleFrom(foregroundColor: _identityColor, side: BorderSide(color: _identityColor)),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: readyToPay ? () => _showPaySalaryDialog(payroll) : null,
                  icon: const Icon(Icons.payments),
                  label: const Text("صرف الراتب"),
                  style: ElevatedButton.styleFrom(backgroundColor: _identityColor, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
          if (data.pendingApprovalHotelIds.isNotEmpty) ...[
            const Divider(height: AppSizes.lg),
            const Text("نتيجة النقل خلال هذا الشهر — يوجد راتب غير معتمد بعد من فندق سابق:", style: AppTextStyles.caption),
            const SizedBox(height: AppSizes.sm),
            ...data.pendingApprovalHotelIds.map((hId) {
              final hotel = _findHotel(data.allHotels, hId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(hotel?.arabicName ?? 'فندق #$hId', style: AppTextStyles.body)),
                    TextButton(
                      onPressed: () => _openApprovalReview(data, overrideHotelId: hId, overrideHotelName: hotel?.arabicName),
                      child: const Text("اعتماد حصته"),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (_otherUnpaidApproved(data).isNotEmpty) ...[
            const Divider(height: AppSizes.lg),
            const Text("رواتب معتمدة بانتظار الصرف من فنادق أخرى:", style: AppTextStyles.caption),
            const SizedBox(height: AppSizes.sm),
            ..._otherUnpaidApproved(data).map((p) {
              final hotel = _findHotel(data.allHotels, p.hotelId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text("${hotel?.arabicName ?? 'فندق #${p.hotelId}'} — ${_fmt.format(p.netSalary)} ر.س", style: AppTextStyles.body)),
                    TextButton(
                      onPressed: () => _showPaySalaryDialog(p),
                      child: const Text("صرف"),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _openApprovalReview(_EmployeeDetailsData data, {int? overrideHotelId, String? overrideHotelName}) async {
    final b = overrideHotelId == null ? data.breakdown : await _payrollService.calculateBreakdown(data.employee, hotelId: overrideHotelId);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionReviewPage(
      title: "مراجعة اعتماد الراتب",
      confirmLabel: "اعتماد الرواتب",
      items: [
        ReviewItem(label: "الفترة", value: PayrollService.currentPeriod(), isHeader: false),
        if (overrideHotelName != null) ReviewItem(label: "الفندق", value: overrideHotelName),
        ReviewItem(label: "أيام العمل الفعلية", value: "${b.daysWorked} من ${b.totalDaysInPeriod} يوماً"),
        ReviewItem(label: "الراتب الأساسي", value: "${_fmt.format(b.baseSalary)} ر.س"),
        ReviewItem(label: "الراتب المستحق عن الفترة", value: "${_fmt.format(b.proratedBase)} ر.س"),
        ReviewItem(label: "مجموع البدلات", value: "+${_fmt.format(b.allowancesTotal)} ر.س", color: AppColors.success),
        ReviewItem(label: "مجموع الخصومات", value: "-${_fmt.format(b.deductionsTotal)} ر.س", color: AppColors.danger),
        ReviewItem(label: "السلف غير المسددة", value: "-${_fmt.format(b.advancesTotal)} ر.س", color: AppColors.warning),
        ReviewItem(label: "صافي الراتب", value: "${_fmt.format(b.netSalary)} ر.س", color: _identityColor, isHeader: false),
      ],
      onConfirm: () async {
        try {
          await _payrollService.approveSalary(data.employee, hotelId: overrideHotelId);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم اعتماد الراتب، وهو الآن جاهز للصرف")));
            _load();
          }
        } on PayrollApprovalException catch (e) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
      },
    )));
  }

  Future<void> _showPaySalaryDialog(PayrollRecord payroll) async {
    bool split = false;
    String singleSource = 'cash';
    final cashController = TextEditingController();
    final bankController = TextEditingController();
    final personalController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLarge))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSizes.md, right: AppSizes.md, top: AppSizes.md,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSizes.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(),
                  Text("صرف الراتب — صافي ${_fmt.format(payroll.netSalary)} ر.س", style: AppTextStyles.bodyBold),
                  const SizedBox(height: AppSizes.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("توزيع بين أكثر من مصدر"),
                    value: split,
                    activeColor: _identityColor,
                    onChanged: (v) => setSheetState(() => split = v),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  if (!split)
                    Wrap(
                      spacing: 8,
                      children: [
                        _sourceChip("نقد", 'cash', singleSource, (v) => setSheetState(() => singleSource = v)),
                        _sourceChip("حساب بنكي", 'bank', singleSource, (v) => setSheetState(() => singleSource = v)),
                        _sourceChip("حساب شخصي", 'personal', singleSource, (v) => setSheetState(() => singleSource = v)),
                      ],
                    )
                  else ...[
                    AppTextField(controller: cashController, hint: "المبلغ من النقد", formatThousands: true),
                    const SizedBox(height: AppSizes.sm),
                    AppTextField(controller: bankController, hint: "المبلغ من الحساب البنكي", formatThousands: true),
                    const SizedBox(height: AppSizes.sm),
                    AppTextField(controller: personalController, hint: "المبلغ من الحساب الشخصي", formatThousands: true),
                  ],
                  const SizedBox(height: AppSizes.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _identityColor, foregroundColor: Colors.white),
                      onPressed: () async {
                        double cash = 0, bank = 0, personal = 0;
                        if (split) {
                          cash = ThousandsSeparatorInputFormatter.parse(cashController.text) ?? 0;
                          bank = ThousandsSeparatorInputFormatter.parse(bankController.text) ?? 0;
                          personal = ThousandsSeparatorInputFormatter.parse(personalController.text) ?? 0;
                        } else if (singleSource == 'cash') {
                          cash = payroll.netSalary;
                        } else if (singleSource == 'bank') {
                          bank = payroll.netSalary;
                        } else {
                          personal = payroll.netSalary;
                        }

                        if ((cash + bank + personal - payroll.netSalary).abs() > 0.01) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(content: Text("مجموع المبالغ الموزعة يجب أن يساوي صافي الراتب بالضبط")),
                          );
                          return;
                        }

                        Navigator.pop(sheetContext);
                        await _paySalary(payroll, cash, bank, personal);
                      },
                      child: const Text("متابعة الصرف"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  Widget _sourceChip(String label, String value, String selected, ValueChanged<String> onSelect) {
    final isSelected = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(value),
      selectedColor: _identityColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
    );
  }

  Future<void> _paySalary(PayrollRecord payroll, double cash, double bank, double personal) async {
    await AppDialog.confirmAction(
      context: context,
      title: "تأكيد صرف الراتب",
      message: "سيتم صرف صافي الراتب (${_fmt.format(payroll.netSalary)} ر.س) وتسجيل الحركة المالية تلقائياً في المركز المالي. هل تريد المتابعة؟",
      onConfirm: () async {
        try {
          await _payrollService.paySalary(
            payroll: payroll,
            employeeName: _employee.name,
            cashAmount: cash,
            bankAmount: bank,
            personalAmount: personal,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم صرف الراتب بنجاح")));
            _load();
          }
        } on PayrollPaymentException catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
    );
  }

  // ------------------------- المستندات -------------------------

  Widget _buildDocumentsSection(List<EmployeeDocument> documents) {
    return _buildListSection(
      title: "المستندات",
      icon: Icons.description_outlined,
      onAdd: _showAddDocumentDialog,
      children: documents.isEmpty
          ? [_emptyHint("لا توجد مستندات مضافة")]
          : documents.map((d) => _buildDocumentItem(d)).toList(),
    );
  }

  Widget _buildDocumentItem(EmployeeDocument d) {
    Color statusColor = AppColors.textSecondary;
    String? statusText;
    if (d.expiryDate != null) {
      final expiry = DateTime.tryParse(d.expiryDate!);
      if (expiry != null) {
        final days = expiry.difference(DateTime.now()).inDays;
        if (days < 0) { statusColor = Colors.black; statusText = "منتهي"; }
        else if (days <= 30) { statusColor = AppColors.warning; statusText = "ينتهي قريباً"; }
        else { statusColor = AppColors.success; statusText = "ساري"; }
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 18, color: _identityColor),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${d.type} — ${d.name}", style: AppTextStyles.body),
                if (d.expiryDate != null) Text("ينتهي: ${d.expiryDate}", style: AppTextStyles.caption),
              ],
            ),
          ),
          if (statusText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  void _showAddDocumentDialog() {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    String type = EmployeeDocument.types.first;
    DateTime? expiry;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("إضافة مستند"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: EmployeeDocument.types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                  decoration: const InputDecoration(labelText: "نوع المستند"),
                ),
                const SizedBox(height: AppSizes.md),
                TextField(controller: nameController, decoration: const InputDecoration(hintText: "اسم/رقم المستند")),
                const SizedBox(height: AppSizes.md),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: dialogContext, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setDialogState(() => expiry = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "تاريخ الانتهاء (اختياري)", border: OutlineInputBorder()),
                    child: Text(expiry == null ? "بدون تاريخ" : "${expiry!.year}-${expiry!.month.toString().padLeft(2, '0')}-${expiry!.day.toString().padLeft(2, '0')}"),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                TextField(controller: notesController, decoration: const InputDecoration(hintText: "ملاحظات (اختياري)")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext);
                AppDialog.confirmAction(
                  context: context,
                  title: "تأكيد إضافة المستند",
                  message: "هل تريد إضافة هذا المستند؟",
                  onConfirm: () async {
                    final expiryStr = expiry == null ? null : "${expiry!.year}-${expiry!.month.toString().padLeft(2, '0')}-${expiry!.day.toString().padLeft(2, '0')}";
                    await _repository.addDocument(EmployeeDocument(
                      employeeId: _employee.id!,
                      type: type,
                      name: nameController.text.trim(),
                      expiryDate: expiryStr,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      createdAt: DateTime.now().toIso8601String(),
                    ));
                    _load();
                  },
                );
              },
              child: const Text("حفظ"),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------- البدلات -------------------------

  Widget _buildAllowancesSection(List<EmployeeAllowance> allowances) {
    return _buildListSection(
      title: "البدلات",
      icon: Icons.add_card_outlined,
      onAdd: _showAddAllowanceDialog,
      children: allowances.isEmpty
          ? [_emptyHint("لا توجد بدلات مضافة")]
          : allowances.map((a) => _buildLineItem(
                title: a.name,
                amount: a.amount,
                amountColor: AppColors.success,
                onDelete: () => _deleteItem(
                  title: "حذف البدل",
                  message: "هل تريد حذف بدل \"${a.name}\"؟",
                  onConfirm: () => _repository.deleteAllowance(a.id!),
                ),
              )).toList(),
    );
  }

  void _showAddAllowanceDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("إضافة بدل"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(hintText: "اسم البدل (سكن، نقل، هاتف...)")),
            const SizedBox(height: AppSizes.md),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(hintText: "القيمة"),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [ThousandsSeparatorInputFormatter()],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext);
              AppDialog.confirmAction(
                context: context,
                title: "تأكيد إضافة البدل",
                message: "هل تريد إضافة هذا البدل؟",
                onConfirm: () async {
                  final name = nameController.text.trim();
                  final amount = ThousandsSeparatorInputFormatter.parse(amountController.text) ?? 0;
                  final now = DateTime.now().toIso8601String();
                  await _repository.addAllowance(EmployeeAllowance(
                    hotelId: widget.hotel.id!,
                    employeeId: _employee.id!,
                    name: name,
                    amount: amount,
                    createdAt: now,
                  ));
                  await _repository.addEvent(EmployeeEvent(
                    employeeId: _employee.id!, hotelId: _employee.hotelId!,
                    eventType: EmployeeEvent.typeAllowanceAdded, eventDate: now.substring(0, 10),
                    newValue: "$name: ${amount.toStringAsFixed(2)}", createdAt: now,
                  ));
                  _load();
                },
              );
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }

  // ------------------------- الخصومات -------------------------

  Widget _buildDeductionsSection(List<EmployeeDeduction> deductions) {
    return _buildListSection(
      title: "الخصومات",
      icon: Icons.remove_circle_outline,
      onAdd: _showAddDeductionDialog,
      children: deductions.isEmpty
          ? [_emptyHint("لا توجد خصومات مضافة")]
          : deductions.map((d) => _buildLineItem(
                title: d.name,
                subtitle: d.notes,
                amount: d.amount,
                amountColor: AppColors.danger,
                onDelete: () => _deleteItem(
                  title: "حذف الخصم",
                  message: "هل تريد حذف خصم \"${d.name}\"؟",
                  onConfirm: () => _repository.deleteDeduction(d.id!),
                ),
              )).toList(),
    );
  }

  void _showAddDeductionDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("إضافة خصم"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(hintText: "اسم الخصم")),
            const SizedBox(height: AppSizes.md),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(hintText: "القيمة"),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [ThousandsSeparatorInputFormatter()],
            ),
            const SizedBox(height: AppSizes.md),
            TextField(controller: notesController, decoration: const InputDecoration(hintText: "ملاحظات (اختياري)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext);
              AppDialog.confirmAction(
                context: context,
                title: "تأكيد إضافة الخصم",
                message: "هل تريد إضافة هذا الخصم؟",
                onConfirm: () async {
                  final name = nameController.text.trim();
                  final amount = ThousandsSeparatorInputFormatter.parse(amountController.text) ?? 0;
                  final now = DateTime.now().toIso8601String();
                  await _repository.addDeduction(EmployeeDeduction(
                    hotelId: widget.hotel.id!,
                    employeeId: _employee.id!,
                    name: name,
                    amount: amount,
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    createdAt: now,
                  ));
                  await _repository.addEvent(EmployeeEvent(
                    employeeId: _employee.id!, hotelId: _employee.hotelId!,
                    eventType: EmployeeEvent.typeDeductionAdded, eventDate: now.substring(0, 10),
                    newValue: "$name: ${amount.toStringAsFixed(2)}", createdAt: now,
                  ));
                  _load();
                },
              );
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }

  // ------------------------- السلف -------------------------

  Widget _buildAdvancesSection(List<EmployeeAdvance> advances) {
    return _buildListSection(
      title: "السلف",
      icon: Icons.account_balance_wallet_outlined,
      onAdd: _showAddAdvanceSheet,
      children: advances.isEmpty
          ? [_emptyHint("لا توجد سلف مسجلة")]
          : advances.map((a) => _buildLineItem(
                title: "${a.date}${a.notes?.isNotEmpty == true ? ' — ${a.notes}' : ''}",
                amount: a.amount,
                amountColor: AppColors.warning,
                trailingBadge: a.isSettled ? "مسددة" : null,
                onDelete: null,
              )).toList(),
    );
  }

  Future<void> _showAddAdvanceSheet() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime date = DateTime.now();
    bool split = false;
    String singleSource = 'cash';
    final cashController = TextEditingController();
    final bankController = TextEditingController();
    final personalController = TextEditingController();
    final entityController = TextEditingController();
    int? entityHotelId;
    final hotels = await _hotelRepository.getAllHotels();
    final otherHotels = hotels.where((h) => h.id != _employee.hotelId).toList();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLarge))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSizes.md, right: AppSizes.md, top: AppSizes.md,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSizes.md,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetHandle(),
                    Text("إضافة سلفة", style: AppTextStyles.bodyBold),
                    const SizedBox(height: AppSizes.md),
                    AppTextField(controller: amountController, hint: "مبلغ السلفة", formatThousands: true),
                    const SizedBox(height: AppSizes.md),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: sheetContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setSheetState(() => date = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: "التاريخ", border: OutlineInputBorder()),
                        child: Text("${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"),
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    TextField(controller: notesController, decoration: const InputDecoration(hintText: "ملاحظات (اختياري)")),
                    const SizedBox(height: AppSizes.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("توزيع بين أكثر من مصدر"),
                      value: split,
                      activeColor: _identityColor,
                      onChanged: (v) => setSheetState(() => split = v),
                    ),
                    if (!split)
                      Wrap(
                        spacing: 8,
                        children: [
                          _sourceChip("نقد", 'cash', singleSource, (v) => setSheetState(() => singleSource = v)),
                          _sourceChip("حساب بنكي", 'bank', singleSource, (v) => setSheetState(() => singleSource = v)),
                          _sourceChip("حساب شخصي", 'personal', singleSource, (v) => setSheetState(() => singleSource = v)),
                          if (otherHotels.isNotEmpty) _sourceChip("منشأة أخرى", 'entity', singleSource, (v) => setSheetState(() => singleSource = v)),
                        ],
                      )
                    else ...[
                      AppTextField(controller: cashController, hint: "من النقد", formatThousands: true),
                      const SizedBox(height: AppSizes.sm),
                      AppTextField(controller: bankController, hint: "من الحساب البنكي", formatThousands: true),
                      const SizedBox(height: AppSizes.sm),
                      AppTextField(controller: personalController, hint: "من الحساب الشخصي", formatThousands: true),
                      if (otherHotels.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.sm),
                        AppTextField(controller: entityController, hint: "من منشأة أخرى", formatThousands: true),
                      ],
                    ],
                    if ((!split && singleSource == 'entity') || (split && entityController.text.isNotEmpty)) ...[
                      const SizedBox(height: AppSizes.sm),
                      DropdownButtonFormField<int>(
                        initialValue: entityHotelId,
                        items: otherHotels.map((h) => DropdownMenuItem(value: h.id, child: Text(h.arabicName))).toList(),
                        onChanged: (v) => setSheetState(() => entityHotelId = v),
                        decoration: const InputDecoration(labelText: "المنشأة الممولة"),
                      ),
                    ],
                    const SizedBox(height: AppSizes.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _identityColor, foregroundColor: Colors.white),
                        onPressed: () async {
                          final amount = ThousandsSeparatorInputFormatter.parse(amountController.text) ?? 0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text("أدخل مبلغاً صحيحاً")));
                            return;
                          }
                          double cash = 0, bank = 0, personal = 0, entity = 0;
                          if (split) {
                            cash = ThousandsSeparatorInputFormatter.parse(cashController.text) ?? 0;
                            bank = ThousandsSeparatorInputFormatter.parse(bankController.text) ?? 0;
                            personal = ThousandsSeparatorInputFormatter.parse(personalController.text) ?? 0;
                            entity = ThousandsSeparatorInputFormatter.parse(entityController.text) ?? 0;
                          } else {
                            switch (singleSource) {
                              case 'cash': cash = amount; break;
                              case 'bank': bank = amount; break;
                              case 'personal': personal = amount; break;
                              case 'entity': entity = amount; break;
                            }
                          }
                          if ((cash + bank + personal + entity - amount).abs() > 0.01) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text("مجموع مصادر التمويل يجب أن يساوي مبلغ السلفة")));
                            return;
                          }
                          if (entity > 0 && entityHotelId == null) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text("يرجى اختيار المنشأة الممولة")));
                            return;
                          }
                          Navigator.pop(sheetContext);
                          await _confirmAddAdvance(
                            amount: amount,
                            date: "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            cash: cash, bank: bank, personal: personal, entity: entity, entityHotelId: entityHotelId,
                          );
                        },
                        child: const Text("متابعة"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAddAdvance({
    required double amount, required String date, String? notes,
    required double cash, required double bank, required double personal, required double entity, int? entityHotelId,
  }) async {
    await AppDialog.confirmAction(
      context: context,
      title: "تأكيد إضافة السلفة",
      message: "سيتم صرف مبلغ السلفة فعلياً من المصادر المحددة وتسجيلها في المركز المالي الآن، ثم خصمها من الراتب عند الاعتماد القادم. هل تريد المتابعة؟",
      onConfirm: () async {
        try {
          await _payrollService.addAdvance(
            employee: _employee, amount: amount, date: date, notes: notes,
            cash: cash, bank: bank, personal: personal, entity: entity, entityHotelId: entityHotelId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تسجيل السلفة وصرفها بنجاح")));
            _load();
          }
        } on AdvanceFundingException catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
    );
  }

  // ========================= التبويب الثاني: سجل الحركة =========================

  Widget _buildEventHistoryTab(_EmployeeDetailsData data) {
    if (data.events.isEmpty) {
      return Center(child: _emptyHint("لا توجد حركات مسجلة بعد"));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: data.events.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.sm),
        child: _buildEventCard(data.events[index]),
      ),
    );
  }

  Widget _buildEventCard(EmployeeEvent event) {
    return AppCard(
      identityAccent: _identityColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(EmployeeEvent.typeLabel(event.eventType), style: AppTextStyles.bodyBold.copyWith(color: _identityColor)),
              Text(event.eventDate, style: AppTextStyles.caption),
            ],
          ),
          if (event.oldValue != null || event.newValue != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (event.oldValue != null) ...[
                  Text(event.oldValue!, style: AppTextStyles.caption.copyWith(decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_back, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                ],
                if (event.newValue != null) Text(event.newValue!, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
              ],
            ),
          ],
          if (event.reason?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text("السبب: ${event.reason}", style: AppTextStyles.caption),
          ],
          if (event.performedBy?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text("بواسطة: ${event.performedBy}", style: AppTextStyles.caption),
          ],
          if (event.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(event.notes!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }

  // ========================= التبويب الثالث: الحركة المالية =========================

  Widget _buildFinancialMovementTab(_EmployeeDetailsData data) {
    final entries = <_MovementEntry>[];

    for (final p in data.payrollHistory) {
      entries.add(_MovementEntry(
        date: p.status == PayrollRecord.statusPaid ? (p.paidAt ?? p.approvedAt).substring(0, 10) : p.approvedAt.substring(0, 10),
        title: "راتب ${p.period}",
        subtitle: p.status == PayrollRecord.statusPaid ? "تم الصرف عبر ${p.paymentSource ?? ''}" : "معتمد بانتظار الصرف",
        amount: p.netSalary,
        color: _identityColor,
      ));
    }
    for (final a in data.advances) {
      entries.add(_MovementEntry(date: a.date, title: "سلفة", subtitle: a.notes ?? '', amount: -a.amount, color: AppColors.warning));
    }
    for (final a in data.allowances) {
      entries.add(_MovementEntry(date: a.createdAt.substring(0, 10), title: "بدل: ${a.name}", subtitle: '', amount: a.amount, color: AppColors.success));
    }
    for (final d in data.deductions) {
      entries.add(_MovementEntry(date: d.createdAt.substring(0, 10), title: "خصم: ${d.name}", subtitle: d.notes ?? '', amount: -d.amount, color: AppColors.danger));
    }

    entries.sort((a, b) => b.date.compareTo(a.date));

    if (entries.isEmpty) {
      return Center(child: _emptyHint("لا توجد حركة مالية بعد"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
          child: AppCard(
            identityAccent: _identityColor,
            padding: const EdgeInsets.all(AppSizes.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: AppTextStyles.bodyBold),
                      if (e.subtitle.isNotEmpty) Text(e.subtitle, style: AppTextStyles.caption),
                      Text(e.date, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Text(
                  "${e.amount < 0 ? '-' : '+'}${_fmt.format(e.amount.abs())}",
                  style: TextStyle(color: e.color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========================= عناصر مشتركة =========================

  Widget _buildListSection({
    required String title,
    required IconData icon,
    required VoidCallback onAdd,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold))),
            TextButton.icon(
              onPressed: onAdd,
              icon: Icon(icon, size: 18, color: _identityColor),
              label: Text("إضافة", style: TextStyle(color: _identityColor)),
            ),
          ],
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          identityAccent: _identityColor,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
    );
  }

  Widget _buildLineItem({
    required String title,
    String? subtitle,
    required double amount,
    required Color amountColor,
    String? trailingBadge,
    VoidCallback? onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body),
                if (subtitle?.isNotEmpty == true) Text(subtitle!, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(_fmt.format(amount), style: TextStyle(color: amountColor, fontWeight: FontWeight.bold)),
          if (trailingBadge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(trailingBadge, style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              onPressed: onDelete,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(right: 4),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteItem({required String title, required String message, required Future<void> Function() onConfirm}) async {
    await AppDialog.confirmAction(
      context: context,
      title: title,
      message: message,
      isDangerous: true,
      onConfirm: () async {
        await onConfirm();
        _load();
      },
    );
  }

  // ========================= إجراءات دورة الحياة =========================

  void _handleLifecycleAction(String action) {
    switch (action) {
      case 'transfer': _showTransferDialog(); break;
      case 'promote': _showPromoteDialog(); break;
      case 'salary': _showChangeSalaryDialog(); break;
      case 'position': _showChangePositionDialog(); break;
      case 'suspend': _showSuspendDialog(); break;
      case 'return': _showReturnDialog(); break;
      case 'resign': _showResignDialog(); break;
      case 'terminate': _showTerminateDialog(); break;
      case 'archive': _showArchiveDialog(); break;
    }
  }

  Future<void> _showTransferDialog() async {
    final hotels = await _hotelRepository.getAllHotels();
    final otherHotels = hotels.where((h) => h.id != _employee.hotelId).toList();
    if (!mounted) return;
    if (otherHotels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد فندق آخر لنقل الموظف إليه")));
      return;
    }
    int? targetHotelId = otherHotels.first.id;
    DateTime date = DateTime.now();
    final reasonController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("نقل الموظف"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: targetHotelId,
                  items: otherHotels.map((h) => DropdownMenuItem(value: h.id, child: Text(h.arabicName))).toList(),
                  onChanged: (v) => setDialogState(() => targetHotelId = v),
                  decoration: const InputDecoration(labelText: "الفندق الجديد"),
                ),
                const SizedBox(height: AppSizes.md),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "تاريخ النقل", border: OutlineInputBorder()),
                    child: Text("${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                TextField(controller: reasonController, decoration: const InputDecoration(hintText: "سبب النقل")),
                const SizedBox(height: AppSizes.md),
                TextField(controller: notesController, decoration: const InputDecoration(hintText: "ملاحظات (اختياري)")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
            TextButton(
              onPressed: () {
                if (targetHotelId == null) return;
                final newHotel = otherHotels.firstWhere((h) => h.id == targetHotelId);
                Navigator.pop(dialogContext);
                AppDialog.confirmAction(
                  context: context,
                  title: "تأكيد نقل الموظف",
                  message: "سيُنقل الموظف إلى \"${newHotel.arabicName}\" اعتباراً من التاريخ المحدد، مع بقاء رقمه الوظيفي وكامل بياناته وسجله. سيُحسب راتب هذا الشهر تلقائياً موزَّعاً بين الفندقين حسب أيام العمل الفعلية. هل تريد المتابعة؟",
                  onConfirm: () async {
                    try {
                      await _payrollService.transferEmployee(
                        employee: _employee, newHotelId: targetHotelId!,
                        oldHotelName: widget.hotel.arabicName, newHotelName: newHotel.arabicName,
                        transferDate: "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
                        reason: reasonController.text.trim().isEmpty ? 'نقل بين الفنادق' : reasonController.text.trim(),
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نقل الموظف بنجاح")));
                        _load();
                      }
                    } on LifecycleException catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                );
              },
              child: const Text("متابعة"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSuspendDialog() async {
    DateTime date = DateTime.now();
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("إيقاف مؤقت"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setDialogState(() => date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "تاريخ بداية الإيقاف", border: OutlineInputBorder()),
                  child: Text("${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              TextField(controller: reasonController, decoration: const InputDecoration(hintText: "السبب")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
            TextButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext);
                AppDialog.confirmAction(
                  context: context,
                  title: "تأكيد الإيقاف المؤقت",
                  message: "سيتم إيقاف الموظف مؤقتاً، وستُخصم أيام الغياب تلقائياً من راتبه عند اعتماد الرواتب. هل تريد المتابعة؟",
                  isDangerous: true,
                  onConfirm: () async {
                    try {
                      await _payrollService.suspendEmployee(
                        employee: _employee,
                        suspendDate: "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
                        reason: reasonController.text.trim(),
                      );
                      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إيقاف الموظف مؤقتاً"))); _load(); }
                    } on LifecycleException catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                );
              },
              child: const Text("متابعة"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReturnDialog() async {
    DateTime date = DateTime.now();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("عودة للعمل"),
          content: InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) setDialogState(() => date = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: "تاريخ العودة", border: OutlineInputBorder()),
              child: Text("${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                AppDialog.confirmAction(
                  context: context,
                  title: "تأكيد العودة للعمل",
                  message: "سيُحتسب راتب الموظف تلقائياً بعد استبعاد أيام الإيقاف عند اعتماد الرواتب القادم. هل تريد المتابعة؟",
                  onConfirm: () async {
                    try {
                      await _payrollService.returnToWork(
                        employee: _employee,
                        returnDate: "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
                      );
                      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تمت إعادة الموظف للعمل"))); _load(); }
                    } on LifecycleException catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                );
              },
              child: const Text("متابعة"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResignDialog() async {
    DateTime date = DateTime.now();
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("تسجيل استقالة"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setDialogState(() => date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "تاريخ الاستقالة", border: OutlineInputBorder()),
                  child: Text("${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              TextField(controller: reasonController, decoration: const InputDecoration(hintText: "ملاحظات (اختياري)")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                AppDialog.confirmAction(
                  context: context,
                  title: "تأكيد الاستقالة",
                  message: "سيُسجَّل هذا الموظف كمستقيل اعتباراً من التاريخ المحدد. هل تريد المتابعة؟",
                  isDangerous: true,
                  onConfirm: () async {
                    await _payrollService.resignEmployee(
                      employee: _employee,
                      date: "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
                      reason: 'استقالة',
                      notes: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                    );
                    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تسجيل الاستقالة"))); _load(); }
                  },
                );
              },
              child: const Text("متابعة"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTerminateDialog() async {
    DateTime date = DateTime.now();
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("إنهاء الخدمة"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setDialogState(() => date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "تاريخ إنهاء الخدمة", border: OutlineInputBorder()),
                  child: Text("${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}"),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              TextField(controller: reasonController, decoration: const InputDecoration(hintText: "السبب (إلزامي)")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
            TextButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext);
                AppDialog.confirmAction(
                  context: context,
                  title: "تأكيد إنهاء الخدمة",
                  message: "سيُنهى عقد هذا الموظف اعتباراً من التاريخ المحدد. هل تريد المتابعة؟",
                  isDangerous: true,
                  onConfirm: () async {
                    await _payrollService.terminateEmployee(
                      employee: _employee,
                      date: "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
                      reason: reasonController.text.trim(),
                    );
                    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إنهاء خدمة الموظف"))); _load(); }
                  },
                );
              },
              child: const Text("متابعة"),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeSalaryDialog() {
    final controller = TextEditingController(text: _employee.salary.toStringAsFixed(0));
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("تعديل الراتب"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "الراتب الجديد"),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [ThousandsSeparatorInputFormatter()],
            ),
            const SizedBox(height: AppSizes.md),
            TextField(controller: reasonController, decoration: const InputDecoration(hintText: "سبب التعديل")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              final newSalary = ThousandsSeparatorInputFormatter.parse(controller.text) ?? 0;
              if (newSalary <= 0) return;
              Navigator.pop(dialogContext);
              AppDialog.confirmAction(
                context: context,
                title: "تأكيد تعديل الراتب",
                message: "سيُحدَّث الراتب الأساسي من ${_fmt.format(_employee.salary)} إلى ${_fmt.format(newSalary)}، وتُسجَّل هذه الحركة في سجل الموظف. هل تريد المتابعة؟",
                onConfirm: () async {
                  await _payrollService.changeSalary(
                    employee: _employee, newSalary: newSalary,
                    reason: reasonController.text.trim().isEmpty ? 'تعديل الراتب' : reasonController.text.trim(),
                  );
                  if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تعديل الراتب"))); _load(); }
                },
              );
            },
            child: const Text("متابعة"),
          ),
        ],
      ),
    );
  }

  void _showChangePositionDialog() {
    final controller = TextEditingController(text: _employee.position);
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("تعديل الوظيفة"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controller, decoration: const InputDecoration(hintText: "الوظيفة الجديدة")),
            const SizedBox(height: AppSizes.md),
            TextField(controller: reasonController, decoration: const InputDecoration(hintText: "سبب التعديل")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(dialogContext);
              AppDialog.confirmAction(
                context: context,
                title: "تأكيد تعديل الوظيفة",
                message: "سيُحدَّث المسمى الوظيفي من \"${_employee.position}\" إلى \"${controller.text.trim()}\"، وتُسجَّل هذه الحركة في سجل الموظف. هل تريد المتابعة؟",
                onConfirm: () async {
                  await _payrollService.changePosition(
                    employee: _employee, newPosition: controller.text.trim(),
                    reason: reasonController.text.trim().isEmpty ? 'تعديل الوظيفة' : reasonController.text.trim(),
                  );
                  if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تعديل الوظيفة"))); _load(); }
                },
              );
            },
            child: const Text("متابعة"),
          ),
        ],
      ),
    );
  }

  void _showPromoteDialog() {
    final positionController = TextEditingController(text: _employee.position);
    final salaryController = TextEditingController();
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("ترقية الموظف"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: positionController, decoration: const InputDecoration(hintText: "المسمى الوظيفي الجديد")),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(hintText: "الراتب الجديد (اختياري)"),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [ThousandsSeparatorInputFormatter()],
              ),
              const SizedBox(height: AppSizes.md),
              TextField(controller: reasonController, decoration: const InputDecoration(hintText: "سبب الترقية")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              if (positionController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext);
              final newSalary = salaryController.text.trim().isEmpty ? null : ThousandsSeparatorInputFormatter.parse(salaryController.text);
              AppDialog.confirmAction(
                context: context,
                title: "تأكيد الترقية",
                message: "سيتم ترقية الموظف إلى \"${positionController.text.trim()}\"${newSalary != null ? ' براتب ${_fmt.format(newSalary)}' : ''}. هل تريد المتابعة؟",
                onConfirm: () async {
                  await _payrollService.promoteEmployee(
                    employee: _employee, newPosition: positionController.text.trim(), newSalary: newSalary,
                    reason: reasonController.text.trim().isEmpty ? 'ترقية' : reasonController.text.trim(),
                  );
                  if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تمت الترقية بنجاح"))); _load(); }
                },
              );
            },
            child: const Text("متابعة"),
          ),
        ],
      ),
    );
  }

  Future<void> _showArchiveDialog() async {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("أرشفة الموظف"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("سيُنقل الموظف إلى الأرشيف مع الاحتفاظ الكامل بسجله. لا يوجد حذف نهائي في النظام."),
            const SizedBox(height: AppSizes.md),
            TextField(controller: reasonController, decoration: const InputDecoration(hintText: "سبب الأرشفة")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext);
              AppDialog.confirmAction(
                context: context,
                title: "تأكيد الأرشفة",
                message: "هل أنت متأكد من أرشفة هذا الموظف؟",
                isDangerous: true,
                onConfirm: () async {
                  await _payrollService.archiveEmployee(employee: _employee, reason: reasonController.text.trim());
                  if (mounted) Navigator.pop(context, true);
                },
              );
            },
            child: const Text("أرشفة", style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
