import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/hotel.dart';
import '../../../models/financial_account.dart';
import '../../../services/financial_engine.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';
import 'collect_receivable_page.dart';
import 'personal_action_page.dart';

class PersonalAccountsPage extends StatefulWidget {
  final Hotel hotel;
  const PersonalAccountsPage({super.key, required this.hotel});

  @override
  State<PersonalAccountsPage> createState() => _PersonalAccountsPageState();
}

class _PersonalAccountsPageState extends State<PersonalAccountsPage> {
  final _engine = FinancialEngine();
  bool _isLoading = true;
  FinancialAccount? _ownerAccount;
  FinancialAccount? _ownerDebtAccount;
  List<FinancialAccount> _people = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Fetch owner account
    final ownerBal = await _engine.getBalance(widget.hotel.id!, 'personal');
    _ownerAccount = FinancialAccount(
      hotelId: widget.hotel.id!,
      name: "المالك",
      type: 'liability',
      category: 'personal',
      balance: ownerBal,
    );

    // سلف المالك (owner_debt): المالك مدين للمنشأة — راجع FinancialEngine.recordOwnerDrawing.
    final ownerDebtBal = await _engine.getBalance(widget.hotel.id!, 'owner_debt');
    _ownerDebtAccount = FinancialAccount(
      hotelId: widget.hotel.id!,
      name: "سلف المالك (مستحقة)",
      type: 'asset',
      category: 'owner_debt',
      balance: ownerDebtBal,
    );

    if (mounted) setState(() => _isLoading = false);
  }

  String _formatCurrency(double amount) {
    return NumberFormat("#,##0.##").format(amount);
  }

  Future<void> _addPerson() async {
    String name = "";
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إضافة شخص جديد"),
        content: TextField(
          onChanged: (v) => name = v,
          decoration: const InputDecoration(hintText: "اسم الشخص"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              if (name.trim().isNotEmpty) {
                await _engine.addPerson(widget.hotel.id!, name.trim());
                if (context.mounted) Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text("إضافة"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: "الحسابات الشخصية", hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: [
              if (_ownerAccount != null) _buildAccountCard(_ownerAccount!, identityColor, identityColor: identityColor, isOwner: true),
              if (_ownerDebtAccount != null) ...[
                const SizedBox(height: AppSizes.md),
                _buildOwnerDebtCard(_ownerDebtAccount!, identityColor),
              ],
              const SizedBox(height: AppSizes.lg),

              _buildSectionHeader("الحسابات الأخرى"),
              const SizedBox(height: AppSizes.md),
              
              if (_people.isEmpty)
                _buildEmptyState()
              else
                ..._people.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.md),
                  child: _buildAccountCard(p, Colors.blueGrey, identityColor: identityColor),
                )),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
        TextButton.icon(
          onPressed: _addPerson, 
          icon: const Icon(Icons.add, size: 18), 
          label: const Text("إضافة شخص")
        ),
      ],
    );
  }

  Widget _buildAccountCard(FinancialAccount acc, Color color, {required Color identityColor, bool isOwner = false}) {
    return AppCard(
      padding: EdgeInsets.all(isOwner ? AppSizes.lg : AppSizes.md),
      identityAccent: identityColor,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: isOwner ? 30 : 20,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(isOwner ? Icons.person : Icons.person_outline, size: isOwner ? 36 : 24, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isOwner ? "👤 حساب المالك" : acc.name, style: AppTextStyles.bodyBold),
                    Text(isOwner ? "الحساب الرئيسي للمنشأة" : "حساب شخصي", style: AppTextStyles.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("الرصيد الحالي", style: AppTextStyles.caption),
                  Text(_formatCurrency(acc.balance), style: AppTextStyles.title.copyWith(color: color, fontSize: isOwner ? 24 : 18)),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              _buildActionBtn("سحب", Icons.upload_rounded, Colors.red, () => _openAction(acc, 'withdraw')),
              const SizedBox(width: 8),
              _buildActionBtn("إيداع", Icons.download_rounded, Colors.green, () => _openAction(acc, 'deposit')),
              const SizedBox(width: 8),
              _buildActionBtn("كشف", Icons.list_alt_rounded, Colors.blue, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  /// "سلف المالك" — ما يدين به المالك للمنشأة (سحوبات "سلفة" ومسحوبات المالك
  /// المُرحَّلة، راجع FinancialEngine.recordOwnerDrawing) — عكس بطاقة حساب
  /// المالك أعلاه (المنشأة مدينة للمالك) تماماً.
  Widget _buildOwnerDebtCard(FinancialAccount acc, Color identityColor) {
    return AppCard(
      identityAccent: identityColor,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.deepOrange.withOpacity(0.1),
            child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.deepOrange, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("سلف المالك (مستحقة)", style: AppTextStyles.bodyBold),
                Text(_formatCurrency(acc.balance), style: AppTextStyles.title.copyWith(color: Colors.deepOrange, fontSize: 20)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: acc.balance > 0 ? () => _collectOwnerDebt(acc) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text("سداد"),
          ),
        ],
      ),
    );
  }

  void _collectOwnerDebt(FinancialAccount acc) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CollectReceivablePage(
      hotel: widget.hotel,
      receivableCategory: 'owner_debt',
      receivableLabel: 'سلف المالك (مستحقة)',
      currentBalance: acc.balance,
    ))).then((_) => _loadData());
  }

  void _openAction(FinancialAccount account, String action) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PersonalActionPage(
      hotel: widget.hotel,
      account: account,
      action: action,
    ))).then((_) => _loadData());
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text("لا توجد حسابات أخرى مضافة حالياً", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
