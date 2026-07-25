import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_page_route.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_color_palettes.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../repositories/hotel_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_text_field.dart';
import 'hotel_audit_log_page.dart';
import 'hotel_wizard_page.dart';
import 'recycle_bin_page.dart';

/// "إدارة الفنادق" — مركز إدارة الفنادق الكامل: بحث، إضافة/تعديل عبر معالج
/// متعدد الخطوات، نسخ فندق، أرشفة (بسبب اختياري)، سلة المحذوفات، وسجل تدقيق.
/// هذه هي الشاشة الوحيدة التي تُدار منها الفنادق إدارياً — قائمة الفنادق
/// الرئيسية (HotelsPage) تبقى مخصَّصة حصراً لاختيار فندق للعمل عليه.
class HotelManagementPage extends StatefulWidget {
  const HotelManagementPage({super.key});

  @override
  State<HotelManagementPage> createState() => _HotelManagementPageState();
}

class _HotelManagementPageState extends State<HotelManagementPage> {
  final _repository = HotelRepository();
  final _searchController = TextEditingController();
  List<Hotel> _allHotels = [];
  List<Hotel> _filteredHotels = [];
  int _archivedCount = 0;
  bool _isLoading = true;

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
    final active = await _repository.getActiveHotels();
    final archived = await _repository.getArchivedHotels();
    if (!mounted) return;
    setState(() {
      _allHotels = active;
      _archivedCount = archived.length;
      _isLoading = false;
      _applySearch();
    });
  }

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredHotels = q.isEmpty
          ? _allHotels
          : _allHotels.where((h) {
              return h.arabicName.toLowerCase().contains(q) ||
                  h.englishName.toLowerCase().contains(q) ||
                  (h.hotelCode ?? '').toLowerCase().contains(q) ||
                  h.city.toLowerCase().contains(q);
            }).toList();
    });
  }

  Future<void> _openAddOrEdit({Hotel? hotel}) async {
    final result = await Navigator.push(context, premiumRoute(HotelWizardPage(hotel: hotel)));
    if (result == true) _loadData();
  }

  Future<void> _duplicateHotel(Hotel hotel) async {
    await AppDialog.confirmAction(
      context: context,
      title: "نسخ ${hotel.arabicName}",
      message: "سيُنشأ فندق جديد بنفس الهوية والإعدادات، باسم \"${hotel.arabicName} (نسخة)\" — يمكن تعديله بعد الإنشاء مباشرة.",
      confirmLabel: "نسخ",
      onConfirm: () async {
        await _repository.duplicateHotel(hotel);
        if (mounted) _loadData();
      },
    );
  }

  Future<void> _archiveHotel(Hotel hotel) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text("أرشفة ${hotel.arabicName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "سيختفي هذا الفندق من القائمة الرئيسية وتبقى كل بياناته المالية والتشغيلية محفوظة بالكامل. يمكن استعادته في أي وقت من سلة المحذوفات.",
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSizes.sm),
            AppTextField(controller: reasonController, hint: "سبب الأرشفة (اختياري)", icon: Icons.notes_outlined),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("أرشفة", style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.archiveHotel(hotel.id!, archivedBy: "مدير النظام", reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim());
    if (mounted) _loadData();
  }

  Future<void> _openRecycleBin() async {
    final result = await Navigator.push(context, premiumRoute(const RecycleBinPage()));
    if (result == true) _loadData();
  }

  Future<void> _openAuditLog() async {
    Navigator.push(context, premiumRoute(const HotelAuditLogPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إدارة الفنادق", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: "سجل التدقيق",
            icon: const Icon(Icons.history_rounded),
            onPressed: _openAuditLog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildRecycleBinLink(),
                const SizedBox(height: AppSizes.lg),
                AppTextField(
                  controller: _searchController,
                  hint: "بحث بالاسم أو الكود أو المدينة...",
                  icon: Icons.search,
                  onChanged: (_) => _applySearch(),
                ),
                const SizedBox(height: AppSizes.md),
                Text("الفنادق النشطة (${_filteredHotels.length})", style: AppTextStyles.subtitle.copyWith(fontSize: 15)),
                const SizedBox(height: AppSizes.sm),
                if (_filteredHotels.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text(_allHotels.isEmpty ? "لا توجد فنادق نشطة" : "لا نتائج مطابقة", style: AppTextStyles.caption)),
                  )
                else
                  ..._filteredHotels.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.sm),
                        child: _buildHotelRow(h),
                      )),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEdit(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text("إضافة فندق", style: TextStyle(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }

  Widget _buildRecycleBinLink() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: _openRecycleBin,
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("سلة المحذوفات", style: AppTextStyles.bodyBold),
                    Text("$_archivedCount فندق مؤرشَف", style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHotelRow(Hotel hotel) {
    final color = HotelVisualIdentity.colorForHotel(hotel);
    final statusInfo = HotelStatuses.fromValue(hotel.status);
    return AppCard(
      identityAccent: color,
      onTap: () => _openAddOrEdit(hotel: hotel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(Icons.apartment_rounded, color: color, size: 22),
              ),
              const SizedBox(width: AppSizes.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(hotel.arabicName, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (hotel.englishName.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(child: Text(hotel.englishName, style: AppTextStyles.caption.copyWith(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (hotel.hotelCode != null && hotel.hotelCode!.trim().isNotEmpty) ...[
                          Icon(Icons.qr_code, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(hotel.hotelCode!, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                          const SizedBox(width: 8),
                        ],
                        _statusBadge(statusInfo),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      _openAddOrEdit(hotel: hotel);
                      break;
                    case 'duplicate':
                      _duplicateHotel(hotel);
                      break;
                    case 'archive':
                      _archiveHotel(hotel);
                      break;
                    case 'log':
                      Navigator.push(context, premiumRoute(HotelAuditLogPage(hotel: hotel)));
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text("تعديل")])),
                  PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_all_outlined, size: 18), SizedBox(width: 8), Text("نسخ")])),
                  PopupMenuItem(value: 'log', child: Row(children: [Icon(Icons.history_rounded, size: 18), SizedBox(width: 8), Text("سجل التدقيق")])),
                  PopupMenuItem(value: 'archive', child: Row(children: [Icon(Icons.archive_outlined, size: 18, color: AppColors.warning), SizedBox(width: 8), Text("أرشفة", style: TextStyle(color: AppColors.warning))])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(HotelStatusInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: info.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 11, color: info.color),
          const SizedBox(width: 3),
          Text(info.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: info.color)),
        ],
      ),
    );
  }
}
