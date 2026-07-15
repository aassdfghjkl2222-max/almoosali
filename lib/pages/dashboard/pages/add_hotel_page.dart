import 'package:flutter/material.dart';
import '../../../core/app_radius.dart';
import '../../../core/app_sizes.dart';
import '../../../core/app_text_styles.dart';
import '../../../models/hotel.dart';
import '../../../repositories/hotel_repository.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/common/app_dialog.dart';
import '../../../widgets/common/app_text_field.dart';

class AddHotelPage extends StatefulWidget {
  final Hotel? hotel; // If provided, we are editing
  const AddHotelPage({super.key, this.hotel});

  @override
  State<AddHotelPage> createState() => _AddHotelPageState();
}

class _AddHotelPageState extends State<AddHotelPage> {
  final _repository = HotelRepository();
  final _arNameController = TextEditingController();
  final _enNameController = TextEditingController();
  final _cityController = TextEditingController();
  bool _hasParking = false;
  int _selectedColorValue = _identityColors.first.value;
  bool _isLoading = false;

  static const List<_HotelColorOption> _identityColors = [
    _HotelColorOption(name: "عنابي", value: 0xFF7A1E2C),
    _HotelColorOption(name: "أزرق", value: 0xFF1565C0),
    _HotelColorOption(name: "أخضر", value: 0xFF0B7A47),
    _HotelColorOption(name: "ذهبي", value: 0xFFB8913F),
    _HotelColorOption(name: "بنفسجي", value: 0xFF6A1B9A),
    _HotelColorOption(name: "برتقالي", value: 0xFFE65100),
    _HotelColorOption(name: "رمادي", value: 0xFF546E7A),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.hotel != null) {
      _arNameController.text = widget.hotel!.arabicName;
      _enNameController.text = widget.hotel!.englishName;
      _cityController.text = widget.hotel!.city;
      _hasParking = widget.hotel!.hasParking;
      _selectedColorValue = widget.hotel!.identityColorValue ?? _selectedColorValue;
    }
  }

  Future<void> _save() async {
    if (_arNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال اسم المنشأة بالعربية")));
      return;
    }

    if (!mounted) return;
    await AppDialog.confirmAction(
      context: context,
      title: widget.hotel == null ? "تأكيد إضافة المنشأة" : "تأكيد حفظ التعديلات",
      message: widget.hotel == null ? "هل تريد إضافة هذه المنشأة؟" : "هل تريد حفظ التعديلات على هذه المنشأة؟",
      onConfirm: _performSave,
    );
  }

  Future<void> _performSave() async {
    setState(() => _isLoading = true);
    final hotel = Hotel(
      id: widget.hotel?.id,
      arabicName: _arNameController.text.trim(),
      englishName: _enNameController.text.trim(),
      city: _cityController.text.trim(),
      hasParking: _hasParking,
      identityColorValue: _selectedColorValue,
    );

    try {
      if (widget.hotel == null) {
        await _repository.addHotel(hotel);
      } else {
        await _repository.updateHotel(hotel);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.hotel == null ? "إضافة منشأة جديدة" : "تعديل المنشأة"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          _buildForm(),
          const SizedBox(height: AppSizes.lg),
          _buildColorPicker(),
          const SizedBox(height: AppSizes.xl),
          AppButton(
            text: widget.hotel == null ? "إضافة المنشأة" : "حفظ التعديلات",
            onPressed: _save,
            isLoading: _isLoading,
            backgroundColor: Color(_selectedColorValue),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("المعلومات الأساسية", style: AppTextStyles.bodyBold),
        const SizedBox(height: AppSizes.md),
        AppTextField(
          controller: _arNameController,
          hint: "اسم المنشأة باللغة العربية",
          icon: Icons.apartment,
        ),
        const SizedBox(height: AppSizes.md),
        AppTextField(
          controller: _enNameController,
          hint: "اسم المنشأة باللغة الإنجليزية (اختياري)",
          icon: Icons.language,
        ),
        const SizedBox(height: AppSizes.md),
        AppTextField(
          controller: _cityController,
          hint: "المدينة",
          icon: Icons.location_city,
        ),
        const SizedBox(height: AppSizes.md),
        SwitchListTile(
          title: const Text("تتوفر مواقف سيارات", style: AppTextStyles.body),
          value: _hasParking,
          onChanged: (v) => setState(() => _hasParking = v),
          activeColor: Color(_selectedColorValue),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("هوية الفندق", style: AppTextStyles.bodyBold),
        const SizedBox(height: AppSizes.xs),
        Text(
          "اختر لوناً واحداً يمثّل هوية هذا الفندق — سيُستخدم تلقائياً في كل شاشاته",
          style: AppTextStyles.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSizes.md),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _identityColors.map((option) {
            final isSelected = _selectedColorValue == option.value;
            final color = Color(option.value);
            return InkWell(
              onTap: () => setState(() => _selectedColorValue = option.value),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 84,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.withOpacity(0.25),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      option.name,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _HotelColorOption {
  final String name;
  final int value;
  const _HotelColorOption({required this.name, required this.value});
}
