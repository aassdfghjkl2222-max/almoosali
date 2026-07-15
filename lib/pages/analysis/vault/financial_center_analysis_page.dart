import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../models/deposited_fund.dart';
import '../../../models/entity_loan.dart';
import '../../../models/financial_account.dart';
import '../../../models/hotel.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../repositories/supplier_repository.dart';
import '../../../repositories/vault_repository.dart';
import '../../../services/financial_engine.dart';
import '../../../widgets/common/app_card.dart';
import '../cash_movements_list_page.dart';

class _CategoryData {
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final VoidCallback onTap;
  const _CategoryData(this.title, this.icon, this.color, this.value, this.onTap);
}

/// قسم "المركز المالي" داخل مركز التحليل — قراءة فقط. يجمع كل بنود المركز
/// المالي (نقد/بنك/حسابات شخصية/أموال معلقة/قروض/أصول/التزامات) بأرصدة
/// حقيقية من FinancialEngine وVaultRepository، بلا أي تعديل أو ترحيل.
class FinancialCenterAnalysisPage extends StatefulWidget {
  final Hotel hotel;
  const FinancialCenterAnalysisPage({super.key, required this.hotel});

  @override
  State<FinancialCenterAnalysisPage> createState() => _FinancialCenterAnalysisPageState();
}

class _FinancialCenterAnalysisPageState extends State<FinancialCenterAnalysisPage> {
  final _engine = FinancialEngine();
  final _vaultRepo = VaultRepository();
  final _supplierRepo = SupplierRepository();

  bool _isLoading = true;
  List<Hotel> _allHotels = [];
  Set<int> _selectedHotelIds = {};

  double _cashBalance = 0, _bankBalance = 0;
  List<FinancialAccount> _personalAccounts = [];
  List<DepositedFund> _pendingFunds = [];
  List<EntityLoan> _loans = [];
  List<FinancialAccount> _assets = [];
  List<FinancialAccount> _liabilities = [];
  double _accountsPayableTotal = 0;
  List<Map<String, dynamic>> _suppliersWithDebt = [];

  @override
  void initState() {
    super.initState();
    _selectedHotelIds = widget.hotel.id != null ? {widget.hotel.id!} : {};
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _allHotels = await HotelRepository().getAllHotels();
    final hotelIds = _selectedHotelIds.toList();

    double cash = 0, bank = 0;
    final personal = <FinancialAccount>[];
    final pending = <DepositedFund>[];
    final loans = <EntityLoan>[];
    final assets = <FinancialAccount>[];
    final liabilities = <FinancialAccount>[];
    double payableTotal = 0;
    final suppliersWithDebt = <Map<String, dynamic>>[];

    for (final id in hotelIds) {
      cash += await _engine.getBalance(id, 'cash');
      bank += await _engine.getBalance(id, 'bank');

      final hotelAssets = await _engine.getAccountsByType(id, 'asset');
      final hotelLiabilities = await _engine.getAccountsByType(id, 'liability');
      assets.addAll(hotelAssets);
      liabilities.addAll(hotelLiabilities);
      personal.addAll(hotelLiabilities.where((a) => a.category == 'personal'));
      personal.addAll(hotelAssets.where((a) => a.category.startsWith('person_')));

      final funds = await _vaultRepo.getDepositedFunds(hotelId: id, isArchived: false);
      pending.addAll(funds.where((f) => f.cashStatus == 'pending' || f.networkStatus == 'pending'));

      loans.addAll(await _vaultRepo.getEntityLoans(id));

      payableTotal += await _supplierRepo.getAccountsPayableTotal(id);
      final suppliers = await _supplierRepo.getSuppliersWithOutstandingDebt(id);
      for (final s in suppliers) {
        suppliersWithDebt.add({...s, 'hotel_id': id});
      }
    }

    if (!mounted) return;
    setState(() {
      _cashBalance = cash;
      _bankBalance = bank;
      _personalAccounts = personal;
      _pendingFunds = pending;
      _loans = loans;
      _assets = assets;
      _liabilities = liabilities;
      _accountsPayableTotal = payableTotal;
      _suppliersWithDebt = suppliersWithDebt;
      _isLoading = false;
    });
  }

  Color get _identityColor {
    if (_selectedHotelIds.length == 1) {
      final h = _allHotels.firstWhere((h) => h.id == _selectedHotelIds.first, orElse: () => widget.hotel);
      return HotelVisualIdentity.colorForHotel(h);
    }
    return AppColors.primary;
  }

  Hotel _hotelFor(int? id) => _allHotels.firstWhere((h) => h.id == id, orElse: () => widget.hotel);
  Map<int, String> get _hotelNames => {for (final h in _allHotels) if (h.id != null) h.id!: h.arabicName};
  String _format(double v) => NumberFormat("#,##0.##").format(v);

  Future<void> _openHotelSelector() async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) {
        Set<int> temp = Set.from(_selectedHotelIds);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final allSelected = _allHotels.isNotEmpty && temp.length == _allHotels.length;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("اختيار الفنادق", style: AppTextStyles.title.copyWith(fontSize: 18)),
                    const SizedBox(height: AppSizes.sm),
                    CheckboxListTile(
                      title: const Text("جميع الفنادق", style: TextStyle(fontWeight: FontWeight.bold)),
                      value: allSelected,
                      onChanged: (v) => setSheetState(() {
                        temp = v == true ? _allHotels.map((h) => h.id!).toSet() : <int>{};
                      }),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _allHotels.length,
                        itemBuilder: (_, i) {
                          final h = _allHotels[i];
                          return CheckboxListTile(
                            title: Text(h.arabicName),
                            secondary: CircleAvatar(radius: 10, backgroundColor: HotelVisualIdentity.colorForHotel(h)),
                            value: h.id != null && temp.contains(h.id),
                            onChanged: (v) => setSheetState(() {
                              if (h.id == null) return;
                              if (v == true) {
                                temp.add(h.id!);
                              } else {
                                temp.remove(h.id!);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _identityColor, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                      onPressed: temp.isEmpty ? null : () => Navigator.pop(ctx, temp),
                      child: const Text("تطبيق"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _selectedHotelIds = result);
      await _load();
    }
  }

  void _openLedger(String title, String category, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CashMovementsListPage(hotel: widget.hotel, title: title, category: category, hotelIds: _selectedHotelIds.toList(), hotelNames: _hotelNames, color: color),
      ),
    );
  }

  void _openAccountsList(String title, List<FinancialAccount> accounts, Color color) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _AccountsListPage(hotel: widget.hotel, title: title, accounts: accounts, color: color, hotelFor: _hotelFor, onOpenLedger: _openLedger)));
  }

  @override
  Widget build(BuildContext context) {
    final color = _identityColor;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: color,
        elevation: 0,
        title: const Text("المركز المالي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                InkWell(
                  onTap: _openHotelSelector,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: color.withOpacity(0.25))),
                    child: Row(children: [Icon(Icons.apartment, color: color, size: 20), const SizedBox(width: 10), Expanded(child: Text(_selectedHotelIds.length == _allHotels.length ? "جميع الفنادق" : "${_selectedHotelIds.length} فندق مختار", style: AppTextStyles.bodyBold.copyWith(fontSize: 13))), Icon(Icons.expand_more, color: color)]),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                _buildGrid(color),
              ],
            ),
    );
  }

  Widget _buildGrid(Color color) {
    final pendingTotal = _pendingFunds.fold(0.0, (s, f) => s + f.cashAmount + f.networkAmount);
    final loansTotal = _loans.fold(0.0, (s, l) => s + l.amount);
    final assetsTotal = _assets.fold(0.0, (s, a) => s + a.balance);
    final liabilitiesTotal = _liabilities.fold(0.0, (s, a) => s + a.balance);
    final personalTotal = _personalAccounts.fold(0.0, (s, a) => s + a.balance);

    final categories = [
      _CategoryData("النقد", Icons.payments_outlined, const Color(0xFF12B886), _format(_cashBalance), () => _openLedger("حركات النقد", 'cash', const Color(0xFF12B886))),
      _CategoryData("البنك", Icons.account_balance_outlined, const Color(0xFF1E3A5F), _format(_bankBalance), () => _openLedger("حركات البنك", 'bank', const Color(0xFF1E3A5F))),
      _CategoryData("الحسابات الشخصية", Icons.person_outline, const Color(0xFF8B5CF6), _format(personalTotal), () => _openAccountsList("الحسابات الشخصية", _personalAccounts, const Color(0xFF8B5CF6))),
      _CategoryData("الأموال المعلقة", Icons.hourglass_empty_outlined, AppColors.warning, _format(pendingTotal), () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PendingFundsPage(hotel: widget.hotel, funds: _pendingFunds, color: AppColors.warning, hotelFor: _hotelFor)))),
      _CategoryData("القروض", Icons.account_balance_wallet_outlined, const Color(0xFFD9743C), _format(loansTotal), () => Navigator.push(context, MaterialPageRoute(builder: (_) => _LoansPage(hotel: widget.hotel, loans: _loans, color: const Color(0xFFD9743C), hotelFor: _hotelFor)))),
      _CategoryData("الأصول", Icons.trending_up_outlined, const Color(0xFF1FA971), _format(assetsTotal), () => _openAccountsList("الأصول", _assets, const Color(0xFF1FA971))),
      _CategoryData("الالتزامات", Icons.trending_down_outlined, AppColors.danger, _format(liabilitiesTotal), () => _openAccountsList("الالتزامات", _liabilities, AppColors.danger)),
      _CategoryData(
        "الذمم الدائنة",
        Icons.receipt_long_outlined,
        const Color(0xFFB3541E),
        _format(_accountsPayableTotal),
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => _AccountsPayablePage(hotel: widget.hotel, suppliers: _suppliersWithDebt, color: const Color(0xFFB3541E), hotelFor: _hotelFor))),
      ),
    ];
    final rows = <Widget>[];
    for (int i = 0; i < categories.length; i += 2) {
      final second = i + 1 < categories.length ? categories[i + 1] : null;
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _buildCard(categories[i])),
          const SizedBox(width: 12),
          Expanded(child: second != null ? _buildCard(second) : const SizedBox()),
        ]),
      ));
      if (i + 2 < categories.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  Widget _buildCard(_CategoryData c) {
    return AppCard(
      onTap: c.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(c.icon, color: c.color, size: 18)),
          const SizedBox(height: 12),
          Text(c.value, style: AppTextStyles.title.copyWith(fontSize: 18, color: c.color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(c.title, style: AppTextStyles.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _AccountsListPage extends StatelessWidget {
  final Hotel hotel;
  final String title;
  final List<FinancialAccount> accounts;
  final Color color;
  final Hotel Function(int?) hotelFor;
  final void Function(String, String, Color) onOpenLedger;
  const _AccountsListPage({required this.hotel, required this.title, required this.accounts, required this.color, required this.hotelFor, required this.onOpenLedger});

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(title, style: const TextStyle(color: Colors.white)), centerTitle: true, backgroundColor: identityColor, elevation: 0),
      body: accounts.isEmpty
          ? const Center(child: Text("لا توجد حسابات", style: TextStyle(color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: accounts
                  .map((a) => Card(
                        margin: const EdgeInsets.only(bottom: AppSizes.sm),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: ListTile(
                          leading: Icon(Icons.account_balance_wallet_outlined, color: color),
                          title: Text(a.name, style: AppTextStyles.bodyBold),
                          subtitle: Text(hotelFor(a.hotelId).arabicName, style: AppTextStyles.caption),
                          trailing: Text(_format(a.balance), style: AppTextStyles.bodyBold.copyWith(color: color)),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => CashMovementsListPage(hotel: hotelFor(a.hotelId), title: a.name, category: a.category, hotelIds: [a.hotelId], hotelNames: {a.hotelId: hotelFor(a.hotelId).arabicName}, color: color)));
                          },
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

class _PendingFundsPage extends StatelessWidget {
  final Hotel hotel;
  final List<DepositedFund> funds;
  final Color color;
  final Hotel Function(int?) hotelFor;
  const _PendingFundsPage({required this.hotel, required this.funds, required this.color, required this.hotelFor});

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("الأموال المعلقة", style: TextStyle(color: Colors.white)), centerTitle: true, backgroundColor: identityColor, elevation: 0),
      body: funds.isEmpty
          ? const Center(child: Text("لا توجد أموال معلّقة", style: TextStyle(color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: funds
                  .map((f) => Card(
                        margin: const EdgeInsets.only(bottom: AppSizes.sm),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: ListTile(
                          leading: Icon(Icons.hourglass_empty_outlined, color: color),
                          title: Text(hotelFor(f.hotelId).arabicName, style: AppTextStyles.bodyBold),
                          subtitle: Text("${f.date} · نقد: ${f.cashStatus == 'pending' ? 'معلّق' : 'مُرحَّل'} · شبكة: ${f.networkStatus == 'pending' ? 'معلّقة' : 'مُرحَّلة'}", style: AppTextStyles.caption),
                          trailing: Text(_format(f.cashAmount + f.networkAmount), style: AppTextStyles.bodyBold.copyWith(color: color)),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

/// "الذمم الدائنة" — ديون على المنشأة لصالح موردين، مجمَّعة من مصدرين
/// (فواتير "شراء آجل" + مصروفات معلقة "آجل (دين)") عبر
/// SupplierRepository.getSuppliersWithOutstandingDebt، ناقص ما سُدِّد. كل
/// عنصر مرتبط بمورد حقيقي — لا كشف حساب تفصيلي بعد (خارج نطاق هذه المرحلة).
class _AccountsPayablePage extends StatelessWidget {
  final Hotel hotel;
  final List<Map<String, dynamic>> suppliers;
  final Color color;
  final Hotel Function(int?) hotelFor;
  const _AccountsPayablePage({required this.hotel, required this.suppliers, required this.color, required this.hotelFor});

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("الذمم الدائنة", style: TextStyle(color: Colors.white)), centerTitle: true, backgroundColor: identityColor, elevation: 0),
      body: suppliers.isEmpty
          ? const Center(child: Text("لا توجد ديون قائمة على المنشأة", style: TextStyle(color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: suppliers
                  .map((s) => Card(
                        margin: const EdgeInsets.only(bottom: AppSizes.sm),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: ListTile(
                          leading: Icon(Icons.local_shipping_outlined, color: color),
                          title: Text(s['official_name'] as String, style: AppTextStyles.bodyBold),
                          subtitle: Text("${hotelFor(s['hotel_id'] as int?).arabicName} · ${s['short_name']}", style: AppTextStyles.caption),
                          trailing: Text(_format((s['balance'] as num).toDouble()), style: AppTextStyles.bodyBold.copyWith(color: color)),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

class _LoansPage extends StatelessWidget {
  final Hotel hotel;
  final List<EntityLoan> loans;
  final Color color;
  final Hotel Function(int?) hotelFor;
  const _LoansPage({required this.hotel, required this.loans, required this.color, required this.hotelFor});

  String _format(double v) => NumberFormat("#,##0.##").format(v);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(hotel);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("القروض", style: TextStyle(color: Colors.white)), centerTitle: true, backgroundColor: identityColor, elevation: 0),
      body: loans.isEmpty
          ? const Center(child: Text("لا توجد قروض", style: TextStyle(color: Colors.grey)))
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: loans
                  .map((l) => Card(
                        margin: const EdgeInsets.only(bottom: AppSizes.sm),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: ListTile(
                          leading: Icon(Icons.account_balance_wallet_outlined, color: color),
                          title: Text(l.statement, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text("${hotelFor(l.hotelId).arabicName} · ${l.date} · مصدر الإيداع: ${l.source}", style: AppTextStyles.caption),
                          trailing: Text(_format(l.amount), style: AppTextStyles.bodyBold.copyWith(color: color)),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}
