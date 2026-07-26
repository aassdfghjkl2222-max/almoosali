import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/document_type.dart';
import '../../repositories/document_type_repository.dart';
import '../../repositories/hotel_repository.dart';
import '../../widgets/common/app_card.dart';
import 'add_edit_document_type_page.dart';

class DocumentTypeDetailsPage extends StatefulWidget {
  final DocumentType documentType;
  const DocumentTypeDetailsPage({super.key, required this.documentType});

  @override
  State<DocumentTypeDetailsPage> createState() => _DocumentTypeDetailsPageState();
}

class _DocumentTypeDetailsPageState extends State<DocumentTypeDetailsPage> {
  final _repository = DocumentTypeRepository();
  final _hotelRepository = HotelRepository();
  late DocumentType _type;
  List<String> _scopedHotelNames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _type = widget.documentType;
    _loadData();
  }

  Future<void> _loadData() async {
    final fresh = await _repository.getTypeById(_type.id!);
    if (fresh != null) _type = fresh;
    if (_type.scope == 'specific') {
      final ids = await _repository.getHotelsForType(_type.id!);
      final allHotels = await _hotelRepository.getAllHotelsIncludingArchived();
      _scopedHotelNames = allHotels.where((h) => ids.contains(h.id)).map((h) => h.arabicName).toList();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _edit() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditDocumentTypePage(documentType: _type)));
    if (result == true) {
      setState(() => _isLoading = true);
      _loadData();
    }
  }

  Future<void> _delete() async {
    final inUse = await _repository.isTypeInUse(_type.id!);
    if (inUse) {
      if (!mounted) return;
      final disableInstead = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("لا يمكن حذف هذا النوع"),
          content: Text("النوع '${_type.name}' مستخدم فعلياً في مستندات فندق واحد أو أكثر، لذلك لا يمكن حذفه نهائياً حفاظاً على سلامة البيانات. يمكنك تعطيله بدلاً من ذلك حتى لا يُقترح لفندق جديد."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("تعطيل النوع")),
          ],
        ),
      );
      if (disableInstead == true) {
        await _repository.updateType(_type.copyWith(isActive: false));
        if (mounted) Navigator.pop(context, true);
      }
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف نوع المستند '${_type.name}' نهائياً؟"),
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
    if (confirm == true) {
      await _repository.deleteType(_type.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("تفاصيل نوع المستند", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(_type.name, style: AppTextStyles.title.copyWith(fontSize: 18))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (_type.isActive ? AppColors.success : Colors.grey).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Text(
                              _type.isActive ? "مفعَّل" : "غير مفعَّل",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _type.isActive ? AppColors.success : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      if (_type.description != null && _type.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.sm),
                        Text(_type.description!, style: AppTextStyles.caption),
                      ],
                      const SizedBox(height: AppSizes.sm),
                      Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(_type.categoryColor ?? 0xFF7A1E2C), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(_type.categoryName ?? '', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                AppCard(
                  child: Column(
                    children: [
                      _row("إلزامي؟", _type.isMandatory ? "نعم" : "لا"),
                      const Divider(height: 1),
                      _row("يحتاج إلى تجديد؟", _type.requiresRenewal ? "نعم" : "لا"),
                      const Divider(height: 1),
                      _row("نطاق التطبيق", _type.isAllHotels ? "جميع الفنادق" : (_scopedHotelNames.isEmpty ? "لا يوجد فندق محدَّد بعد" : _scopedHotelNames.join('، '))),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.xl),
                OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  label: const Text("حذف نوع المستند", style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: AppColors.danger)),
                ),
              ],
            ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.caption),
          const Spacer(),
          Flexible(child: Text(value, style: AppTextStyles.bodyBold.copyWith(fontSize: 13), textAlign: TextAlign.left)),
        ],
      ),
    );
  }
}
