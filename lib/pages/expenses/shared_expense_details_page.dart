import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_page_route.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/pending_expense.dart';
import '../../models/shared_expense.dart';
import '../../repositories/shared_expense_distribution_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import 'add_edit_shared_expense_page.dart';

/// تفاصيل مصروف مشترك: رأس المصروف (بمرجعه SE-000001) + كل مصروف معلَّق
/// مولَّد لكل منشأة. التعديل/الحذف مسموحان فقط قبل ترحيل أيٍّ منها لتقرير
/// يومي — راجع SharedExpenseDistributionRepository.canModify.
class SharedExpenseDetailsPage extends StatefulWidget {
  final int sharedExpenseId;
  const SharedExpenseDetailsPage({super.key, required this.sharedExpenseId});

  @override
  State<SharedExpenseDetailsPage> createState() => _SharedExpenseDetailsPageState();
}

class _SharedExpenseDetailsPageState extends State<SharedExpenseDetailsPage> {
  final _repository = SharedExpenseDistributionRepository();
  SharedExpense? _header;
  List<PendingExpense> _rows = [];
  bool _isLoading = true;
  bool _canModify = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final header = await _repository.getSharedExpenseById(widget.sharedExpenseId);
    final rows = await _repository.getPendingExpensesFor(widget.sharedExpenseId);
    final canModify = await _repository.canModify(widget.sharedExpenseId);
    if (!mounted) return;
    setState(() {
      _header = header;
      _rows = rows;
      _canModify = canModify;
      _isLoading = false;
    });
  }

  Future<void> _edit() async {
    final result = await Navigator.push(
      context,
      premiumRoute(AddEditSharedExpensePage(editing: _header, editingRows: _rows)),
    );
    if (result == true) {
      _changed = true;
      _loadData();
    }
  }

  Future<void> _delete() async {
    await AppDialog.confirmAction(
      context: context,
      title: "حذف المصروف المشترك",
      message: "سيُحذف رأس المصروف المشترك \"${_header!.reference}\" وكل ${_rows.length} مصروف معلَّق مولَّد منه نهائياً. هذا الإجراء لا يمكن التراجع عنه.",
      confirmLabel: "حذف نهائي",
      isDangerous: true,
      onConfirm: () async {
        await _repository.deleteSharedExpense(widget.sharedExpenseId);
        _changed = true;
        if (mounted) Navigator.pop(context, true);
      },
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
          title: Text(_header?.reference ?? "مصروف مشترك"),
          centerTitle: true,
          actions: _isLoading || _header == null
              ? null
              : [
                  IconButton(icon: const Icon(Icons.edit_outlined), tooltip: "تعديل", onPressed: _canModify ? _edit : null),
                  IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), tooltip: "حذف", onPressed: _canModify ? _delete : null),
                ],
        ),
        body: _isLoading || _header == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSizes.md),
                children: [
                  if (!_canModify)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSizes.md),
                      padding: const EdgeInsets.all(AppSizes.sm),
                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text("رُحِّل جزء من هذا المصروف لتقرير يومي بالفعل — لا يمكن تعديله أو حذفه بعد الآن.", style: AppTextStyles.caption)),
                        ],
                      ),
                    ),
                  _buildHeaderCard(),
                  const SizedBox(height: AppSizes.md),
                  Text("موزَّع على ${_rows.length} منشأة", style: AppTextStyles.bodyBold),
                  const SizedBox(height: AppSizes.sm),
                  for (final r in _rows) _buildRow(r),
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final h = _header!;
    final numberFmt = NumberFormat("#,##0.##");
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.xs)),
                child: Text(h.reference, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const Spacer(),
              Text(h.date, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(h.description ?? h.categoryName ?? '', style: AppTextStyles.title.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text("${numberFmt.format(h.totalAmount)} ريال", style: AppTextStyles.bodyBold.copyWith(fontSize: 20, color: AppColors.danger)),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text("مصدر التمويل: ${h.fundingSource}", style: AppTextStyles.caption),
            ],
          ),
          if (h.notes != null && h.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text("ملاحظات: ${h.notes}", style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(PendingExpense r) {
    final numberFmt = NumberFormat("#,##0.##");
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.hotelName ?? "منشأة #${r.hotelId}", style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(r.isTransferred ? "مُرحَّل" : "بانتظار الترحيل", style: AppTextStyles.caption.copyWith(color: r.isTransferred ? Colors.green : Colors.orange)),
                ],
              ),
            ),
            Text("${numberFmt.format(r.amount)} ريال", style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
