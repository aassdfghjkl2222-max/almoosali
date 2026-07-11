import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'dart:io';
import '../../../core/app_colors.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../core/formatters/thousands_separator_formatter.dart';
import '../../../models/settlement.dart';
import '../../../models/settlement_account.dart';
import '../../../repositories/settlement_repository.dart';
import '../../../services/vault_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/common/app_dialog.dart';
import '../../../widgets/vault/amount_source_selector.dart';

import '../../../models/hotel.dart';

class AddPersonOperationPage extends StatefulWidget {
  final Hotel hotel;
  final SettlementAccount? account; // Pre-selected account
  final String type; // 'person' or 'supplier'

  const AddPersonOperationPage({super.key, required this.hotel, this.account, this.type = 'person'});

  @override
  State<AddPersonOperationPage> createState() => _AddPersonOperationPageState();
}

class _AddPersonOperationPageState extends State<AddPersonOperationPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = SettlementRepository();
  final _vaultService = VaultService();

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _direction = 'to_me'; // 'to_me' (لك عليه), 'from_me' (عليك له)
  String _amountSource = 'خارج النظام';
  final List<String> _attachments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _nameController.text = widget.account!.name;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _attachments.add(image.path));
  }

  Future<void> _pickFile() async {
    final result = await fp.FilePicker.pickFiles(type: fp.FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.path != null) setState(() => _attachments.add(result.files.single.path!));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    final amountPreview = ThousandsSeparatorInputFormatter.parse(_amountController.text) ?? 0;
    await AppDialog.confirmAction(
      context: context,
      title: "تأكيد حفظ العملية",
      message: "هل تريد حفظ هذه العملية بمبلغ ${NumberFormat("#,##0.00").format(amountPreview)}؟",
      onConfirm: _performSave,
    );
  }

  Future<void> _performSave() async {
    setState(() => _isLoading = true);

    try {
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

      // 1. Find or Create Account
      SettlementAccount? account = widget.account;
      if (account == null) {
        account = await _repository.getAccountByName(widget.hotel.id!, _nameController.text, widget.type);
        if (account == null) {
          final id = await _repository.addAccount(SettlementAccount(
            hotelId: widget.hotel.id!,
            name: _nameController.text,
            type: widget.type,
            createdAt: DateTime.now(),
          ));
          account = SettlementAccount(
            id: id, 
            hotelId: widget.hotel.id!,
            name: _nameController.text, 
            type: widget.type, 
            createdAt: DateTime.now()
          );
        }
      }

      // 2. Add Settlement Operation
      await _repository.addSettlement(Settlement(
        type: widget.type,
        accountId: account!.id,
        amount: amount,
        date: _selectedDate,
        description: _descriptionController.text,
        attachments: _attachments,
        direction: _direction,
        createdAt: DateTime.now(),
      ));

      if (mounted) {
        // معالجة حركة الخزنة/البنك إن وجدت
        await _vaultService.processVaultTransaction(
          context: context,
          hotelId: widget.hotel.id!,
          amount: amount,
          source: _amountSource,
          type: "تسوية: ${account!.name}",
          reference: _descriptionController.text,
        );
        
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPerson = widget.type == 'person';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isPerson ? "إضافة عملية شخص" : "إضافة عملية مورد", 
                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
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
                  _buildLabel(isPerson ? "اسم الشخص" : "اسم المورد"),
                  TextFormField(
                    controller: _nameController,
                    enabled: widget.account == null,
                    decoration: const InputDecoration(hintText: "ادخل الاسم..."),
                    validator: (v) => (v == null || v.isEmpty) ? "الاسم مطلوب" : null,
                  ),
                  const SizedBox(height: AppSizes.md),

                  _buildLabel("نوع العملية"),
                  Row(
                    children: [
                      _buildDirectionOption("to_me", isPerson ? "لك عليه" : "لك عنده"),
                      const SizedBox(width: AppSizes.md),
                      _buildDirectionOption("from_me", isPerson ? "عليك له" : "عليك له"),
                    ],
                  ),
                  const SizedBox(height: AppSizes.md),

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

                  _buildLabel("التاريخ"),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _selectedDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.md),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(AppSizes.sm)),
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
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: "اكتب وصفاً للعملية..."),
                    validator: (v) => (v == null || v.isEmpty) ? "الوصف مطلوب" : null,
                  ),
                  const SizedBox(height: AppSizes.lg),

                  _buildLabel("المرفقات"),
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
                      children: _attachments.asMap().entries.map((e) => _buildAttachmentTile(e.value, e.key)).toList(),
                    ),
                  ],
                  const SizedBox(height: AppSizes.xl),

                  AppButton(text: "حفظ العملية", onPressed: _save),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDirectionOption(String value, String label) {
    final isSelected = _direction == value;
    final primary = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _direction = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.white,
            border: Border.all(color: isSelected ? primary : Colors.grey.shade400),
            borderRadius: BorderRadius.circular(AppSizes.md),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(text, style: AppTextStyles.bodyBold));

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
      width: 80, height: 80,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Stack(
        children: [
          Center(child: isPdf ? const Icon(Icons.picture_as_pdf, color: Colors.red) : Image.file(File(path), width: 80, height: 80, fit: BoxFit.cover)),
          Positioned(right: 0, top: 0, child: IconButton(icon: const Icon(Icons.cancel, color: Colors.red, size: 20), onPressed: () => setState(() => _attachments.removeAt(index)))),
        ],
      ),
    );
  }
}
