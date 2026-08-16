import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/hotel_visual_identity.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/app_radius.dart';
import '../../models/hotel.dart';
import '../../models/pending_expense.dart';
import '../../models/advance_withdrawal.dart';
import '../../models/inter_entity_transfer.dart';
import '../../models/financial_account.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/vault_repository.dart';
import '../../repositories/inter_entity_transfer_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../services/financial_engine.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../../widgets/common/trash_confirm_dialogs.dart';
import '../dashboard/widgets/dashboard_section_card.dart';
import 'add_edit_shared_expense_page.dart';
import 'add_inter_entity_transfer_page.dart';
import 'add_owner_withdrawal_page.dart';
import 'add_pending_expense_page.dart';
import 'expense_reports_page.dart';
import 'shared_expense_details_page.dart';

enum _OpCategory { expenses, shared, hotelAdvance, ownerWithdrawal, transfer }

class _CategoryMeta {
  final _OpCategory type;
  final String label;
  final String addLabel;
  final IconData icon;
  final Color color;
  const _CategoryMeta(this.type, this.label, this.addLabel, this.icon, this.color);
}

const _categoryMetas = <_CategoryMeta>[
  _CategoryMeta(_OpCategory.expenses, "المصروفات", "إضافة مصروف", Icons.receipt_long_outlined, Color(0xFF7B1E3A)),
  _CategoryMeta(_OpCategory.shared, "المصروفات المشتركة", "إضافة مصروف مشترك", Icons.call_split, Color(0xFF1E63C7)),
  _CategoryMeta(_OpCategory.hotelAdvance, "عهدة على الفندق", "إضافة عهدة على الفندق", Icons.account_balance_wallet_outlined, Color(0xFF1B8A5A)),
  _CategoryMeta(_OpCategory.ownerWithdrawal, "مسحوبات المالك", "إضافة مسحوب", Icons.person_outline, Color(0xFFB8860B)),
  _CategoryMeta(_OpCategory.transfer, "التحويل بين المنشآت", "إضافة تحويل", Icons.swap_horiz, Color(0xFF6A3EA1)),
];

/// بيانات عرض موحَّدة لبطاقة عملية — تُبنى من أي من النماذج المختلفة لتُعرض
/// ببطاقة واحدة موحَّدة الشكل (راجع _buildOpCard في _CategoryOperationsPage).
class _OpCardData {
  final String statement;
  final String hotelName;
  final String date;
  final String time;
  final String? fundingSource;
  final String status;
  final Color statusColor;
  final double amount;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const _OpCardData({
    required this.statement,
    required this.hotelName,
    required this.date,
    required this.time,
    this.fundingSource,
    required this.status,
    required this.statusColor,
    required this.amount,
    this.onTap,
    this.onDelete,
  });
}

/// الشاشة الرئيسية: قائمة عمودية من 5 بطاقات كبيرة (نفس شكل لوحة تحكم
/// الفندق تماماً — راجع DashboardSectionCard)، كل بطاقة تفتح شاشتها المستقلة
/// (_CategoryOperationsPage) عبر الضغط، بلا أي عرض لقوائم العمليات هنا.
class PendingExpensesListPage extends StatefulWidget {
  final Hotel hotel;
  const PendingExpensesListPage({super.key, required this.hotel});

  @override
  State<PendingExpensesListPage> createState() => _PendingExpensesListPageState();
}

class _PendingExpensesListPageState extends State<PendingExpensesListPage> {
  final _expenseRepo = ExpenseRepository();
  final _vaultRepo = VaultRepository();
  final _transferRepo = InterEntityTransferRepository();
  final _financialEngine = FinancialEngine();

  bool _isLoading = true;
  final Map<_OpCategory, int> _counts = {};
  double _ownerDebt = 0;
  List<FinancialAccount> _receivables = [];
  Map<int, String> _hotelNames = {};

  static const double _largeBalanceThreshold = 50000;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _isLoading = true);
    final hotelId = widget.hotel.id!;

    final allExpenses = await _expenseRepo.getPendingExpenses(hotelId: hotelId, isTransferred: false);
    final ownerWithdrawals = await _vaultRepo.getAdvanceWithdrawals(hotelId);
    final transfers = await _transferRepo.getForHotel(hotelId);
    final ownerDebt = await _financialEngine.getBalance(hotelId, 'owner_debt');
    final receivableAccounts = await _financialEngine.getAccountsByType(hotelId, 'asset');

    if (!mounted) return;
    final legacyOwnerDrawingCount = allExpenses.where((e) => e.isOwnerDrawing).length;
    setState(() {
      _counts[_OpCategory.expenses] = allExpenses.where((e) => !e.isOwnerDrawing && !e.isHotelAdvance && e.sharedExpenseId == null).length;
      _counts[_OpCategory.shared] = allExpenses.where((e) => e.sharedExpenseId != null).length;
      _counts[_OpCategory.hotelAdvance] = allExpenses.where((e) => e.isHotelAdvance).length;
      _counts[_OpCategory.ownerWithdrawal] = ownerWithdrawals.length + legacyOwnerDrawingCount;
      _counts[_OpCategory.transfer] = transfers.where((t) => !t.isTransferred).length;
      _ownerDebt = ownerDebt;
      _receivables = receivableAccounts.where((a) => a.balance > 0.01).toList();
      _isLoading = false;
    });

    final hotelRepo = HotelRepository();
    final hotels = await hotelRepo.getAllHotelsIncludingArchived();
    if (mounted) setState(() => _hotelNames = {for (final h in hotels) if (h.id != null) h.id!: h.arabicName});
  }

  int? _otherHotelIdFromReceivableCategory(String category) {
    if (category.startsWith('receivable_entity_')) {
      return int.tryParse(category.substring('receivable_entity_'.length));
    }
    return null;
  }

  List<String> get _largeBalanceAlerts {
    final format = NumberFormat("#,##0.##");
    final alerts = <String>[];
    if (_ownerDebt > _largeBalanceThreshold) {
      alerts.add("ذمة المالك (مسحوبات مستحقة) كبيرة: ${format.format(_ownerDebt)} ريال");
    }
    for (final acc in _receivables) {
      if (acc.balance <= _largeBalanceThreshold) continue;
      final otherId = _otherHotelIdFromReceivableCategory(acc.category);
      final name = otherId != null ? (_hotelNames[otherId] ?? acc.name) : acc.name;
      alerts.add("ذمة كبيرة مستحقة من $name: ${format.format(acc.balance)} ريال");
    }
    return alerts;
  }

  Future<void> _openCategory(_CategoryMeta meta) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _CategoryOperationsPage(hotel: widget.hotel, meta: meta)),
    );
    if (result == true) _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "العمليات المالية المعلقة", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: "التقارير والإحصائيات",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseReportsPage(hotel: widget.hotel))),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCounts,
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.md),
                children: [
                  if (_largeBalanceAlerts.isNotEmpty) _buildAlertBanner(),
                  for (final meta in _categoryMetas) ...[
                    DashboardSectionCard(
                      icon: meta.icon,
                      title: meta.label,
                      color: meta.color,
                      badgeCount: _counts[meta.type] ?? 0,
                      onTap: () => _openCategory(meta),
                    ),
                    const SizedBox(height: AppSizes.sm),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildAlertBanner() {
    final alerts = _largeBalanceAlerts;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
              SizedBox(width: 6),
              Text("تنبيه: ذمم كبيرة", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          ...alerts.map((a) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text("• $a", style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              )),
        ],
      ),
    );
  }
}

/// شاشة عمليات قسم واحد — تُفتح من إحدى بطاقات [PendingExpensesListPage].
/// نفس منطق البحث/التصفية/بطاقات العمليات المستخدَم سابقاً، لكن لقسم واحد
/// فقط في كل مرة (بدل تبويبات أفقية داخل شاشة واحدة).
class _CategoryOperationsPage extends StatefulWidget {
  final Hotel hotel;
  final _CategoryMeta meta;
  const _CategoryOperationsPage({required this.hotel, required this.meta});

  @override
  State<_CategoryOperationsPage> createState() => _CategoryOperationsPageState();
}

class _CategoryOperationsPageState extends State<_CategoryOperationsPage> {
  final _expenseRepo = ExpenseRepository();
  final _vaultRepo = VaultRepository();
  final _transferRepo = InterEntityTransferRepository();
  final _hotelRepo = HotelRepository();

  bool _isLoading = true;
  bool _changed = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearchBar = false;
  String _sortBy = 'date';

  List<PendingExpense> _expenseRows = [];
  List<AdvanceWithdrawal> _ownerWithdrawalRows = [];
  List<PendingExpense> _legacyOwnerDrawingRows = [];
  List<InterEntityTransfer> _transferRows = [];
  Map<int, String> _hotelNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final hotelId = widget.hotel.id!;
    switch (widget.meta.type) {
      case _OpCategory.expenses:
        final all = await _expenseRepo.getPendingExpenses(hotelId: hotelId, isTransferred: false);
        _expenseRows = all.where((e) => !e.isOwnerDrawing && !e.isHotelAdvance && e.sharedExpenseId == null).toList();
        final hotels = await _hotelRepo.getAllHotelsIncludingArchived();
        _hotelNames = {for (final h in hotels) if (h.id != null) h.id!: h.arabicName};
        break;
      case _OpCategory.shared:
        final all = await _expenseRepo.getPendingExpenses(hotelId: hotelId, isTransferred: false);
        _expenseRows = all.where((e) => e.sharedExpenseId != null).toList();
        break;
      case _OpCategory.hotelAdvance:
        final all = await _expenseRepo.getPendingExpenses(hotelId: hotelId, isTransferred: false);
        _expenseRows = all.where((e) => e.isHotelAdvance).toList();
        break;
      case _OpCategory.ownerWithdrawal:
        _ownerWithdrawalRows = await _vaultRepo.getAdvanceWithdrawals(hotelId);
        final all = await _expenseRepo.getPendingExpenses(hotelId: hotelId, isTransferred: false);
        _legacyOwnerDrawingRows = all.where((e) => e.isOwnerDrawing).toList();
        break;
      case _OpCategory.transfer:
        _transferRows = await _transferRepo.getForHotel(hotelId);
        final hotels = await _hotelRepo.getAllHotelsIncludingArchived();
        _hotelNames = {for (final h in hotels) if (h.id != null) h.id!: h.arabicName};
        break;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  bool _matches(String text) {
    if (_searchQuery.isEmpty) return true;
    return text.toLowerCase().contains(_searchQuery.toLowerCase());
  }

  List<_OpCardData> _buildCards() {
    switch (widget.meta.type) {
      case _OpCategory.expenses:
        return _expenseRows.where((e) => _matches(e.statement) || _matches(e.categoryName ?? '')).map((e) {
          return _OpCardData(
            statement: e.statement,
            hotelName: e.isFundedByOtherHotel
                ? "${widget.hotel.arabicName} (ممول من ${_hotelNames[e.fundingSourceHotelId] ?? '—'})"
                : widget.hotel.arabicName,
            date: e.date,
            time: e.time,
            fundingSource: e.paymentMethod,
            status: "بانتظار الترحيل",
            statusColor: Colors.orange,
            amount: e.amount,
            onTap: () => _editExpense(e),
            onDelete: () => _deletePendingExpense(e),
          );
        }).toList();
      case _OpCategory.shared:
        return _expenseRows.where((e) => _matches(e.statement) || _matches(e.categoryName ?? '')).map((e) {
          return _OpCardData(
            statement: e.statement,
            hotelName: widget.hotel.arabicName,
            date: e.date,
            time: e.time,
            fundingSource: e.paymentMethod,
            status: "بانتظار الترحيل",
            statusColor: Colors.orange,
            amount: e.amount,
            onTap: () async {
              final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => SharedExpenseDetailsPage(sharedExpenseId: e.sharedExpenseId!)));
              if (changed == true) {
                _changed = true;
                _loadData();
              }
            },
          );
        }).toList();
      case _OpCategory.hotelAdvance:
        return _expenseRows.where((e) => _matches(e.statement)).map((e) {
          return _OpCardData(
            statement: e.statement,
            hotelName: widget.hotel.arabicName,
            date: e.date,
            time: e.time,
            fundingSource: "المالك شخصياً",
            status: "بانتظار الترحيل",
            statusColor: Colors.orange,
            amount: e.amount,
            onTap: () => _editExpense(e, lockToHotelAdvance: true),
            onDelete: () => _deletePendingExpense(e),
          );
        }).toList();
      case _OpCategory.ownerWithdrawal:
        final cards = <_OpCardData>[];
        cards.addAll(_ownerWithdrawalRows.where((w) => _matches(w.statement)).map((w) => _OpCardData(
              statement: w.statement,
              hotelName: widget.hotel.arabicName,
              date: w.date,
              time: w.time,
              fundingSource: w.method,
              status: "مُنفَّذ",
              statusColor: Colors.green,
              amount: w.amount,
              onTap: () => _editOwnerWithdrawal(w),
              onDelete: () => _deleteOwnerWithdrawal(w),
            )));
        cards.addAll(_legacyOwnerDrawingRows.where((e) => _matches(e.statement)).map((e) => _OpCardData(
              statement: e.statement,
              hotelName: widget.hotel.arabicName,
              date: e.date,
              time: e.time,
              fundingSource: "نقد",
              status: "بانتظار الترحيل",
              statusColor: Colors.orange,
              amount: e.amount,
              onTap: () => _editExpense(e, lockToOwnerDrawing: true),
              onDelete: () => _deletePendingExpense(e),
            )));
        return cards;
      case _OpCategory.transfer:
        return _transferRows.where((t) => _matches(t.statement)).map((t) {
          final isOutgoing = t.fromHotelId == widget.hotel.id;
          final counterpart = _hotelNames[isOutgoing ? t.toHotelId : t.fromHotelId] ?? '—';
          // معلَّق حتى يُعتمَد تقرير يوم التحويل (راجع دورة الحياة المحاسبية:
          // معلّق ← تقرير يومي ← ترحيل) — لا قيد محاسبي حقيقي بعد، فالبيان
          // للمستقبِل يبقى تحذيرياً بحتاً طالما لم يُعتمَد.
          final pendingNote = "لم يُعتمَد تقرير يوم هذا التحويل بعد — لا أثر محاسبي حقيقي عليه الآن.";
          return _OpCardData(
            statement: t.statement,
            hotelName: isOutgoing ? "إلى: $counterpart" : "من: $counterpart",
            date: t.date,
            time: t.time,
            status: t.isTransferred ? "مُعتمَد" : "بانتظار الترحيل",
            statusColor: t.isTransferred ? Colors.green : Colors.orange,
            amount: t.amount,
            // التعديل/الحذف مسموحان فقط من الفندق المُرسِل وقبل اعتماد التقرير
            // (نفس ما تتحقق منه InterEntityTransferRepository._ensureTransferEditable
            // فعلياً على مستوى طبقة الأعمال — هذا مجرد انعكاس في الواجهة).
            onTap: (isOutgoing && !t.isTransferred)
                ? () => _editTransfer(t)
                : () => _showDetail(
                      "تحويل بين المنشآت",
                      t.statement,
                      t.amount,
                      t.date,
                      t.time,
                      !t.isTransferred
                          ? pendingNote
                          : (isOutgoing
                              ? "أُرسل إلى $counterpart — أصبح $counterpart مديناً لهذا الفندق."
                              : "استُلم من $counterpart — أصبح ${widget.hotel.arabicName} مديناً له."),
                    ),
            onDelete: (isOutgoing && !t.isTransferred) ? () => _deleteTransfer(t) : null,
          );
        }).toList();
    }
  }

  List<_OpCardData> _sortedCards() {
    final cards = _buildCards();
    if (_sortBy == 'amount') {
      cards.sort((a, b) => b.amount.compareTo(a.amount));
    } else {
      cards.sort((a, b) => "${b.date} ${b.time}".compareTo("${a.date} ${a.time}"));
    }
    return cards;
  }

  Future<void> _editOwnerWithdrawal(AdvanceWithdrawal withdrawal) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddOwnerWithdrawalPage(hotel: widget.hotel, editWithdrawal: withdrawal)));
    if (result == true) {
      _changed = true;
      _loadData();
    }
  }

  Future<void> _deleteOwnerWithdrawal(AdvanceWithdrawal withdrawal) async {
    if (!await _confirmDelete("هل أنت متأكد من حذف مسحوب \"${withdrawal.statement}\"؟ سيُعكَس أثره المحاسبي بالكامل.")) return;
    try {
      await _vaultRepo.deleteOwnerWithdrawal(withdrawal);
      _changed = true;
      _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحذف")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('StateError: ', '')), backgroundColor: Colors.red));
    }
  }

  Future<void> _editTransfer(InterEntityTransfer transfer) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddInterEntityTransferPage(hotel: widget.hotel, editTransfer: transfer)));
    if (result == true) {
      _changed = true;
      _loadData();
    }
  }

  Future<void> _deleteTransfer(InterEntityTransfer transfer) async {
    await TrashConfirmDialogs.confirmMoveToTrash(context, () async {
      await _transferRepo.deleteTransfer(transfer);
      _changed = true;
      _loadData();
    });
  }

  Future<void> _editExpense(PendingExpense expense, {bool lockToOwnerDrawing = false, bool lockToHotelAdvance = false}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPendingExpensePage(
          hotel: widget.hotel,
          editExpense: expense,
          lockToOwnerDrawing: lockToOwnerDrawing,
          lockToHotelAdvance: lockToHotelAdvance,
        ),
      ),
    );
    if (result == true) {
      _changed = true;
      _loadData();
    }
  }

  void _showDetail(String title, String statement, double amount, String date, String time, String note) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSizes.sm),
            Text(statement, style: AppTextStyles.body),
            const SizedBox(height: AppSizes.sm),
            Text("${NumberFormat("#,##0.##").format(amount)} ريال", style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("$date $time", style: AppTextStyles.caption),
            const Divider(height: AppSizes.lg),
            Text(note, style: AppTextStyles.caption),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                const Expanded(child: Text("عملية منفَّذة فوراً — بلا إمكانية تعديل من هذه الشاشة.", style: TextStyle(fontSize: 11, color: Colors.grey))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAdd() async {
    bool? result;
    switch (widget.meta.type) {
      case _OpCategory.expenses:
        result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddPendingExpensePage(hotel: widget.hotel)));
        break;
      case _OpCategory.shared:
        result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditSharedExpensePage(initialHotelId: widget.hotel.id)));
        break;
      case _OpCategory.hotelAdvance:
        result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddPendingExpensePage(hotel: widget.hotel, lockToHotelAdvance: true)));
        break;
      case _OpCategory.ownerWithdrawal:
        // مسحوبات المالك أصبحت مصروفاً معلَّقاً عادياً (مصدر تمويل
        // paymentMethodOwnerDrawing) يمر بدورة حياة "معلّق ← تقرير يومي ←
        // ترحيل" الكاملة — لم تعد تُنفَّذ فوراً عبر AddOwnerWithdrawalPage
        // (راجع البند "مسحوبات المالك" من متطلبات إعادة بناء دورة الحياة
        // المحاسبية؛ AddOwnerWithdrawalPage يبقى فقط لعرض/تعديل/حذف سحوبات
        // قديمة نُفِّذت فوراً بالمسار السابق).
        result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddPendingExpensePage(hotel: widget.hotel, lockToOwnerDrawing: true)));
        break;
      case _OpCategory.transfer:
        result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddInterEntityTransferPage(hotel: widget.hotel)));
        break;
    }
    if (result == true) {
      _changed = true;
      _loadData();
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ترتيب حسب", style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSizes.sm),
            RadioListTile<String>(
              value: 'date',
              groupValue: _sortBy,
              title: const Text("التاريخ (الأحدث)"),
              onChanged: (v) {
                setState(() => _sortBy = v!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              value: 'amount',
              groupValue: _sortBy,
              title: const Text("المبلغ (الأعلى)"),
              onChanged: (v) {
                setState(() => _sortBy = v!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: HotelIdentityTitle(title: widget.meta.label, hotel: widget.hotel),
          centerTitle: true,
          backgroundColor: widget.meta.color,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: "بحث",
              onPressed: () => setState(() => _showSearchBar = !_showSearchBar),
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: "تصفية وترتيب",
              onPressed: _openFilterSheet,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: Column(
                  children: [
                    if (_showSearchBar)
                      Padding(
                        padding: const EdgeInsets.all(AppSizes.md),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: "بحث في ${widget.meta.label}...",
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    Expanded(child: _buildList()),
                  ],
                ),
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.sm),
            child: AppButton(
              text: widget.meta.addLabel,
              icon: Icons.add,
              onPressed: _openAdd,
              backgroundColor: widget.meta.color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final cards = _sortedCards();
    if (cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.meta.icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text("لا توجد عمليات في \"${widget.meta.label}\"", style: AppTextStyles.caption),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.md),
      itemCount: cards.length,
      itemBuilder: (context, index) => _buildOpCard(cards[index]),
    );
  }

  Widget _buildOpCard(_OpCardData d) {
    final format = NumberFormat("#,##0.##");
    final accent = widget.meta.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: AppCard(
        identityAccent: accent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: d.onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.statement, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.apartment_outlined, size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Expanded(child: Text(d.hotelName, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text("${d.date} ${d.time}", style: AppTextStyles.caption.copyWith(fontSize: 10)),
                      if (d.fundingSource != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.account_balance_wallet_outlined, size: 12, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(d.fundingSource!, style: AppTextStyles.caption.copyWith(fontSize: 10)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  _statusTag(d.status, d.statusColor),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  format.format(d.amount),
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: accent),
                ),
                if (d.onDelete != null) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: d.onDelete,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// حوار تأكيد موحَّد قبل أي حذف — يُستخدم لكل أنواع العمليات في هذه الشاشة.
  Future<bool> _confirmDelete(String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("تأكيد الحذف"),
        content: Text(message),
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
    return confirmed == true;
  }

  Future<void> _deletePendingExpense(PendingExpense expense) async {
    await TrashConfirmDialogs.confirmMoveToTrash(context, () async {
      await _expenseRepo.deletePendingExpense(expense);
      _changed = true;
      _loadData();
    });
  }
}
