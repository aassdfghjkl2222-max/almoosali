import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import '../../core/app_colors.dart';
import '../../core/app_preferences.dart';
import '../../core/formatters/thousands_separator_formatter.dart';
import '../../core/hotel_visual_identity.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_radius.dart';
import '../../models/hotel.dart';
import '../../models/financial_report.dart';
import '../../models/financial_report_item.dart';
import '../../models/pending_expense.dart';
import '../../models/expense_category.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/financial_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/financial_report_item_repository.dart';
import '../../repositories/vault_repository.dart';
import '../../repositories/shared_expense_repository.dart';
import '../../models/deposited_fund.dart';
import '../../models/shared_expense_share.dart';
import '../../models/daily_report_template.dart';
import '../../services/daily_report_builder.dart';
import '../../services/daily_report_text_renderer.dart';
import '../../services/pdf_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/financial/add_report_item_sheet.dart';
import '../../widgets/financial/funding_source_picker.dart';
import 'manage_report_items_page.dart';
import 'monthly_report_page.dart';
import 'previous_reports_page.dart';
import 'report_preview_page.dart';
import '../expenses/pending_expense_selector.dart';
import '../vault/unposted_funds_page.dart';

/// بند إيراد حر داخل التقرير — إما مُدخَل يدوياً أو مُضاف من كتالوج البنود
/// الدائمة (financial_report_items نوع 'revenue') عبر "➕" بجانب التحويل
/// البنكي. لا يوجد له مفهوم "مصروف معلّق مرحَّل" (خاص بـExpenseItem فقط).
class IncomeItem {
  final TextEditingController nameController;
  final TextEditingController amountController;
  String paymentMethod;

  IncomeItem({required this.nameController, required this.amountController, this.paymentMethod = "نقد"});

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class ExpenseItem {
  final TextEditingController nameController;
  final TextEditingController amountController;
  String paymentMethod;
  final FocusNode nameFocus;
  final FocusNode amountFocus;

  /// غير null فقط للبنود التي أصلها مصروف معلق حقيقي مُرحَّل داخل هذا
  /// التقرير (وليس بنداً حراً أُضيف يدوياً) — راجع _loadReportForDate و
  /// _unpostPendingItem. هذه البنود مقفلة (بلا تعديل مباشر) إلا عبر "إلغاء الترحيل".
  final int? pendingExpenseId;

  /// اسم المورد (لبند "آجل (دين)" فقط) — يُحفَظ كنسخة ثابتة داخل JSON التقرير
  /// حتى بعد أن يختفي المصروف المعلق الأصلي من _availablePendingExpenses (لأنه
  /// أصبح مُرحَّلاً)، ليبقى ظاهراً في نص المشاركة/PDF ("أجل - اسم المورد").
  final String? supplierName;

  ExpenseItem({
    required this.nameController,
    required this.amountController,
    this.paymentMethod = "نقد",
    required this.nameFocus,
    required this.amountFocus,
    this.pendingExpenseId,
    this.supplierName,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    nameFocus.dispose();
    amountFocus.dispose();
  }
}

class FinancialSummaryPage extends StatefulWidget {
  final Hotel hotel;
  final DateTime? initialDate;

  const FinancialSummaryPage({
    super.key,
    required this.hotel,
    this.initialDate,
  });

  @override
  State<FinancialSummaryPage> createState() => _FinancialSummaryPageState();
}

class _FinancialSummaryPageState extends State<FinancialSummaryPage> {
  final _cashController = TextEditingController();
  final _posController = TextEditingController();
  final _transferController = TextEditingController();
  final _parkingCashController = TextEditingController();
  final _parkingPosController = TextEditingController();
  final _subsistenceController = TextEditingController();
  final _refundController = TextEditingController();
  final _cashToPosController = TextEditingController();

  double _increaseAmount = 0;
  String _increaseDesc = "";
  String _increaseSource = "نقد";
  double _shortageAmount = 0;
  String _shortageDesc = "";
  String _shortageSource = "نقد";

  final List<ExpenseItem> _otherExpenses = [];
  final List<IncomeItem> _otherIncomes = [];
  final _reportItemRepository = FinancialReportItemRepository();
  final _cashFocus = FocusNode();
  final _posFocus = FocusNode();
  final _transferFocus = FocusNode();
  final _parkingCashFocus = FocusNode();
  final _parkingPosFocus = FocusNode();
  final _subsistenceFocus = FocusNode();
  final _refundFocus = FocusNode();
  final _cashToPosFocus = FocusNode();

  String _subsistenceMethod = "نقد";
  String _refundMethod = "نقد";
  late DateTime _selectedDate;

  final _expenseRepository = ExpenseRepository();
  List<PendingExpense> _availablePendingExpenses = [];
  final Set<int> _selectedPendingIds = {};

  final _sharedExpenseRepository = SharedExpenseRepository();
  List<SharedExpenseShare> _sharedExpenseShares = [];

  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _totalDebtExpenses = 0;
  double _netCash = 0;
  double _netPos = 0;
  double _finalBalance = 0;

  int? _loadedReportId;
  bool _showTransferField = false;
  bool _showMoreExpenses = false;
  bool _isLocked = false;
  List<Hotel> _otherHotels = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // القاعدة: التاريخ الافتراضي هو اليوم السابق
    _selectedDate = widget.initialDate ?? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    _loadReportForDate(_selectedDate);
    _loadPendingExpenses();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _posController.dispose();
    _transferController.dispose();
    _parkingCashController.dispose();
    _parkingPosController.dispose();
    _subsistenceController.dispose();
    _refundController.dispose();
    _cashToPosController.dispose();
    _cashFocus.dispose();
    _posFocus.dispose();
    _transferFocus.dispose();
    _parkingCashFocus.dispose();
    _parkingPosFocus.dispose();
    _subsistenceFocus.dispose();
    _refundFocus.dispose();
    _cashToPosFocus.dispose();
    for (final e in _otherExpenses) {
      e.dispose();
    }
    for (final i in _otherIncomes) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPendingExpenses() async {
    final expenses = await _expenseRepository.getPendingExpenses(hotelId: widget.hotel.id!, isTransferred: false);
    final hotels = await HotelRepository().getAllHotels();
    if (mounted) {
      setState(() {
        _availablePendingExpenses = expenses;
        _otherHotels = hotels.where((h) => h.id != widget.hotel.id).toList();
      });
    }
  }

  Future<void> _loadReportForDate(DateTime date) async {
    final repository = FinancialRepository();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final reports = await repository.getFinancialReportsInRange(hotelId: widget.hotel.id, startDate: dateStr, endDate: dateStr);
    final sharedShares = await _sharedExpenseRepository.getSharesForHotelAndDate(widget.hotel.id!, dateStr);
    if (mounted) setState(() => _sharedExpenseShares = sharedShares);

    if (reports.isNotEmpty) {
      final report = reports.first;
      if (report.detailsJson != null) {
        final details = jsonDecode(report.detailsJson!);
        final inc = details['income_details'] ?? {};
        final exp = details['expense_details'] ?? {};
        final adj = details['adjustments'] ?? {};

        setState(() {
          _loadedReportId = report.id;
          _cashController.text = _fmtAmount(inc['cash']);
          _posController.text = _fmtAmount(inc['pos']);
          _transferController.text = _fmtAmount(inc['transfer']);
          _parkingCashController.text = _fmtAmount(inc['parking_cash']);
          _parkingPosController.text = _fmtAmount(inc['parking_pos']);
          _subsistenceController.text = _fmtAmount(exp['subsistence']);
          _subsistenceMethod = exp['subsistence_method'] ?? "نقد";
          _refundController.text = _fmtAmount(exp['refund']);
          _refundMethod = exp['refund_method'] ?? "نقد";
          _cashToPosController.text = _fmtAmount(exp['cash_to_pos']);
          _isLocked = report.isLocked;
          _showTransferField = _transferController.text.isNotEmpty && _transferController.text != "0";
          
          _showMoreExpenses = (_refundController.text.isNotEmpty && _refundController.text != "0") || 
                              (_cashToPosController.text.isNotEmpty && _cashToPosController.text != "0") ||
                              (_otherExpenses.isNotEmpty);

          _otherExpenses.clear();
          final others = exp['other'] as List? ?? [];
          for (var item in others) {
            _otherExpenses.add(ExpenseItem(
              nameController: TextEditingController(text: item['name']),
              amountController: TextEditingController(text: _fmtAmount(item['amount'])),
              paymentMethod: item['method'] ?? "نقد",
              nameFocus: FocusNode(), amountFocus: FocusNode(),
              pendingExpenseId: item['is_pending_transferred'] == true ? item['pending_id'] as int? : null,
              supplierName: item['supplier_name'] as String?,
            ));
          }
          if (_otherExpenses.isNotEmpty) _showMoreExpenses = true;

          _otherIncomes.clear();
          final otherIncomes = inc['other_income'] as List? ?? [];
          for (var item in otherIncomes) {
            _otherIncomes.add(IncomeItem(
              nameController: TextEditingController(text: item['name']),
              amountController: TextEditingController(text: _fmtAmount(item['amount'])),
              paymentMethod: item['method'] ?? "نقد",
            ));
          }

          _increaseAmount = double.tryParse(adj['increase']?.toString() ?? '0') ?? 0;
          _increaseSource = adj['increase_effect'] ?? "نقد";
          _increaseDesc = report.increaseDesc ?? "";
          _shortageAmount = double.tryParse(adj['shortage']?.toString() ?? '0') ?? 0;
          _shortageSource = adj['shortage_effect'] ?? "نقد";
          _shortageDesc = report.shortageDesc ?? "";
        });
      }
    } else {
      _loadedReportId = null;
      _clearForm();
    }
    _calculateTotals();
  }

  /// يحوّل قيمة رقمية (أو نصاً رقمياً قديماً بلا فواصل) إلى نص منسَّق
  /// بفاصل آلاف لعرضه في الحقل — يدعم بيانات محفوظة قبل تفعيل التنسيق أيضاً.
  String _fmtAmount(dynamic v) {
    if (v == null) return "";
    final n = v is num ? v : double.tryParse(v.toString().replaceAll(',', ''));
    if (n == null) return v.toString();
    return NumberFormat("#,##0.##").format(n);
  }

  void _clearForm() {
    _cashController.clear(); _posController.clear(); _transferController.clear();
    _parkingCashController.clear(); _parkingPosController.clear();
    _subsistenceController.clear(); _refundController.clear(); _cashToPosController.clear();
    _otherExpenses.clear(); _otherIncomes.clear(); _increaseAmount = 0; _shortageAmount = 0;
    _increaseDesc = ""; _shortageDesc = "";
    _showTransferField = false; _showMoreExpenses = false;
    _isLocked = false;
  }

  void _calculateTotals() {
    double cash = ThousandsSeparatorInputFormatter.parse(_cashController.text) ?? 0;
    double pos = ThousandsSeparatorInputFormatter.parse(_posController.text) ?? 0;
    double transfer = ThousandsSeparatorInputFormatter.parse(_transferController.text) ?? 0;
    double pCash = ThousandsSeparatorInputFormatter.parse(_parkingCashController.text) ?? 0;
    double pPos = ThousandsSeparatorInputFormatter.parse(_parkingPosController.text) ?? 0;
    double sub = ThousandsSeparatorInputFormatter.parse(_subsistenceController.text) ?? 0;
    double ref = ThousandsSeparatorInputFormatter.parse(_refundController.text) ?? 0;
    double c2p = ThousandsSeparatorInputFormatter.parse(_cashToPosController.text) ?? 0;

    double oTotal = 0, oCash = 0, oBank = 0, oDebt = 0;
    void process(double a, String m, {bool isFundedByOtherHotel = false}) {
      oTotal += a;
      // مموَّل من فندق آخر: يُحتسَب ضمن إجمالي المصروفات المعروض فقط، ولا
      // يخصم من النقد/الشبكة ولا يؤثر على صافي الخزنة إطلاقاً (البند خامساً).
      if (isFundedByOtherHotel) return;
      if (m == "نقد" || m == PendingExpense.paymentMethodOwnerDrawing) oCash += a;
      else if (m == "شبكة") oBank += a;
      else oDebt += a;
    }

    for (var i in _otherExpenses) process(ThousandsSeparatorInputFormatter.parse(i.amountController.text) ?? 0, i.paymentMethod);
    for (var e in _availablePendingExpenses) {
      if (_selectedPendingIds.contains(e.id)) process(e.amount, e.paymentMethod, isFundedByOtherHotel: e.isFundedByOtherHotel);
    }

    // بنود الإيراد الحرة — تُضاف إلى صافي النقد/الشبكة حسب مصدرها، أو إلى
    // التحويل مباشرة لأي مصدر آخر (تحويل بنكي وأي مصدر مستقبلي).
    double incOther = 0, incCash = 0, incBank = 0, incTransfer = 0;
    for (var i in _otherIncomes) {
      final a = ThousandsSeparatorInputFormatter.parse(i.amountController.text) ?? 0;
      incOther += a;
      if (i.paymentMethod == "نقد") incCash += a;
      else if (i.paymentMethod == "شبكة") incBank += a;
      else incTransfer += a;
    }

    setState(() {
      _totalIncome = cash + pos + transfer + pCash + pPos + incOther;
      _totalExpenses = sub + ref + oTotal;
      _totalDebtExpenses = oDebt;
      _netCash = (cash + pCash + incCash + (_increaseSource == "نقد" ? _increaseAmount : 0)) -
                 ((_subsistenceMethod == "نقد" ? sub : 0) + (_refundMethod == "نقد" ? ref : 0) + c2p + oCash + (_shortageSource == "نقد" ? _shortageAmount : 0));
      _netPos = (pos + pPos + incBank + (_increaseSource == "شبكة" ? _increaseAmount : 0) + c2p) -
                ((_subsistenceMethod == "شبكة" ? sub : 0) + (_refundMethod == "شبكة" ? ref : 0) + oBank + (_shortageSource == "شبكة" ? _shortageAmount : 0));
      _finalBalance = _netCash + _netPos + transfer + incTransfer;
    });
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    final pTotal = _availablePendingExpenses.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface, size: 20),
        ),
        // أزرار الإجراءات عبر actions الأصلية بدل Row مخصّص داخل title — تفادياً
        // لتجاوز عرض الشاشة (Overflow) على الشاشات الضيقة. أزرار المشاركة الثلاثة
        // مُجمَّعة في قائمة منسدلة واحدة بدل ثلاثة أيقونات منفصلة — يقلّل عدد
        // عناصر actions من 5 إلى 3 (هامش أمان إضافي على الشاشات الصغيرة جداً).
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share, color: Colors.blue, size: 20),
            tooltip: "مشاركة",
            onSelected: (v) {
              if (v == 'text') _shareText();
              if (v == 'copy') _copyReport();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'text', child: Row(children: [Icon(Icons.share, size: 18), SizedBox(width: 8), Text("مشاركة نصية")])),
              PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy, size: 18), SizedBox(width: 8), Text("نسخ التقرير")])),
            ],
          ),
          // زر "مشاركة PDF" منفصل وبارز حسب الطلب — بدل دمجه ضمن القائمة المنسدلة.
          IconButton(onPressed: _sharePdf, icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), tooltip: "مشاركة PDF"),
          IconButton(onPressed: _selectDate, icon: Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary, size: 20)),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface, size: 20),
            onSelected: (v) {
              if (v == 'items') Navigator.push(context, MaterialPageRoute(builder: (_) => ManageReportItemsPage(hotel: widget.hotel)));
              if (v == 'history') Navigator.push(context, MaterialPageRoute(builder: (_) => PreviousReportsPage(hotel: widget.hotel)));
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'items', child: Row(children: [Icon(Icons.tune, size: 18), SizedBox(width: 8), Text("إدارة البنود")])),
              PopupMenuItem(value: 'history', child: Row(children: [Icon(Icons.history, size: 18), SizedBox(width: 8), Text("التقارير السابقة")])),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(identityColor),
      body: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          children: [
            _buildRow2(pTotal),
            const SizedBox(height: AppSizes.md),
            _buildRow3(),
            const SizedBox(height: AppSizes.lg),
            _buildSectionTitle("💰 الإيرادات", color: Colors.green),
            _buildIncomeSection(),
            const SizedBox(height: AppSizes.md),
            _buildSectionTitle("💸 المصروفات", color: AppColors.danger),
            _buildExpenseSection(),
            const SizedBox(height: AppSizes.md),
            _buildAdjustRow(),
            const SizedBox(height: AppSizes.md),
            _buildSectionTitle("📊 ملخص الأرصدة", color: identityColor),
            _buildFinalTotals(),
            const SizedBox(height: AppSizes.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildRow2(double pTotal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              widget.hotel.arabicName,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Theme.of(context).colorScheme.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildPendingIndicator(pTotal),
        ],
      ),
    );
  }

  Widget _buildRow3() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _headerInfoSimple("اليوم", _getDayName(_selectedDate.weekday)),
        _headerInfoSimple("تاريخ التقرير", DateFormat('yyyy/MM/dd').format(_selectedDate)),
      ],
    );
  }

  Widget _headerInfoSimple(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).colorScheme.primary)),
      ],
    );
  }

  Widget _buildPendingIndicator(double total) {
    if (_availablePendingExpenses.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: _showPendingExpensesSelector,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "المصروفات المعلقة",
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    NumberFormat("#,##0.##").format(total),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _availablePendingExpenses.length.toString(),
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(Color color) => Container(
    padding: const EdgeInsets.all(AppSizes.md),
    decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05)))),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "هذا التقرير مقفل (تم الترحيل)",
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        if (!_isLocked && _loadedReportId != null)
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnpostedFundsPage(hotel: widget.hotel))),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "هذا التقرير معتمد وبانتظار الترحيل — عرض الأموال غير المرحلة",
                      style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            if (!_isLocked && _loadedReportId != null) ...[
              IconButton(onPressed: _deleteReport, icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: "حذف التقرير"),
              const SizedBox(width: 8),
            ],
            if (!_isLocked)
              Expanded(child: AppButton(text: "تعيين", onPressed: _reviewReport, icon: Icons.assignment_turned_in_outlined, backgroundColor: color)),
          ],
        ),
      ],
    ),
  );

  Widget _buildSectionTitle(String t, {required Color color}) => Padding(padding: const EdgeInsets.only(bottom: 4, right: 4), child: Text(t, style: AppTextStyles.title.copyWith(color: color, fontSize: 14)));

  Widget _buildIncomeSection() {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.md),
      identityAccent: Theme.of(context).colorScheme.primary,
      child: Column(children: [
      _field("النقد (كاش)", _cashController, Icons.money, _cashFocus, _posFocus),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _field(
              "الشبكة (مدى)", 
              _posController, 
              Icons.credit_card, 
              _posFocus, 
              null,
              onSubmitted: (_) => FocusScope.of(context).requestFocus(_subsistenceFocus),
            )
          ),
          const SizedBox(width: 8),
          _buildTinyActionBtn(
            label: "التحويل البنكي",
            icon: Icons.account_balance,
            onTap: () => setState(() => _showTransferField = !_showTransferField),
            isActive: _showTransferField,
          ),
          if (!_isLocked) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: _addIncomeItem,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: Colors.green)),
                child: const Icon(Icons.add, size: 16, color: Colors.green),
              ),
            ),
          ],
        ],
      ),
      if (_showTransferField) ...[
        const SizedBox(height: 12),
        _field("التحويل البنكي", _transferController, Icons.account_balance, _transferFocus, null),
      ],
      ..._otherIncomes.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(top: 12), child: _buildIncomeRow(e.value, e.key))),
    ]));
  }

  Widget _buildIncomeRow(IncomeItem item, int index) {
    return Column(children: [
      Row(children: [
        Expanded(flex: 2, child: AppTextField(controller: item.nameController, hint: "اسم بند الإيراد", icon: Icons.edit_note, readOnly: _isLocked)),
        const SizedBox(width: 8),
        Expanded(flex: 1, child: AppTextField(controller: item.amountController, hint: "0.00", formatThousands: true, onChanged: (_) => _calculateTotals(), readOnly: _isLocked)),
      ]),
      const SizedBox(height: 4),
      if (!_isLocked)
        Row(children: [
          Flexible(child: _buildFundingSourceChip(item.paymentMethod, (v) => setState(() => item.paymentMethod = v))),
          const Spacer(),
          IconButton(
            onPressed: () { setState(() => _otherIncomes.removeAt(index)); _calculateTotals(); },
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          ),
        ]),
    ]);
  }

  /// "➕" بجانب التحويل البنكي — يفتح النافذة الموحّدة لإضافة بند إيراد (حر
  /// أو من الكتالوج)، ويُضيفه فوراً لهذا التقرير فقط. حفظه بشكل دائم اختياري.
  Future<void> _addIncomeItem() async {
    if (_isLocked) return;
    final result = await showAddReportItemSheet(context, itemType: FinancialReportItem.typeRevenue, hotelId: widget.hotel.id!, otherHotels: _otherHotels);
    if (result == null) return;
    setState(() => _otherIncomes.add(IncomeItem(
          nameController: TextEditingController(text: result.name),
          amountController: TextEditingController(),
          paymentMethod: result.fundingSource,
        )));
    _calculateTotals();
    if (result.savePermanently && await _reportItemRepository.getItemByName(result.name, FinancialReportItem.typeRevenue) == null) {
      await _reportItemRepository.addItem(FinancialReportItem(
        name: result.name,
        type: FinancialReportItem.typeRevenue,
        defaultFundingSource: result.fundingSource,
        sortOrder: 0,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }
  }

  Widget _buildTinyActionBtn({required String label, required IconData icon, required VoidCallback onTap, bool isActive = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? primary.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: isActive ? primary : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? primary : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? primary : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseSection() => AppCard(
    padding: const EdgeInsets.all(AppSizes.md),
    identityAccent: Theme.of(context).colorScheme.primary,
    child: Column(children: [
    _field("الإعاشة", _subsistenceController, Icons.restaurant, _subsistenceFocus, null, m: _subsistenceMethod, onT: (v) => setState(() => _subsistenceMethod = v)),
    
    if (_showMoreExpenses) ...[
      const SizedBox(height: 12),
      _field("تحويل نقد لشبكة", _cashToPosController, Icons.swap_horiz, _cashToPosFocus, null),
      const SizedBox(height: 12),
      _field("الاسترداد", _refundController, Icons.keyboard_return, _refundFocus, null, m: _refundMethod, onT: (v) => setState(() => _refundMethod = v)),
      ..._otherExpenses.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(top: 12), child: _buildDynamicRow(e.value, e.key))),
    ],
    
    const SizedBox(height: 12),
    if (!_showMoreExpenses)
      AppButton(
        text: "إضافة مصروف",
        icon: Icons.add,
        backgroundColor: Colors.grey[100],
        foregroundColor: Colors.grey[800],
        onPressed: () => setState(() => _showMoreExpenses = true),
      )
    else
      Column(
        children: [
           TextButton.icon(onPressed: _addExpense, icon: const Icon(Icons.add_circle_outline, size: 16), label: const Text("بند مصروف مخصص", style: TextStyle(fontSize: 12))),
           TextButton(onPressed: () => setState(() => _showMoreExpenses = false), child: const Text("إخفاء المصاريف الإضافية", style: TextStyle(fontSize: 11, color: Colors.grey))),
        ],
      ),
  ]));

  Widget _buildAdjustRow() {
    bool hasData = _increaseAmount > 0 || _shortageAmount > 0;
    return Column(
      children: [
        Row(children: [
          Expanded(child: _adjustBtn("🟢 زيادة", Colors.green, _increaseAmount, _showIncreasePopup)),
          const SizedBox(width: 12),
          Expanded(child: _adjustBtn("🔴 عجز", Colors.red, _shortageAmount, _showShortagePopup)),
        ]),
        if (hasData) ...[
          const SizedBox(height: 8),
          _buildAdjustSummary(),
        ],
      ],
    );
  }

  Widget _buildAdjustSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          if (_increaseAmount > 0)
            _adjustSummaryItem("زيادة", _increaseAmount, _increaseSource, Colors.green),
          if (_increaseAmount > 0 && _shortageAmount > 0) const Divider(height: 16),
          if (_shortageAmount > 0)
            _adjustSummaryItem("عجز", _shortageAmount, _shortageSource, Colors.red),
        ],
      ),
    );
  }

  Widget _adjustSummaryItem(String label, double amt, String source, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
              TextSpan(text: " ($source)", style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(NumberFormat("#,##0.##").format(amt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _adjustBtn(String l, Color c, double a, VoidCallback o) => InkWell(onTap: o, child: Container(
    padding: const EdgeInsets.all(AppSizes.md),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: a > 0 ? c : Colors.grey.withOpacity(0.2))),
    child: Column(children: [Text(l, style: TextStyle(color: c, fontWeight: FontWeight.bold)), if (a > 0) Text(NumberFormat("#,##0.##").format(a), style: const TextStyle(fontWeight: FontWeight.bold))]),
  ));

  Widget _buildFinalTotals() => AppCard(
    padding: const EdgeInsets.all(AppSizes.md),
    identityAccent: Theme.of(context).colorScheme.primary,
    child: Column(children: [
    _totalRow("صافي النقد", _netCash, Colors.blue),
    if (_totalDebtExpenses > 0) ...[
      const SizedBox(height: 8),
      InkWell(
        onTap: _showDebtExpensesDetails,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
          child: _totalRow("المصروفات المدينة", _totalDebtExpenses, Colors.orange),
        ),
      ),
    ],
    const SizedBox(height: 8),
    _totalRow("صافي الشبكة", _netPos, Colors.purple),
  ]));

  void _showDebtExpensesDetails() {
    Map<String, double> breakdown = {};
    void add(double a, String m) {
      if (m == "نقد" || m == "شبكة" || m == PendingExpense.paymentMethodOwnerDrawing) return;
      breakdown[m] = (breakdown[m] ?? 0) + a;
    }
    for (var i in _otherExpenses) add(double.tryParse(i.amountController.text) ?? 0, i.paymentMethod);
    for (var e in _availablePendingExpenses) if (_selectedPendingIds.contains(e.id)) add(e.amount, e.paymentMethod);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تفاصيل المصروفات المدينة"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: breakdown.entries.map((e) => ListTile(
            title: Text(e.key),
            trailing: Text(NumberFormat("#,##0.##").format(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
          )).toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق"))],
      ),
    );
  }

  Widget _totalRow(String l, double v, Color c) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Expanded(child: Text(l, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
    const SizedBox(width: 8),
    Text(NumberFormat("#,##0.##").format(v), style: TextStyle(fontWeight: FontWeight.bold, color: v < 0 ? Colors.red : c, fontSize: 16)),
  ]);

  Widget _field(String l, TextEditingController c, IconData i, FocusNode? f, FocusNode? n, {String? m, Function(String)? onT, ValueChanged<String>? onSubmitted}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      if (m != null) _smallToggle(m, onT!),
    ]),
    const SizedBox(height: 4),
    AppTextField(controller: c, hint: "0.00", icon: i, focusNode: f, formatThousands: true, onChanged: (_) => _calculateTotals(), onSubmitted: onSubmitted ?? (_) => n != null ? FocusScope.of(context).requestFocus(n) : null, readOnly: _isLocked),
  ]);

  /// تبديل ثنائي بسيط (نقد/شبكة فقط) — يُستخدم حصراً لحقلي "الإعاشة"/"الاسترداد"
  /// اللذين يُحسبان دوماً كخصم فوري من صندوق اليوم (راجع _calculateTotals، لا
  /// يتعامل مع أي قيمة غير نقد/شبكة لهذين الحقلين تحديداً). لاختيار مصدر تمويل
  /// كامل (بما فيه فندق آخر/آجل) راجع _buildFundingSourceChip أدناه.
  Widget _smallToggle(String current, Function(String) onC, {bool locked = false}) {
    if (_isLocked || locked) return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: Colors.grey)),
      child: Text(current, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    const options = ["نقد", "شبكة"];
    const colorMap = {
      "نقد": Colors.green,
      "شبكة": Colors.blue,
    };

    final color = colorMap[current] ?? Colors.grey;
    return InkWell(onTap: () { int idx = options.indexOf(current); if (idx == -1) idx = 0; onC(options[(idx + 1) % options.length]); _calculateTotals(); }, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: color)),
      child: Text(current, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
    ));
  }

  /// شريحة مصدر تمويل كاملة (نقد/شبكة/فندق آخر/شخصي/مسحوبات المالك/آجل (دين)) عبر
  /// النافذة الموحّدة showFundingSourcePicker — تُستخدم للبنود الحرة داخل قسم
  /// المصروفات/الإيرادات (بخلاف _smallToggle الثنائي البسيط للإعاشة/الاسترداد).
  Widget _buildFundingSourceChip(String current, ValueChanged<String> onSelected, {bool locked = false}) {
    if (_isLocked || locked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: Colors.grey)),
        child: Text(current, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    return InkWell(
      onTap: () async {
        final result = await showFundingSourcePicker(context, hotelId: widget.hotel.id!, otherHotels: _otherHotels, allowDeferred: false, allowBankTransfer: true);
        if (result != null) { onSelected(result.paymentMethod); _calculateTotals(); }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: Colors.grey.shade400)),
        child: Text(current, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildDynamicRow(ExpenseItem item, int index) {
    final isPendingLinked = item.pendingExpenseId != null;
    return Column(children: [
      Row(children: [
        Expanded(flex: 2, child: AppTextField(controller: item.nameController, hint: "اسم المصروف", icon: Icons.edit_note, readOnly: _isLocked || isPendingLinked)),
        const SizedBox(width: 8),
        Expanded(flex: 1, child: AppTextField(controller: item.amountController, hint: "0.00", formatThousands: true, onChanged: (_) => _calculateTotals(), readOnly: _isLocked || isPendingLinked)),
      ]),
      if (isPendingLinked)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(Icons.link, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                "من المصروفات المعلقة — مقفل حتى يُلغى ترحيله",
                style: TextStyle(fontSize: 10, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      const SizedBox(height: 4),
      if (!_isLocked)
        Row(children: [
          Flexible(child: _buildFundingSourceChip(item.paymentMethod, (v) => setState(() => item.paymentMethod = v), locked: isPendingLinked)),
          const Spacer(),
          isPendingLinked
              ? TextButton.icon(
                  onPressed: () => _unpostPendingItem(item, index),
                  icon: const Icon(Icons.undo, size: 16, color: Colors.orange),
                  label: const Text("إلغاء ترحيل", style: TextStyle(fontSize: 11, color: Colors.orange)),
                )
              : IconButton(onPressed: () { setState(() => _otherExpenses.removeAt(index)); _calculateTotals(); }, icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
        ]),
    ]);
  }

  void _showIncreasePopup() {
    if (_isLocked) return;
    _showAdjPop("زيادة", _increaseAmount, _increaseDesc, _increaseSource, (a, d, s) => setState(() { _increaseAmount = a; _increaseDesc = d; _increaseSource = s; _calculateTotals(); }));
  }
  
  void _showShortagePopup() {
    if (_isLocked) return;
    _showAdjPop("عجز", _shortageAmount, _shortageDesc, _shortageSource, (a, d, s) => setState(() { _shortageAmount = a; _shortageDesc = d; _shortageSource = s; _calculateTotals(); }));
  }

  void _showAdjPop(String t, double a, String d, String s, Function(double, String, String) onS) {
    final aC = TextEditingController(text: a > 0 ? _fmtAmount(a) : ""); final dC = TextEditingController(text: d); String curS = s;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: Text(t), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: aC, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: const [ThousandsSeparatorInputFormatter()], decoration: InputDecoration(labelText: "المبلغ", suffixIcon: TextButton(onPressed: () => setS(() => curS = curS == "نقد" ? "شبكة" : "نقد"), child: Text(curS)))),
        TextField(controller: dC, decoration: const InputDecoration(labelText: "الوصف")),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")), ElevatedButton(onPressed: () { onS(ThousandsSeparatorInputFormatter.parse(aC.text) ?? 0, dC.text, curS); Navigator.pop(ctx); }, child: const Text("حفظ"))],
    )));
  }

  /// يبني قائمة "المصروفات الأخرى" (الحرة + المصروفات المعلقة المُحدَّدة الآن)
  /// بنفس بنية JSON المخزَّنة دوماً — بما فيها وسم pending_id للبنود التي
  /// أصلها مصروف معلق، حتى تبقى قابلة للتتبع لاحقاً (راجع _unpostPendingItem).
  List<Map<String, dynamic>> _buildOtherExpensesDetails() {
    final otherDetails = _otherExpenses.map((e) => {
      'name': e.nameController.text,
      'amount': ThousandsSeparatorInputFormatter.parse(e.amountController.text) ?? 0,
      'method': e.paymentMethod,
      if (e.pendingExpenseId != null) 'is_pending_transferred': true,
      if (e.pendingExpenseId != null) 'pending_id': e.pendingExpenseId,
      if (e.supplierName != null) 'supplier_name': e.supplierName,
    }).toList();
    for (var e in _availablePendingExpenses) {
      if (_selectedPendingIds.contains(e.id)) {
        otherDetails.add({
          'name': "${e.categoryName}: ${e.statement}",
          'amount': e.amount,
          'method': e.paymentMethod,
          'is_pending_transferred': true,
          'pending_id': e.id!,
          if (e.supplierName != null) 'supplier_name': e.supplierName,
          if (e.isFundedByOtherHotel) 'funding_source_hotel_name': _hotelNameForId(e.fundingSourceHotelId),
        });
      }
    }
    return otherDetails;
  }

  /// اسم فندق من [_otherHotels] بمعرّفه — يُخزَّن حرفياً داخل details_json
  /// عند الحفظ (بدل الاكتفاء بالمعرّف) حتى يبقى التقرير المحفوظ مستقلاً
  /// وقابلاً لإعادة العرض بشكل صحيح حتى لو تغيّر اسم الفندق أو حُذف لاحقاً.
  String _hotelNameForId(int? hotelId) {
    if (hotelId == null) return "فندق آخر";
    for (final h in _otherHotels) {
      if (h.id == hotelId) return h.arabicName;
    }
    if (hotelId == widget.hotel.id) return widget.hotel.arabicName;
    return "فندق آخر";
  }

  /// يبني قائمة بنود الإيراد الحرة بنفس بنية `other` الخاصة بالمصروفات.
  List<Map<String, dynamic>> _buildOtherIncomeDetails() {
    return _otherIncomes.map((i) => {
      'name': i.nameController.text,
      'amount': ThousandsSeparatorInputFormatter.parse(i.amountController.text) ?? 0,
      'method': i.paymentMethod,
    }).toList();
  }

  Future<FinancialReport> _buildReportFromCurrentState() async {
    final repo = FinancialRepository();
    final mainR = await repo.getMainReportForDate(widget.hotel.id!, DateFormat('yyyy-MM-dd').format(_selectedDate));

    return FinancialReport(
      hotelId: widget.hotel.id!, date: DateFormat('yyyy-MM-dd').format(_selectedDate), income: _totalIncome, expenses: _totalExpenses,
      reportType: mainR == null || (mainR.id == _loadedReportId) ? 'main' : 'additional', increaseDesc: _increaseDesc, shortageDesc: _shortageDesc,
      detailsJson: jsonEncode({
        'income_details': {
          'cash': ThousandsSeparatorInputFormatter.parse(_cashController.text) ?? 0,
          'pos': ThousandsSeparatorInputFormatter.parse(_posController.text) ?? 0,
          'transfer': ThousandsSeparatorInputFormatter.parse(_transferController.text) ?? 0,
          'parking_cash': ThousandsSeparatorInputFormatter.parse(_parkingCashController.text) ?? 0,
          'parking_pos': ThousandsSeparatorInputFormatter.parse(_parkingPosController.text) ?? 0,
          'other_income': _buildOtherIncomeDetails(),
        },
        'expense_details': {
          'subsistence': ThousandsSeparatorInputFormatter.parse(_subsistenceController.text) ?? 0,
          'subsistence_method': _subsistenceMethod,
          'refund': ThousandsSeparatorInputFormatter.parse(_refundController.text) ?? 0,
          'refund_method': _refundMethod,
          'cash_to_pos': ThousandsSeparatorInputFormatter.parse(_cashToPosController.text) ?? 0,
          'other': _buildOtherExpensesDetails(),
        },
        'adjustments': {'increase': _increaseAmount, 'shortage': _shortageAmount, 'increase_effect': _increaseSource, 'shortage_effect': _shortageSource},
        'net_cash': _netCash.toStringAsFixed(2), 'net_pos': _netPos.toStringAsFixed(2),
      }),
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  /// يحفظ تقريراً (إنشاء أو تحديث) + صندوقه المودَع المرتبط — الجزء المشترك
  /// بين تأكيد "تعيين" (بعد المعاينة) وبين "إلغاء ترحيل" مصروف من داخل تقرير
  /// محمَّل مسبقاً (يحفظ فوراً بلا معاينة، لأنه تصحيح لا تقرير جديد).
  Future<int> _persistReport(FinancialReport report) async {
    final repo = FinancialRepository();
    final vaultRepo = VaultRepository();
    int rId;

    if (_loadedReportId != null) {
      await repo.updateFinancialReport(report.copyWith(id: _loadedReportId));
      rId = _loadedReportId!;

      final existingFund = await vaultRepo.getDepositedFundByReportId(rId);
      if (existingFund != null) {
        await vaultRepo.updateDepositedFundByReportId(
          existingFund.copyWith(
            cashAmount: _netCash,
            networkAmount: _netPos,
            date: report.date,
          ),
          rId,
        );
      } else {
         await vaultRepo.addDepositedFund(DepositedFund(hotelId: widget.hotel.id!, reportId: rId, date: report.date, cashAmount: _netCash, networkAmount: _netPos));
      }
    } else {
      rId = await repo.addFinancialReport(report);
      await vaultRepo.addDepositedFund(DepositedFund(hotelId: widget.hotel.id!, reportId: rId, date: report.date, cashAmount: _netCash, networkAmount: _netPos));
    }
    return rId;
  }

  Future<void> _reviewReport() async {
    // منع تكرار التقرير في الوضع الرسمي فقط — وضع التجربة يُبقي السلوك القديم
    // (تقرير "إضافي" تلقائي) كما هو تماماً بلا أي تعديل لهذا المسار.
    final trialMode = await AppPreferences.getBool(AppPreferences.keyTrialMode);
    if (!trialMode) {
      final repo = FinancialRepository();
      final mainR = await repo.getMainReportForDate(widget.hotel.id!, DateFormat('yyyy-MM-dd').format(_selectedDate));
      if (mainR != null && mainR.id != _loadedReportId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يوجد تقرير معتمد مسبقاً لهذا الفندق بهذا التاريخ — فعّل \"وضع التجربة\" من الإعدادات إن أردت إنشاء تقرير إضافي.")));
        }
        return;
      }
    }

    final report = await _buildReportFromCurrentState();
    final template = _buildDailyReportTemplate(isAdditional: report.reportType == 'additional');

    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ReportPreviewPage(template: template, onConfirm: () async {
      await _persistReport(report);
      if (_selectedPendingIds.isNotEmpty) await _expenseRepository.transferExpenses(_selectedPendingIds.toList());
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ تم اعتماد التقرير بنجاح — بانتظار الترحيل إلى الخزنة من \"الأموال غير المرحلة\"."),
          duration: Duration(seconds: 4),
        ));
      }
    })));
  }

  /// حذف تقرير لم يُرحَّل بعد (قبل الترحيل فقط — التحقق يتم عبر إخفاء الزر
  /// أصلاً عند _isLocked). يحذف صف financial_reports + صندوقه المودَع
  /// المرتبط معاً، حتى لا يبقى صندوق يتيم في "الأموال غير المرحلة".
  Future<void> _deleteReport() async {
    if (_loadedReportId == null || _isLocked) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("حذف التقرير"),
        content: const Text("هل أنت متأكد من حذف هذا التقرير المالي؟ لم يُرحَّل بعد إلى الخزنة، فلن يتأثر أي رصيد."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("حذف"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final vaultRepo = VaultRepository();
    final fund = await vaultRepo.getDepositedFundByReportId(_loadedReportId!);
    if (fund?.id != null) await vaultRepo.deleteDepositedFund(fund!.id!);
    await FinancialRepository().deleteFinancialReport(_loadedReportId!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حذف التقرير")));
      Navigator.pop(context, true);
    }
  }

  /// "إلغاء ترحيل" مصروف معلق من داخل هذا التقرير — يُزيله من التقرير الحالي
  /// فوراً (يُحفظ التقرير مباشرة بلا معاينة)، ويُعيد المصروف نفسه إلى
  /// المصروفات المعلقة القابلة للتعديل (is_transferred=0). لا يمسّ أي دين
  /// مرتبط به (إن وُجد) — الدين يبقى قائماً حتى يُعدَّل المصروف أو يُحذف صراحة.
  Future<void> _unpostPendingItem(ExpenseItem item, int index) async {
    final pendingId = item.pendingExpenseId;
    if (pendingId == null || _loadedReportId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("إلغاء ترحيل المصروف"),
        content: const Text("سيُزال هذا المصروف من التقرير الحالي فوراً، ويعود إلى المصروفات المعلقة ليصبح قابلاً للتعديل مرة أخرى."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("إلغاء الترحيل", style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _otherExpenses.removeAt(index));
    _calculateTotals();
    await _expenseRepository.untransferExpenses([pendingId]);
    final report = await _buildReportFromCurrentState();
    await _persistReport(report);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إلغاء الترحيل — يمكن تعديل المصروف الآن من المصروفات المعلقة")));
    }
    _loadPendingExpenses();
  }

  void _showPendingExpensesSelector() async {
    if (_isLocked) return;
    final res = await showModalBottomSheet<Set<int>>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => PendingExpenseSelector(currentHotel: widget.hotel, initialSelected: _selectedPendingIds));
    if (res != null) { 
      setState(() { 
        _selectedPendingIds.clear(); 
        _selectedPendingIds.addAll(res); 
      }); 
      _calculateTotals(); 
      _loadPendingExpenses();
    }
  }

  /// "بند مصروف مخصص" — يفتح النافذة الموحّدة لإضافة بند مصروف (حر أو من
  /// الكتالوج)، بدل إضافة صفّ فارغ مباشرة كما كان سابقاً.
  Future<void> _addExpense() async {
    if (_isLocked) return;
    final result = await showAddReportItemSheet(context, itemType: FinancialReportItem.typeExpense, hotelId: widget.hotel.id!, otherHotels: _otherHotels);
    if (result == null) return;
    setState(() => _otherExpenses.add(ExpenseItem(
          nameController: TextEditingController(text: result.name),
          amountController: TextEditingController(),
          paymentMethod: result.fundingSource,
          nameFocus: FocusNode(),
          amountFocus: FocusNode(),
        )));
    _calculateTotals();
    if (result.savePermanently && await _reportItemRepository.getItemByName(result.name, FinancialReportItem.typeExpense) == null) {
      await _reportItemRepository.addItem(FinancialReportItem(
        name: result.name,
        type: FinancialReportItem.typeExpense,
        sortOrder: 0,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }
  }
  
  Future<void> _selectDate() async {
    final DateTime? p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2101), locale: const Locale('ar', 'SA'));
    if (p != null) { _selectedDate = p; _loadReportForDate(p); }
  }

  /// عناصر "مصروفات لم تخصم من خزنة الفندق" — كل بند لم يُسحب من النقد
  /// الفعلي اليوم (نفس تصنيف oDebt في _calculateTotals، ماعدا "شبكة" التي
  /// تُستبعَد من oDebt حسابياً لكنها تُعرَض هنا لأنها ليست نقداً من الخزنة —
  /// تصنيف عرض بحت، بلا أي تغيير على _calculateTotals نفسها). التصنيف نفسه
  /// (classifyUnwithdrawnSource) مشترك مع buildTemplateFromSavedReport حتى
  /// تتطابق "التقارير السابقة" مع هذه الشاشة تماماً.
  List<UnwithdrawnTemplateLine> _collectUnwithdrawnLines() {
    final items = <UnwithdrawnTemplateLine>[];
    void addIfNotCash(String name, double amount, String method, String? supplierName, {String? fundedByHotelName}) {
      if (fundedByHotelName == null && (method == "نقد" || method == PendingExpense.paymentMethodOwnerDrawing)) return;
      final c = classifyUnwithdrawnSource(method, supplierName, fundedByHotelName: fundedByHotelName);
      items.add(UnwithdrawnTemplateLine(icon: c.icon, itemName: name, label: c.label, amount: amount));
    }

    for (final e in _otherExpenses) {
      final amount = ThousandsSeparatorInputFormatter.parse(e.amountController.text) ?? 0;
      addIfNotCash(e.nameController.text, amount, e.paymentMethod, e.supplierName);
    }
    for (final e in _availablePendingExpenses) {
      if (_selectedPendingIds.contains(e.id)) {
        addIfNotCash(
          "${e.categoryName}: ${e.statement}",
          e.amount,
          e.paymentMethod,
          e.isDeferredDebt ? e.supplierName : null,
          fundedByHotelName: e.isFundedByOtherHotel ? _hotelNameForId(e.fundingSourceHotelId) : null,
        );
      }
    }
    return items;
  }

  /// يبني القالب الرسمي الموحّد من الحالة الحالية — بلا أي حساب جديد، فقط
  /// تجميع القيم المحسوبة أصلاً (_totalIncome، _netCash، ...) في بنية عرض
  /// واحدة يستهلكها عرض المعاينة داخل التطبيق ونص المشاركة/النسخ وPDF معاً.
  DailyReportTemplate _buildDailyReportTemplate({bool isAdditional = false}) {
    final sub = ThousandsSeparatorInputFormatter.parse(_subsistenceController.text) ?? 0;
    final ref = ThousandsSeparatorInputFormatter.parse(_refundController.text) ?? 0;
    final transfer = ThousandsSeparatorInputFormatter.parse(_transferController.text) ?? 0;
    double incTransfer = 0;
    for (final i in _otherIncomes) {
      if (i.paymentMethod != "نقد" && i.paymentMethod != "شبكة") {
        incTransfer += ThousandsSeparatorInputFormatter.parse(i.amountController.text) ?? 0;
      }
    }

    final incomeLines = <ReportTemplateLine>[
      ReportTemplateLine(label: "💵 النقد", amount: ThousandsSeparatorInputFormatter.parse(_cashController.text) ?? 0),
      ReportTemplateLine(label: "💳 الشبكة", amount: ThousandsSeparatorInputFormatter.parse(_posController.text) ?? 0),
      ReportTemplateLine(label: "🏦 التحويل البنكي", amount: transfer),
      if (widget.hotel.hasParking) ...[
        ReportTemplateLine(label: "مواقف (نقد)", amount: ThousandsSeparatorInputFormatter.parse(_parkingCashController.text) ?? 0),
        ReportTemplateLine(label: "مواقف (شبكة)", amount: ThousandsSeparatorInputFormatter.parse(_parkingPosController.text) ?? 0),
      ],
      for (final i in _otherIncomes)
        ReportTemplateLine(label: withItemIcon(i.nameController.text), amount: ThousandsSeparatorInputFormatter.parse(i.amountController.text) ?? 0),
    ];

    final expenseLines = <ReportTemplateLine>[
      ReportTemplateLine(label: "🍽️ الإعاشة", amount: sub),
      ReportTemplateLine(label: "↩️ الاسترداد", amount: ref),
      for (final e in _otherExpenses)
        ReportTemplateLine(label: withItemIcon(e.nameController.text), amount: ThousandsSeparatorInputFormatter.parse(e.amountController.text) ?? 0),
      for (final e in _availablePendingExpenses)
        if (_selectedPendingIds.contains(e.id)) ReportTemplateLine(label: withItemIcon("${e.categoryName}: ${e.statement}"), amount: e.amount),
    ];

    final netLines = <ReportTemplateLine>[
      ReportTemplateLine(label: "💼 صافي النقد", amount: _netCash),
      ReportTemplateLine(label: "📊 صافي الشبكة", amount: _netPos),
      ReportTemplateLine(label: "🏦 صافي التحويل البنكي", amount: transfer + incTransfer),
    ];

    return buildDailyReportTemplate(
      hotelName: widget.hotel.arabicName,
      dayName: _getDayName(_selectedDate.weekday),
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      isAdditional: isAdditional,
      rawIncomeLines: incomeLines,
      totalIncome: _totalIncome,
      rawExpenseLines: expenseLines,
      totalExpenses: _totalExpenses,
      rawNetLines: netLines,
      netTotal: _finalBalance,
      unwithdrawnLines: _collectUnwithdrawnLines(),
      sharedExpenseLines: [
        for (final s in _sharedExpenseShares)
          SharedExpenseTemplateLine(
            description: s.groupDescription ?? '',
            fundingHotelName: s.fundingHotelName ?? '',
            amount: s.amount,
            isFundingHotel: s.isFundingHotel,
          ),
      ],
    );
  }

  void _copyReport() async {
    await Clipboard.setData(ClipboardData(text: renderDailyReportAsText(_buildDailyReportTemplate())));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نسخ التقرير")));
  }

  void _shareText() {
    Share.share(renderDailyReportAsText(_buildDailyReportTemplate()));
  }

  Future<void> _sharePdf() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("جاري إنشاء ملف PDF...")));
    await PdfService.shareDailyReportPdf(_buildDailyReportTemplate());
  }

  void _showMonthlyReport() => Navigator.push(context, MaterialPageRoute(builder: (_) => MonthlyReportPage(hotel: widget.hotel, initialDate: _selectedDate)));
  
  String _getDayName(int day) { const names = ["", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"]; return names[day]; }
}
