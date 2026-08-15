import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../models/hotel.dart';
import '../../models/inter_entity_transfer.dart';
import '../../repositories/hotel_repository.dart';
import '../../repositories/inter_entity_transfer_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/hotel_identity_title.dart';
import '../common/transaction_review_page.dart';

/// "التحويل بين المنشآت" — تحويل مباشر لمبلغ بين هذا الفندق وفندق آخر، بلا
/// مصروف مرتبط. سجل معلَّق بحت عند الحفظ — بلا أي قيد محاسبي فوري، بلا أي
/// أثر على المركز المالي. يظهر في التقرير اليومي، ويُقفَل من التعديل عند
/// اعتماد ذلك التقرير، والقيد المحاسبي الفعلي (ذمة بين الطرفين، أو خصم حقيقي
/// من أصول المُرسِل + ذمة إن دُفع من مصدر تمويل حقيقي) لا يُنفَّذ إلا عند
/// الترحيل الفعلي (راجع InterEntityTransferRepository ودورة الحياة
/// المحاسبية: معلّق ← تقرير يومي ← ترحيل).
///
/// [editTransfer] يفتح الشاشة بوضع التعديل — مسموح فقط من الفندق المُرسِل
/// الأصلي، وفقط إن لم يُعتمَد تقرير يوم هذا التحويل بعد (بلا أي قيد ليُعكَس،
/// فالتعديل/الحذف هنا تحديث/حذف مباشر لا أكثر)؛ راجع
/// InterEntityTransferRepository.updateTransfer/deleteTransfer للحماية
/// الفعلية على مستوى طبقة الأعمال.
class AddInterEntityTransferPage extends StatefulWidget {
  final Hotel hotel;
  final InterEntityTransfer? editTransfer;
  const AddInterEntityTransferPage({super.key, required this.hotel, this.editTransfer});

  @override
  State<AddInterEntityTransferPage> createState() => _AddInterEntityTransferPageState();
}

class _AddInterEntityTransferPageState extends State<AddInterEntityTransferPage> {
  final _repository = InterEntityTransferRepository();
  final _hotelRepository = HotelRepository();
  final _formKey = GlobalKey<FormState>();
  final _statementController = TextEditingController();
  final _amountController = TextEditingController();

  List<Hotel> _otherHotels = [];
  Hotel? _counterpartHotel;
  bool _isLoading = true;

  bool get _isEditing => widget.editTransfer != null;

  /// true = هذا الفندق يُرسِل إلى [_counterpartHotel] (يصبح الآخر مديناً لهذا
  /// الفندق). false = هذا الفندق يستلم من [_counterpartHotel] (يصبح هذا
  /// الفندق مديناً له).
  bool _isSending = true;

  /// مصدر التمويل مطلوب فقط عند الإرسال (هذا الفندق هو من يدفع فعلياً) —
  /// راجع InterEntityTransferRepository.createTransfer.
  String _fundingSource = 'نقد';

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    final hotels = await _hotelRepository.getAllHotels();
    if (!mounted) return;
    final edit = widget.editTransfer;
    setState(() {
      _otherHotels = hotels.where((h) => h.id != widget.hotel.id).toList();
      if (edit != null) {
        // التعديل مسموح فقط من الفندق المُرسِل — فراجع pending_expenses_list_page.dart،
        // فـ_isSending دائماً true عند التعديل.
        _isSending = true;
        _statementController.text = edit.statement;
        _amountController.text = NumberFormat("#,##0.##").format(edit.amount);
        for (final h in _otherHotels) {
          if (h.id == edit.toHotelId) _counterpartHotel = h;
        }
        if (edit.fundingSourceCategory != null) {
          _fundingSource = edit.fundingSourceCategory == 'bank' ? 'شبكة' : 'نقد';
        }
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _statementController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال مبلغ صحيح")));
      return;
    }
    if (_counterpartHotel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار المنشأة الأخرى")));
      return;
    }

    final fromHotel = _isSending ? widget.hotel : _counterpartHotel!;
    final toHotel = _isSending ? _counterpartHotel! : widget.hotel;
    final statement = _statementController.text.trim();

    final reviewItems = [
      ReviewItem(label: "البيان", value: statement),
      ReviewItem(label: "المبلغ", value: "${NumberFormat("#,##0.##").format(amount)} ريال", color: AppColors.danger),
      ReviewItem(label: "من", value: fromHotel.arabicName, color: Colors.purple),
      ReviewItem(label: "إلى", value: toHotel.arabicName, color: Colors.purple),
      if (_isSending) ReviewItem(label: "مصدر التمويل", value: _fundingSource, color: Colors.blue),
    ];

    final edit = widget.editTransfer;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionReviewPage(
          title: _isEditing ? "مراجعة تعديل التحويل" : "مراجعة التحويل",
          items: reviewItems,
          onConfirm: () async {
            final fundingSourceCategory = _isSending ? (_fundingSource == 'شبكة' ? 'bank' : 'cash') : null;
            if (edit != null) {
              final newTransfer = edit.copyWith(
                fromHotelId: fromHotel.id!,
                toHotelId: toHotel.id!,
                amount: amount,
                statement: statement,
                fundingSourceCategory: fundingSourceCategory,
                clearFundingSourceCategory: fundingSourceCategory == null,
              );
              await _repository.updateTransfer(newTransfer);
            } else {
              await _repository.createTransfer(
                fromHotelId: fromHotel.id!,
                toHotelId: toHotel.id!,
                amount: amount,
                statement: statement,
                fundingSourceCategory: fundingSourceCategory,
              );
            }
            if (mounted) {
              Navigator.pop(context); // Close Review
              Navigator.pop(context, true); // Close Add/Edit Page
            }
          },
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final edit = widget.editTransfer;
    if (edit == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("حذف التحويل"),
        content: const Text("هل أنت متأكد من حذف هذا التحويل؟ سيُعكَس أثره المحاسبي بالكامل."),
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
    if (confirmed != true) return;
    try {
      await _repository.deleteTransfer(edit);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحذف")));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('StateError: ', '')), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: HotelIdentityTitle(title: _isEditing ? "تعديل تحويل" : "تحويل بين المنشآت", hotel: widget.hotel),
        centerTitle: true,
        actions: _isEditing ? [IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: "حذف", onPressed: _delete)] : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("اتجاه التحويل", style: AppTextStyles.bodyBold),
                          const SizedBox(height: AppSizes.sm),
                          Row(
                            children: [
                              Expanded(child: _directionChip("إرسال إلى", Icons.call_made, true)),
                              const SizedBox(width: 8),
                              Expanded(child: _directionChip("استلام من", Icons.call_received, false)),
                            ],
                          ),
                          const SizedBox(height: AppSizes.md),
                          _buildHotelDropdown(),
                        ],
                      ),
                    ),
                    if (_isSending) ...[
                      const SizedBox(height: AppSizes.lg),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("مصدر التمويل", style: AppTextStyles.bodyBold),
                            const SizedBox(height: 4),
                            const Text("هذا الفندق هو من يدفع فعلياً — يجب تحديد مصدر الخصم.", style: AppTextStyles.caption),
                            const SizedBox(height: AppSizes.sm),
                            Row(
                              children: [
                                Expanded(child: _fundingChip('نقد', Icons.money)),
                                const SizedBox(width: 8),
                                Expanded(child: _fundingChip('الخزنة', Icons.lock_outline)),
                                const SizedBox(width: 8),
                                Expanded(child: _fundingChip('شبكة', Icons.credit_card)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSizes.lg),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("تفاصيل التحويل", style: AppTextStyles.bodyBold),
                          const SizedBox(height: AppSizes.md),
                          AppTextField(controller: _statementController, hint: "البيان", icon: Icons.description),
                          const SizedBox(height: AppSizes.md),
                          AppTextField(controller: _amountController, hint: "المبلغ", icon: Icons.attach_money, formatThousands: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.xl),
                    AppButton(text: "مراجعة وحفظ", onPressed: _save),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _fundingChip(String label, IconData icon) {
    final selected = _fundingSource == label;
    return ChoiceChip(
      label: Text(label, textAlign: TextAlign.center),
      avatar: Icon(icon, size: 16),
      selected: selected,
      onSelected: (_) => setState(() => _fundingSource = label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
  }

  /// اتجاه التحويل مُقفَل عند التعديل (يبقى "إرسال" دائماً — راجع تعليق
  /// pending_expenses_list_page.dart._editTransfer) حتى لا يتغيّر معنى
  /// [_counterpartHotel] المُعبَّأ مسبقاً كـ"المستقبِل".
  Widget _directionChip(String label, IconData icon, bool value) {
    final selected = _isSending == value;
    return ChoiceChip(
      label: Text(label, textAlign: TextAlign.center),
      avatar: Icon(icon, size: 16),
      selected: selected,
      onSelected: _isEditing ? null : (_) => setState(() => _isSending = value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
  }

  Widget _buildHotelDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Hotel>(
          value: _counterpartHotel,
          isExpanded: true,
          hint: Text(_isSending ? "اختر المنشأة المستقبِلة" : "اختر المنشأة المرسِلة"),
          items: _otherHotels.map((h) => DropdownMenuItem(value: h, child: Text(h.arabicName))).toList(),
          onChanged: (v) => setState(() => _counterpartHotel = v),
        ),
      ),
    );
  }
}
