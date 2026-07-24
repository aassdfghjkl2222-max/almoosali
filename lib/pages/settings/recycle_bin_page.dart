import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_visual_identity.dart';
import '../../models/hotel.dart';
import '../../repositories/hotel_repository.dart';
import '../../services/security_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_text_field.dart';

/// سلة المحذوفات: الفنادق المؤرشَفة فقط. "استعادة" تعيد الفندق فوراً لقائمة
/// الفنادق النشطة بضغطة واحدة (عملية آمنة تماماً وقابلة للتكرار). "حذف نهائي"
/// محمي بثلاث طبقات تأكيد متتالية (تحذير صريح ← كتابة اسم الفندق ← رمز PIN)
/// قبل تنفيذ HotelRepository.deleteHotel الذي يحذف كل البيانات المرتبطة عبر
/// ON DELETE CASCADE بلا أي إمكانية تراجع بعده.
class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  final _repository = HotelRepository();
  List<Hotel> _hotels = [];
  bool _isLoading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final hotels = await _repository.getArchivedHotels();
    if (!mounted) return;
    setState(() {
      _hotels = hotels;
      _isLoading = false;
    });
  }

  String _formatDate(String? iso) {
    if (iso == null) return "—";
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  Future<void> _restore(Hotel hotel) async {
    await AppDialog.confirmAction(
      context: context,
      title: "استعادة ${hotel.arabicName}",
      message: "سيعود هذا الفندق فوراً لقائمة الفنادق النشطة بكل بياناته كما كانت تماماً.",
      confirmLabel: "استعادة",
      onConfirm: () async {
        await _repository.restoreHotel(hotel.id!);
        _changed = true;
        if (mounted) _loadData();
      },
    );
  }

  /// المرحلة 1: تحذير صريح لا لبس فيه بأن الحذف نهائي ولا رجعة عنه.
  Future<void> _startPermanentDelete(Hotel hotel) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Expanded(child: Text("حذف نهائي — لا يمكن التراجع", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 15))),
          ],
        ),
        content: Text(
          "سيتم حذف \"${hotel.arabicName}\" وكل بياناته المالية والتشغيلية (التقارير، المصروفات، المستندات، الموظفون، العقود، وكل شيء آخر) نهائياً من النظام. هذا الإجراء لا يمكن التراجع عنه إطلاقاً بعد تنفيذه.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("متابعة", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    await _confirmByTypingName(hotel);
  }

  /// المرحلة 2: كتابة اسم الفندق حرفياً — تأكيد إضافي واعٍ، يمنع الحذف
  /// بضغطة عرضية واحدة.
  Future<void> _confirmByTypingName(Hotel hotel) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final matches = controller.text.trim() == hotel.arabicName;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: const Text("تأكيد الحذف", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("للمتابعة، اكتب اسم الفندق بالضبط:", style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text(hotel.arabicName, style: AppTextStyles.bodyBold),
                const SizedBox(height: AppSizes.sm),
                AppTextField(controller: controller, hint: "اسم الفندق", onChanged: (_) => setDialogState(() {})),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
              TextButton(
                onPressed: matches ? () => Navigator.pop(context, true) : null,
                child: Text("متابعة", style: TextStyle(color: matches ? AppColors.danger : Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;
    await _confirmByPin(hotel);
  }

  /// المرحلة 3: رمز PIN — أقرب مفهوم "صلاحية المدير" الفعلي المتاح في
  /// التطبيق حالياً (نظام دخول واحد مشترك، بلا حسابات مستخدمين متعددة بعد).
  Future<void> _confirmByPin(Hotel hotel) async {
    final controller = TextEditingController();
    String? errorText;
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: const Text("تأكيد صلاحية المدير", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("أدخل رمز PIN للمتابعة بالحذف النهائي.", style: AppTextStyles.caption),
                const SizedBox(height: AppSizes.sm),
                AppTextField(
                  controller: controller,
                  hint: "رمز PIN",
                  isPassword: true,
                  keyboardType: TextInputType.number,
                  errorText: errorText,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
              TextButton(
                onPressed: () async {
                  final ok = await SecurityService.instance.verifyPin(controller.text.trim());
                  if (ok) {
                    if (context.mounted) Navigator.pop(context, true);
                  } else {
                    setDialogState(() => errorText = "رمز غير صحيح");
                  }
                },
                child: const Text("تأكيد الحذف النهائي", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
    if (verified != true || !mounted) return;
    await _repository.deleteHotel(hotel.id!);
    _changed = true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم حذف \"${hotel.arabicName}\" نهائياً")));
      _loadData();
    }
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
          title: const Text("سلة المحذوفات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.danger,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hotels.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text("سلة المحذوفات فارغة", style: AppTextStyles.caption),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSizes.md),
                    itemCount: _hotels.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      child: _buildRow(_hotels[i]),
                    ),
                  ),
      ),
    );
  }

  Widget _buildRow(Hotel hotel) {
    final color = HotelVisualIdentity.colorForHotel(hotel);
    return AppCard(
      identityAccent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(Icons.apartment_rounded, color: color, size: 20),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(hotel.arabicName, style: AppTextStyles.bodyBold.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text("أُرشِف: ${_formatDate(hotel.archivedAt)}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
              const SizedBox(width: AppSizes.md),
              const Icon(Icons.person_outline, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text("بواسطة: ${hotel.archivedBy ?? '—'}", style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _restore(hotel),
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text("استعادة"),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _startPermanentDelete(hotel),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                  icon: const Icon(Icons.delete_forever_outlined, size: 18),
                  label: const Text("حذف نهائي"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
