import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_page_route.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../repositories/hotel_repository.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../dashboard/pages/add_hotel_page.dart';
import 'recycle_bin_page.dart';

/// "إدارة الفنادق" — قسم إعدادات جديد يتيح للمدير إضافة/تعديل/أرشفة الفنادق
/// من مكان واحد، بدل خلط ذلك داخل قائمة الفنادق الرئيسية (HotelsPage) التي
/// تبقى مخصَّصة لاختيار فندق للعمل عليه فقط. الأرشفة لا تحذف أي بيانات —
/// راجع HotelRepository.archiveHotel وRecycleBinPage.
class HotelManagementPage extends StatefulWidget {
  const HotelManagementPage({super.key});

  @override
  State<HotelManagementPage> createState() => _HotelManagementPageState();
}

class _HotelManagementPageState extends State<HotelManagementPage> {
  final _repository = HotelRepository();
  List<Hotel> _hotels = [];
  int _archivedCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final active = await _repository.getActiveHotels();
    final archived = await _repository.getArchivedHotels();
    if (!mounted) return;
    setState(() {
      _hotels = active;
      _archivedCount = archived.length;
      _isLoading = false;
    });
  }

  Future<void> _openAddOrEdit({Hotel? hotel}) async {
    final result = await Navigator.push(context, premiumRoute(AddHotelPage(hotel: hotel)));
    if (result == true) _loadData();
  }

  Future<void> _archiveHotel(Hotel hotel) async {
    await AppDialog.confirmAction(
      context: context,
      title: "أرشفة ${hotel.arabicName}",
      message: "سيختفي هذا الفندق من القائمة الرئيسية وتبقى كل بياناته المالية والتشغيلية محفوظة بالكامل. يمكن استعادته في أي وقت من سلة المحذوفات.",
      isDangerous: true,
      confirmLabel: "أرشفة",
      onConfirm: () async {
        await _repository.archiveHotel(hotel.id!, archivedBy: "مدير النظام");
        if (mounted) _loadData();
      },
    );
  }

  Future<void> _openRecycleBin() async {
    final result = await Navigator.push(context, premiumRoute(const RecycleBinPage()));
    if (result == true) _loadData();
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                _buildRecycleBinLink(),
                const SizedBox(height: AppSizes.lg),
                Text("الفنادق النشطة (${_hotels.length})", style: AppTextStyles.subtitle.copyWith(fontSize: 15)),
                const SizedBox(height: AppSizes.sm),
                if (_hotels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text("لا توجد فنادق نشطة", style: AppTextStyles.caption)),
                  )
                else
                  ..._hotels.map((h) => Padding(
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
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
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
    return AppCard(
      identityAccent: color,
      onTap: () => _openAddOrEdit(hotel: hotel),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(Icons.apartment_rounded, color: color, size: 22),
          ),
          const SizedBox(width: AppSizes.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(hotel.arabicName, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (hotel.city.trim().isNotEmpty) Text(hotel.city, style: AppTextStyles.caption.copyWith(fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: "تعديل",
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _openAddOrEdit(hotel: hotel),
          ),
          IconButton(
            tooltip: "أرشفة",
            icon: const Icon(Icons.archive_outlined, size: 20, color: AppColors.warning),
            onPressed: () => _archiveHotel(hotel),
          ),
        ],
      ),
    );
  }
}
