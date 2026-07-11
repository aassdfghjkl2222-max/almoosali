import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import '../../core/app_colors.dart';
import '../../core/formatters/thousands_separator_formatter.dart';
import '../../core/hotel_visual_identity.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_radius.dart';
import '../../models/hotel.dart';
import '../../models/financial_report.dart';
import '../../models/pending_expense.dart';
import '../../models/expense_category.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/financial_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/vault_repository.dart';
import '../../models/deposited_fund.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../../widgets/common/app_text_field.dart';
import 'monthly_report_page.dart';
import 'report_preview_page.dart';
import '../expenses/pending_expense_selector.dart';

class ExpenseItem {
  final TextEditingController nameController;
  final TextEditingController amountController;
  String paymentMethod;
  final FocusNode nameFocus;
  final FocusNode amountFocus;

  ExpenseItem({
    required this.nameController,
    required this.amountController,
    this.paymentMethod = "نقد",
    required this.nameFocus,
    required this.amountFocus,
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
            ));
          }
          if (_otherExpenses.isNotEmpty) _showMoreExpenses = true;

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
    _otherExpenses.clear(); _increaseAmount = 0; _shortageAmount = 0;
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
    void process(double a, String m) {
      oTotal += a;
      if (m == "نقد" || m == "مصروف خاص") oCash += a;
      else if (m == "شبكة") oBank += a;
      else oDebt += a;
    }

    for (var i in _otherExpenses) process(ThousandsSeparatorInputFormatter.parse(i.amountController.text) ?? 0, i.paymentMethod);
    for (var e in _availablePendingExpenses) if (_selectedPendingIds.contains(e.id)) process(e.amount, e.paymentMethod);

    setState(() {
      _totalIncome = cash + pos + transfer + pCash + pPos;
      _totalExpenses = sub + ref + oTotal;
      _totalDebtExpenses = oDebt;
      _netCash = (cash + pCash + (_increaseSource == "نقد" ? _increaseAmount : 0)) - 
                 ((_subsistenceMethod == "نقد" ? sub : 0) + (_refundMethod == "نقد" ? ref : 0) + c2p + oCash + (_shortageSource == "نقد" ? _shortageAmount : 0));
      _netPos = (pos + pPos + (_increaseSource == "شبكة" ? _increaseAmount : 0) + c2p) - 
                ((_subsistenceMethod == "شبكة" ? sub : 0) + (_refundMethod == "شبكة" ? ref : 0) + oBank + (_shortageSource == "شبكة" ? _shortageAmount : 0));
      _finalBalance = _netCash + _netPos + transfer;
    });
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);
    final pTotal = _availablePendingExpenses.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: _shareText, icon: const Icon(Icons.share, color: Colors.blue, size: 20)),
                IconButton(onPressed: _copyReport, icon: const Icon(Icons.copy, color: Colors.blueGrey, size: 20)),
                IconButton(onPressed: _sharePdf, icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20)),
                IconButton(onPressed: _selectDate, icon: Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary, size: 20)),
              ],
            ),
          ],
        ),
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
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.textPrimary),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat("#,##0.##").format(total),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
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
                Text("هذا التقرير مقفل (تم الترحيل)", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        Row(
          children: [
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
        ],
      ),
      if (_showTransferField) ...[
        const SizedBox(height: 12),
        _field("التحويل البنكي", _transferController, Icons.account_balance, _transferFocus, null),
      ],
    ]));
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text("($source)", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
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
      if (m == "نقد" || m == "شبكة" || m == "مصروف خاص") return;
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
    Text(l, style: const TextStyle(fontSize: 13)),
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

  Widget _smallToggle(String current, Function(String) onC) {
    if (_isLocked) return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: Colors.grey)),
      child: Text(current, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
    final List<String> options = ["نقد", "شبكة"];
    for (var h in _otherHotels) {
      options.add(h.arabicName);
    }
    options.addAll(["شخصي", "مصروف خاص"]);

    final Map<String, Color> colorMap = {
      "نقد": Colors.green,
      "شبكة": Colors.blue,
      "شخصي": Colors.purple,
      "مصروف خاص": Colors.indigo,
    };
    for (var h in _otherHotels) {
      colorMap[h.arabicName] = Colors.deepOrange;
    }

    final color = colorMap[current] ?? Colors.grey;
    return InkWell(onTap: () { int idx = options.indexOf(current); if (idx == -1) idx = 0; onC(options[(idx + 1) % options.length]); _calculateTotals(); }, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: color)),
      child: Text(current, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    ));
  }

  Widget _buildDynamicRow(ExpenseItem item, int index) => Column(children: [
    Row(children: [
      Expanded(flex: 2, child: AppTextField(controller: item.nameController, hint: "اسم المصروف", icon: Icons.edit_note, readOnly: _isLocked)),
      const SizedBox(width: 8),
      Expanded(flex: 1, child: AppTextField(controller: item.amountController, hint: "0.00", formatThousands: true, onChanged: (_) => _calculateTotals(), readOnly: _isLocked)),
    ]),
    const SizedBox(height: 4),
    if (!_isLocked)
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _smallToggle(item.paymentMethod, (v) => setState(() => item.paymentMethod = v)),
        IconButton(onPressed: () { setState(() => _otherExpenses.removeAt(index)); _calculateTotals(); }, icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
      ]),
  ]);

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

  Future<void> _reviewReport() async {
    final otherDetails = _otherExpenses.map((e) => {'name': e.nameController.text, 'amount': ThousandsSeparatorInputFormatter.parse(e.amountController.text) ?? 0, 'method': e.paymentMethod}).toList();
    for (var e in _availablePendingExpenses) if (_selectedPendingIds.contains(e.id)) otherDetails.add({'name': "${e.categoryName}: ${e.statement}", 'amount': e.amount, 'method': e.paymentMethod, 'is_pending_transferred': true, 'pending_id': e.id!});

    final repo = FinancialRepository();
    final mainR = await repo.getMainReportForDate(widget.hotel.id!, DateFormat('yyyy-MM-dd').format(_selectedDate));
    
    final report = FinancialReport(
      hotelId: widget.hotel.id!, date: DateFormat('yyyy-MM-dd').format(_selectedDate), income: _totalIncome, expenses: _totalExpenses, 
      reportType: mainR == null || (mainR.id == _loadedReportId) ? 'main' : 'additional', increaseDesc: _increaseDesc, shortageDesc: _shortageDesc,
      detailsJson: jsonEncode({
        'income_details': {
          'cash': ThousandsSeparatorInputFormatter.parse(_cashController.text) ?? 0,
          'pos': ThousandsSeparatorInputFormatter.parse(_posController.text) ?? 0,
          'transfer': ThousandsSeparatorInputFormatter.parse(_transferController.text) ?? 0,
          'parking_cash': ThousandsSeparatorInputFormatter.parse(_parkingCashController.text) ?? 0,
          'parking_pos': ThousandsSeparatorInputFormatter.parse(_parkingPosController.text) ?? 0,
        },
        'expense_details': {
          'subsistence': ThousandsSeparatorInputFormatter.parse(_subsistenceController.text) ?? 0,
          'subsistence_method': _subsistenceMethod,
          'refund': ThousandsSeparatorInputFormatter.parse(_refundController.text) ?? 0,
          'refund_method': _refundMethod,
          'cash_to_pos': ThousandsSeparatorInputFormatter.parse(_cashToPosController.text) ?? 0,
          'other': otherDetails,
        },
        'adjustments': {'increase': _increaseAmount, 'shortage': _shortageAmount, 'increase_effect': _increaseSource, 'shortage_effect': _shortageSource},
        'net_cash': _netCash.toStringAsFixed(2), 'net_pos': _netPos.toStringAsFixed(2),
      }),
      createdAt: DateTime.now().toIso8601String(),
    );

    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ReportPreviewPage(hotel: widget.hotel, report: report, detailedData: jsonDecode(report.detailsJson!), onConfirm: () async {
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

      if (_selectedPendingIds.isNotEmpty) await _expenseRepository.transferExpenses(_selectedPendingIds.toList());
      if (mounted) { Navigator.pop(context); Navigator.pop(context, true); }
    })));
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

  void _addExpense() {
    if (_isLocked) return;
    setState(() => _otherExpenses.add(ExpenseItem(nameController: TextEditingController(), amountController: TextEditingController(), nameFocus: FocusNode(), amountFocus: FocusNode())));
  }
  
  Future<void> _selectDate() async {
    final DateTime? p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2101), locale: const Locale('ar', 'SA'));
    if (p != null) { _selectedDate = p; _loadReportForDate(p); }
  }

  void _copyReport() async {
    final t = "تقرير فندق ${widget.hotel.arabicName}\nالتاريخ: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}\nإجمالي الإيراد: $_totalIncome\nإجمالي المصروف: $_totalExpenses\nصافي النقد: $_netCash\nصافي الشبكة: $_netPos";
    await Clipboard.setData(ClipboardData(text: t));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم نسخ التقرير")));
  }

  void _shareText() {
     final t = "تقرير فندق ${widget.hotel.arabicName}\nالتاريخ: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}\nإجمالي الإيراد: $_totalIncome\nإجمالي المصروف: $_totalExpenses\nصافي النقد: $_netCash\nصافي الشبكة: $_netPos";
     Share.share(t);
  }

  Future<void> _sharePdf() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("جاري إنشاء ملف PDF...")));
  }

  void _showMonthlyReport() => Navigator.push(context, MaterialPageRoute(builder: (_) => MonthlyReportPage(hotel: widget.hotel, initialDate: _selectedDate)));
  
  String _getDayName(int day) { const names = ["", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"]; return names[day]; }
}
