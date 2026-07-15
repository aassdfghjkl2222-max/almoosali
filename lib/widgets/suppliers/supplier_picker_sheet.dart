import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/supplier.dart';
import '../../repositories/supplier_repository.dart';
import '../common/app_text_field.dart';

/// نافذة اختيار مورد مرجعي واحد (بحث فوري) مع إمكانية إضافة مورد جديد مباشرة
/// ثم اختياره تلقائياً — لا يُسمح بكتابة اسم مورد حراً؛ كل مورد صف حقيقي في
/// جدول suppliers، يُطابق تماماً نفس مبدأ الموردين المرجعيين المستخدم أصلاً
/// في شاشة إضافة الفاتورة الضريبية. مشتركة لأي شاشة تحتاج ربط مورد (حالياً:
/// المصروفات المعلقة الآجلة؛ مستقبلاً أي شاشة أخرى بلا تكرار لهذا المنطق).
Future<Supplier?> showSupplierPicker(BuildContext context, {required int hotelId}) {
  return showModalBottomSheet<Supplier>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (sheetContext) => _SupplierPickerSheet(hotelId: hotelId),
  );
}

class _SupplierPickerSheet extends StatefulWidget {
  final int hotelId;
  const _SupplierPickerSheet({required this.hotelId});

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  final _repository = SupplierRepository();
  final _searchController = TextEditingController();

  final _officialNameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _taxNumberController = TextEditingController();

  List<Supplier> _results = [];
  bool _isAddMode = false;
  bool _isSaving = false;
  String? _taxNumberError;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _officialNameController.dispose();
    _shortNameController.dispose();
    _taxNumberController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final results = await _repository.searchSuppliers(widget.hotelId, query.trim());
    if (mounted) setState(() => _results = results);
  }

  void _startAddMode() {
    _officialNameController.text = _searchController.text.trim();
    setState(() {
      _isAddMode = true;
      _taxNumberError = null;
    });
  }

  Future<void> _saveNewSupplier() async {
    final officialName = _officialNameController.text.trim();
    final shortName = _shortNameController.text.trim();
    final taxNumber = _taxNumberController.text.trim();

    if (officialName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال الاسم الرسمي للمورد")));
      return;
    }
    if (shortName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال الاسم المختصر للمورد")));
      return;
    }
    if (taxNumber.length != 15) {
      setState(() => _taxNumberError = "الرقم الضريبي يجب أن يكون 15 رقماً بالضبط");
      return;
    }

    setState(() => _isSaving = true);
    final existing = await _repository.getSupplierByOfficialName(widget.hotelId, officialName);
    if (existing != null) {
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, existing);
      }
      return;
    }
    final newSupplier = Supplier(hotelId: widget.hotelId, officialName: officialName, shortName: shortName, taxNumber: taxNumber);
    final id = await _repository.addSupplier(newSupplier);
    if (mounted) Navigator.pop(context, Supplier(id: id, hotelId: widget.hotelId, officialName: officialName, shortName: shortName, taxNumber: taxNumber));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(_isAddMode ? "مورد جديد" : "اختيار المورد", style: AppTextStyles.title.copyWith(fontSize: 17))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: AppSizes.sm),
            if (_isAddMode) _buildAddForm() else _buildSearch(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: "بحث بالاسم",
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ..._results.map((s) => ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(s.officialName),
                      subtitle: Text(s.shortName, style: AppTextStyles.caption),
                      onTap: () => Navigator.pop(context, s),
                    )),
                if (_results.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: AppSizes.md), child: Center(child: Text("لا يوجد مورد مطابق", style: AppTextStyles.caption))),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: Colors.green),
                  title: const Text("إضافة مورد جديد", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  onTap: _startAddMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Flexible(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(controller: _officialNameController, hint: "الاسم الرسمي", icon: Icons.business_outlined),
            const SizedBox(height: AppSizes.md),
            AppTextField(controller: _shortNameController, hint: "الاسم المختصر", icon: Icons.short_text),
            const SizedBox(height: AppSizes.md),
            AppTextField(
              controller: _taxNumberController,
              hint: "الرقم الضريبي (15 رقماً)",
              icon: Icons.numbers_outlined,
              keyboardType: TextInputType.number,
              errorText: _taxNumberError,
              onChanged: (_) {
                if (_taxNumberError != null) setState(() => _taxNumberError = null);
              },
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _isAddMode = false), child: const Text("رجوع"))),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveNewSupplier,
                    child: const Text("حفظ واختيار"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
