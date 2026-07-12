import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/hotel_visual_identity.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/hotel.dart';
import '../../../services/financial_engine.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/hotel_identity_title.dart';

class LedgerPage extends StatefulWidget {
  final Hotel hotel;
  final String category; // 'cash', 'bank', 'personal', 'entity', etc.
  final String title;

  const LedgerPage({
    super.key,
    required this.hotel,
    required this.category,
    required this.title,
  });

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final _engine = FinancialEngine();
  bool _isLoading = true;
  List<Map<String, dynamic>> _entries = [];
  double _currentBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _entries = await _engine.getLedger(widget.hotel.id!, widget.category);
    _currentBalance = await _engine.getBalance(widget.hotel.id!, widget.category);
    if (mounted) setState(() => _isLoading = false);
  }

  String _format(num val) => NumberFormat("#,##0.##").format(val);

  @override
  Widget build(BuildContext context) {
    final identityColor = HotelVisualIdentity.colorForHotel(widget.hotel);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: HotelIdentityTitle(title: widget.title, hotel: widget.hotel),
        centerTitle: true,
        backgroundColor: identityColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildBalanceCard(identityColor),
              Expanded(
                child: _entries.isEmpty 
                  ? const Center(child: Text("لا توجد حركات مسجلة لهذا الحساب"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSizes.md),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return _buildEntryItem(entry, identityColor);
                      },
                    ),
              ),
            ],
          ),
    );
  }

  Widget _buildBalanceCard(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        children: [
          const Text("الرصيد الحالي", style: TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            _format(_currentBalance),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryItem(Map<String, dynamic> entry, Color identityColor) {
    final isDebit = entry['type'] == 'debit';

    bool isPositive;
    if (widget.category == 'cash' || widget.category == 'bank' || widget.category.startsWith('receivable')) {
      isPositive = isDebit;
    } else {
      isPositive = !isDebit;
    }

    final amountColor = isPositive ? Colors.green : AppColors.danger;
    final icon = isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      identityAccent: identityColor,
      child: Row(
        children: [
          Icon(icon, color: amountColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_referenceTypeLabel(entry['reference_type']) != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(_referenceTypeLabel(entry['reference_type'])!, style: AppTextStyles.caption.copyWith(color: identityColor, fontWeight: FontWeight.bold)),
                  ),
                Text(entry['description'], style: AppTextStyles.bodyBold),
                Text("${entry['date']} • ${entry['time']}", style: AppTextStyles.caption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isPositive ? '+' : '-'}${_format(entry['amount'])}",
                style: AppTextStyles.bodyBold.copyWith(color: amountColor),
              ),
              const SizedBox(height: 4),
              _miniInfo("قبل الحركة", _format(entry['balance_before'])),
              _miniInfo("بعد الحركة", _format(entry['balance_after'])),
              if (entry['reference_id'] != null)
                 Padding(
                   padding: const EdgeInsets.only(top: 2),
                   child: Text("مرجع: #${entry['reference_id']}", style: const TextStyle(fontSize: 8, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                 ),
            ],
          ),
        ],
      ),
    );
  }

  String? _referenceTypeLabel(dynamic refType) {
    switch (refType) {
      case 'daily_report': return "مصروف يومي";
      case 'employee_advance': return "سلفة موظف";
      case 'debt_settlement': return "سداد دين";
      case 'inter_entity': return "تحويل بين المنشآت";
      case 'personal_action': return "حركة شخصية";
      case 'entity_loan': return "قرض على المنشأة";
      default: return null;
    }
  }

  Widget _miniInfo(String label, String val) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("$label: ", style: const TextStyle(fontSize: 8, color: Colors.grey)),
        Text(val, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54)),
      ],
    );
  }
}
