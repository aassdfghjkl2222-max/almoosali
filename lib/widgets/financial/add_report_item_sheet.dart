import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/financial_report_item.dart';
import '../../models/hotel.dart';
import '../../repositories/financial_report_item_repository.dart';
import '../common/app_text_field.dart';
import 'funding_source_picker.dart';

/// نتيجة "إضافة بند" — [savePermanently] يطلب من المستدعي حفظ البند في
/// كتالوج financial_report_items بعد الإضافة الفعلية للتقرير الحالي.
typedef AddReportItemResult = ({String name, String fundingSource, bool savePermanently});

/// نافذة موحّدة لإضافة بند (إيراد أو مصروف) إلى التقرير الحالي — إما باختيار
/// بند محفوظ سلفاً من الكتالوج (لا يظهر تلقائياً في الشاشة الرئيسية، فقط هنا)
/// أو بكتابة اسم جديد + اختيار مصدر تمويل + خيار حفظه بشكل دائم للمستقبل.
/// مشتركة بين قسمي الإيرادات والمصروفات (نفس التفاعل، الفارق فقط [itemType]).
Future<AddReportItemResult?> showAddReportItemSheet(
  BuildContext context, {
  required String itemType,
  required int hotelId,
  required List<Hotel> otherHotels,
}) {
  return showModalBottomSheet<AddReportItemResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (sheetContext) => _AddReportItemSheet(itemType: itemType, hotelId: hotelId, otherHotels: otherHotels),
  );
}

class _AddReportItemSheet extends StatefulWidget {
  final String itemType;
  final int hotelId;
  final List<Hotel> otherHotels;
  const _AddReportItemSheet({required this.itemType, required this.hotelId, required this.otherHotels});

  @override
  State<_AddReportItemSheet> createState() => _AddReportItemSheetState();
}

class _AddReportItemSheetState extends State<_AddReportItemSheet> {
  final _repository = FinancialReportItemRepository();
  final _nameController = TextEditingController();

  List<FinancialReportItem> _savedItems = [];
  bool _isLoading = true;
  bool _manualMode = false;
  String? _fundingSource;
  bool _savePermanently = false;

  bool get _isRevenue => widget.itemType == FinancialReportItem.typeRevenue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _repository.getItems(type: widget.itemType);
    if (mounted) setState(() { _savedItems = items; _isLoading = false; });
  }

  void _pickSaved(FinancialReportItem item) {
    final result = (name: item.name, fundingSource: item.defaultFundingSource ?? 'نقد', savePermanently: false);
    Navigator.pop(context, result);
  }

  Future<void> _pickFundingSource() async {
    final result = await showFundingSourcePicker(
      context,
      hotelId: widget.hotelId,
      otherHotels: widget.otherHotels,
      allowDeferred: false,
      allowBankTransfer: _isRevenue,
    );
    if (result != null) setState(() => _fundingSource = result.paymentMethod);
  }

  void _confirmManual() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال اسم البند")));
      return;
    }
    if (_fundingSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار مصدر التمويل")));
      return;
    }
    final AddReportItemResult result = (name: name, fundingSource: _fundingSource!, savePermanently: _savePermanently);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
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
                  Expanded(child: Text(_isRevenue ? "إضافة بند إيراد" : "إضافة بند مصروف", style: AppTextStyles.title.copyWith(fontSize: 17))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 1),
              Flexible(
                child: _isLoading
                    ? const Padding(padding: EdgeInsets.all(AppSizes.lg), child: Center(child: CircularProgressIndicator()))
                    : _manualMode
                        ? _buildManualForm()
                        : _buildSavedList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedList() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_savedItems.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: AppSizes.md), child: Center(child: Text("لا توجد بنود محفوظة بعد", style: AppTextStyles.caption)))
          else
            ..._savedItems.map((item) => ListTile(
                  leading: Icon(_isRevenue ? Icons.trending_up : Icons.trending_down, color: _isRevenue ? Colors.green : Colors.red),
                  title: Text(item.name),
                  subtitle: item.defaultFundingSource != null ? Text(item.defaultFundingSource!, style: AppTextStyles.caption) : null,
                  onTap: () => _pickSaved(item),
                )),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
            title: const Text("إضافة اسم جديد", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            onTap: () => setState(() => _manualMode = true),
          ),
        ],
      ),
    );
  }

  Widget _buildManualForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSizes.sm),
          AppTextField(controller: _nameController, hint: "اسم البند", icon: Icons.edit_note),
          const SizedBox(height: AppSizes.md),
          InkWell(
            onTap: _pickFundingSource,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_fundingSource ?? "اختيار مصدر التمويل", style: _fundingSource == null ? AppTextStyles.caption : AppTextStyles.bodyBold.copyWith(fontSize: 13))),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _savePermanently,
            title: const Text("حفظ هذا البند بشكل دائم", style: TextStyle(fontSize: 13)),
            subtitle: const Text("يظهر لاحقاً ضمن البنود المحفوظة عند الضغط على إضافة", style: AppTextStyles.caption),
            onChanged: (v) => setState(() => _savePermanently = v ?? false),
          ),
          const SizedBox(height: AppSizes.sm),
          ElevatedButton(onPressed: _confirmManual, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: const Text("إضافة")),
          const SizedBox(height: AppSizes.sm),
        ],
      ),
    );
  }
}
