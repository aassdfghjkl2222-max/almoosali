import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'dart:io';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/formatters/thousands_separator_formatter.dart';
import '../../../models/settlement.dart';
import '../../../models/hotel.dart';
import '../../../repositories/settlement_repository.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../services/vault_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/common/app_dialog.dart';
import '../../../widgets/vault/amount_source_selector.dart';

import '../../../core/hotel_visual_identity.dart';

class AddInterEntityDebtPage extends StatefulWidget {
  final Hotel hotel;
  final Settlement? settlement; // For editing

  const AddInterEntityDebtPage({super.key, required this.hotel, this.settlement});

  @override
  State<AddInterEntityDebtPage> createState() => _AddInterEntityDebtPageState();
}

class _AddInterEntityDebtPageState extends State<AddInterEntityDebtPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = SettlementRepository();
  final _hotelRepository = HotelRepository();
  final _vaultService = VaultService();

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int? _creditorHotelId;
  int? _debtorHotelId;
  String _amountSource = 'خارج النظام';
  List<String> _attachments = [];
  List<Hotel> _hotels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHotels();
    if (widget.settlement != null) {
      _amountController.text = NumberFormat("#,##0.##").format(widget.settlement!.amount);
      _descriptionController.text = widget.settlement!.description;
      _selectedDate = widget.settlement!.date;
      _creditorHotelId = widget.settlement!.creditorHotelId;
      _debtorHotelId = widget.settlement!.debtorHotelId;
      _attachments = List.from(widget.settlement!.attachments);
    }
  }

  Future<void> _loadHotels() async {
    try {
      final hotels = await _hotelRepository.getAllHotels();
      setState(() {
        _hotels = hotels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _attachments.add(image.path));
    }
  }

  Future<void> _pickFile() async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _attachments.add(result.files.single.path!));
    }
  }

  void _onCreditorChanged(int? hotelId) {
    setState(() {
      _creditorHotelId = hotelId;
      // Automatically set debtor if there are only 2 hotels
      if (_hotels.length == 2 && hotelId != null) {
        _debtorHotelId = _hotels.firstWhere((h) => h.id != hotelId).id;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_creditorHotelId == null || _debtorHotelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار المنشآت")));
      return;
    }

    if (!mounted) return;
    await AppDialog.confirmAction(
      context: context,
      title: widget.settlement != null ? "تأكيد تعديل المديونية" : "تأكيد إضافة المديونية",
      message: widget.settlement != null
          ? "هل تريد حفظ التعديلات على هذه المديونية؟"
          : "هل تريد إضافة هذه المديونية؟",
      onConfirm: _performSave,
    );
  }

  Future<void> _performSave() async {
    final amount = ThousandsSeparatorInputFormatter.parse(_amountController.text) ?? 0;

    // التحقق من الرصيد والتأكيد
    final confirmed = await _vaultService.checkBalanceAndConfirm(
      context: context,
      hotelId: widget.hotel.id!,
      amount: amount,
      source: _amountSource,
    );

    if (!confirmed) {
      setState(() => _isLoading = false);
      return;
    }

    final settlement = Settlement(
      id: widget.settlement?.id,
      type: 'inter_entity',
      creditorHotelId: _creditorHotelId,
      debtorHotelId: _debtorHotelId,
      amount: amount,
      date: _selectedDate,
      description: _descriptionController.text,
      attachments: _attachments,
      status: widget.settlement?.status ?? 'open',
      totalPaid: widget.settlement?.totalPaid ?? 0,
      createdAt: widget.settlement?.createdAt ?? DateTime.now(),
    );

    try {
      if (widget.settlement == null) {
        await _repository.addSettlement(settlement);
        
        // معالجة حركة الخزنة/البنك إن وجدت
        if (mounted) {
          final creditorName = _hotels.firstWhere((h) => h.id == _creditorHotelId).arabicName;
          await _vaultService.processVaultTransaction(
            context: context,
            hotelId: widget.hotel.id!,
            amount: amount,
            source: _amountSource,
            type: "مديونية: $creditorName",
            reference: _descriptionController.text,
          );
        }
      } else {
        await _repository.updateSettlement(settlement);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء الحفظ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.settlement == null ? "إضافة مديونية" : "تعديل مديونية", 
                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("المبلغ"),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [ThousandsSeparatorInputFormatter()],
                    decoration: const InputDecoration(hintText: "0.00"),
                    validator: (v) => (v == null || v.isEmpty) ? "المبلغ مطلوب" : null,
                  ),
                  const SizedBox(height: AppSizes.md),

                  _buildLabel("مصدر المبلغ"),
                  AmountSourceSelector(
                    selectedSource: _amountSource,
                    onSourceChanged: (val) => setState(() => _amountSource = val),
                  ),
                  const SizedBox(height: AppSizes.md),
                  
                  _buildLabel("المنشأة الدائنة (التي دفعت)"),
                  DropdownButtonFormField<int>(
                    initialValue: _creditorHotelId,
                    items: _hotels.map((h) => DropdownMenuItem(value: h.id, child: Text(h.arabicName))).toList(),
                    onChanged: _onCreditorChanged,
                    decoration: const InputDecoration(hintText: "اختر المنشأة"),
                    validator: (v) => v == null ? "مطلوب" : null,
                  ),
                  const SizedBox(height: AppSizes.md),

                  _buildLabel("المنشأة المدينة (عليها دفع)"),
                  DropdownButtonFormField<int>(
                    initialValue: _debtorHotelId,
                    items: _hotels.map((h) => DropdownMenuItem(value: h.id, child: Text(h.arabicName))).toList(),
                    onChanged: (v) => setState(() => _debtorHotelId = v),
                    decoration: const InputDecoration(hintText: "اختر المنشأة"),
                    validator: (v) => v == null ? "مطلوب" : null,
                  ),
                  const SizedBox(height: AppSizes.md),

                  _buildLabel("التاريخ"),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setState(() => _selectedDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(AppSizes.sm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),

                  _buildLabel("الوصف (إجباري)"),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: "اكتب وصفاً للعملية..."),
                    validator: (v) => (v == null || v.isEmpty) ? "الوصف مطلوب" : null,
                  ),
                  const SizedBox(height: AppSizes.lg),

                  _buildLabel("المرفقات (صور أو PDF)"),
                  Row(
                    children: [
                      _buildAttachButton(Icons.image, "صورة", _pickImage),
                      const SizedBox(width: AppSizes.sm),
                      _buildAttachButton(Icons.picture_as_pdf, "PDF", _pickFile),
                    ],
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _attachments.asMap().entries.map((entry) {
                        return _buildAttachmentTile(entry.value, entry.key);
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: AppSizes.xl),

                  AppButton(
                    text: widget.settlement == null ? "إضافة المديونية" : "حفظ التعديلات",
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.xs),
      child: Text(text, style: AppTextStyles.bodyBold),
    );
  }

  Widget _buildAttachButton(IconData icon, String text, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.md)),
        ),
      ),
    );
  }

  Widget _buildAttachmentTile(String path, int index) {
    final isPdf = path.toLowerCase().endsWith('.pdf');
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(AppSizes.sm),
      ),
      child: Stack(
        children: [
          Center(
            child: isPdf 
              ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.sm),
                  child: Image.file(File(path), width: 100, height: 100, fit: BoxFit.cover),
                ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => setState(() => _attachments.removeAt(index)),
            ),
          ),
        ],
      ),
    );
  }
}
