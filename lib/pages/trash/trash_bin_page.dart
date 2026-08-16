import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/trashed_item.dart';
import '../../repositories/trash_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/trash_confirm_dialogs.dart';
import '../settings/recycle_bin_page.dart';

/// "سلة المهملات" الموحّدة — تجمع كل العناصر المحذوفة ناعماً عبر كل الأنواع
/// المسجَّلة في lib/core/trash/trashable_entity.dart (مستندات، ملاحظات،
/// عقود، فواتير، تسويات، مصروفات معلَّقة/مشتركة، تحويلات بين منشآت غير
/// مُرحَّلة) في قائمة واحدة، بلا تفريق شاشة لكل نوع.
///
/// الفنادق والموظفون **غير مُدرَجين في هذه القائمة** — يحتفظان بحمايتهما
/// الحالية كاملة (سلة محذوفات الفنادق الرباعية المراحل: اسم+سبب+PIN، وأرشفة
/// الموظفين الدائمة بلا حذف نهائي) عبر بطاقة تنقّل مباشرة لشاشتيهما بدل
/// تفكيك تلك الحماية إلى الحوار العام هنا (راجع قرار المستخدم الصريح).
class TrashBinPage extends StatefulWidget {
  const TrashBinPage({super.key});

  @override
  State<TrashBinPage> createState() => _TrashBinPageState();
}

class _TrashBinPageState extends State<TrashBinPage> {
  final _repository = TrashRepository();
  bool _isLoading = true;
  List<TrashedItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await _repository.listAll();
    if (mounted) setState(() { _items = items; _isLoading = false; });
  }

  Future<void> _restore(TrashedItem item) async {
    await TrashConfirmDialogs.confirmRestore(context, () async {
      await _repository.restore(item.type, item.id);
      _loadData();
    });
  }

  Future<void> _permanentlyDelete(TrashedItem item) async {
    await TrashConfirmDialogs.confirmPermanentDelete(context, () async {
      await _repository.permanentlyDelete(item.type, item.id);
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("سلة المهملات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.md),
                children: [
                  AppCard(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecycleBinPage())),
                    child: const Row(
                      children: [
                        Icon(Icons.apartment_outlined, color: AppColors.primary),
                        SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text("سلة محذوفات الفنادق", style: AppTextStyles.bodyBold),
                        ),
                        Icon(Icons.chevron_left),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text("سلة المهملات فارغة", style: AppTextStyles.caption)),
                    )
                  else
                    for (final item in _items) ...[
                      _buildRow(item),
                      const SizedBox(height: AppSizes.sm),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _buildRow(TrashedItem item) {
    final remaining = item.remainingDays;
    final urgentColor = remaining <= 3 ? AppColors.danger : Colors.orange;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(item.typeLabel, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: urgentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text("متبقٍ $remaining يوم", style: TextStyle(color: urgentColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text("حُذف: ${DateFormat('yyyy-MM-dd').format(item.deletedAt)}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _restore(item),
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text("استعادة"),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _permanentlyDelete(item),
                  icon: const Icon(Icons.delete_forever, size: 16, color: AppColors.danger),
                  label: const Text("حذف نهائي", style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
