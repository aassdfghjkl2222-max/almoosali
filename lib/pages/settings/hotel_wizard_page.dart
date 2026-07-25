import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/hotel_color_palettes.dart';
import '../../models/hotel.dart';
import '../../repositories/hotel_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_text_field.dart';

/// معالج إنشاء/تعديل فندق متعدد الخطوات — عام / الموقع / التواصل / معلومات
/// الفندق / الهوية البصرية. يحل محل AddHotelPage القديم (نموذج بحقول قليلة
/// بلا تنظيم بخطوات) كجزء من وحدة "إدارة الفنادق" الكاملة.
///
/// شعار الفندق وصورة الغلاف: الحقول (logoPath/coverImagePath) موجودة في
/// النموذج ومُعَدَّة للمستقبل، لكن رفع/التقاط الصورة الفعلي غير مُنفَّذ بعد
/// عمداً — يتطلب حزمة قص صور جديدة لم تُضَف للمشروع بعد (قرار يتطلب موافقة
/// صريحة قبل إضافة أي اعتمادية جديدة). تُعرض بطاقة "قريباً" بدلاً منه.
///
/// الصلاحيات المبنية على الأدوار (RBAC) المذكورة في متطلبات الوحدة غير
/// مُنفَّذة أيضاً: التطبيق حالياً نظام دخول واحد مشترك (رمز PIN) بلا حسابات
/// مستخدمين حقيقية (راجع kAppHasMultipleUsers في app_drawer.dart) — بناء
/// شاشة صلاحيات لأدوار لا تقابلها حسابات مستخدمين فعلية سيكون واجهة معطَّلة
/// لا تُطبِّق شيئاً فعلياً، فتُركت لحين وجود نظام مستخدمين حقيقي.
class HotelWizardPage extends StatefulWidget {
  final Hotel? hotel;
  const HotelWizardPage({super.key, this.hotel});

  @override
  State<HotelWizardPage> createState() => _HotelWizardPageState();
}

class _HotelWizardPageState extends State<HotelWizardPage> {
  final _repository = HotelRepository();
  int _step = 0;
  bool _isSaving = false;

  // عام
  final _arNameController = TextEditingController();
  final _enNameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();

  // الموقع
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _addressController = TextEditingController();
  final _mapsLinkController = TextEditingController();

  // التواصل
  final _phoneController = TextEditingController();
  final _mobileController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();

  // معلومات الفندق
  int _starRating = 0;
  final _roomsController = TextEditingController();
  final _openingDateController = TextEditingController();
  final _notesController = TextEditingController();
  bool _hasParking = false;

  // الهوية البصرية
  int _selectedColorValue = HotelColorPalettes.defaultColorValue;
  String _status = HotelStatuses.active.value;

  String? _nameError;
  String? _codeError;
  String? _emailError;

  bool get _isEditing => widget.hotel != null;

  @override
  void initState() {
    super.initState();
    final h = widget.hotel;
    if (h != null) {
      _arNameController.text = h.arabicName;
      _enNameController.text = h.englishName;
      _codeController.text = h.hotelCode ?? '';
      _descriptionController.text = h.description ?? '';
      _countryController.text = h.country ?? '';
      _cityController.text = h.city;
      _districtController.text = h.district ?? '';
      _addressController.text = h.address ?? '';
      _mapsLinkController.text = h.mapsLink ?? '';
      _phoneController.text = h.phone ?? '';
      _mobileController.text = h.mobile ?? '';
      _whatsappController.text = h.whatsapp ?? '';
      _emailController.text = h.email ?? '';
      _websiteController.text = h.website ?? '';
      _starRating = h.starRating ?? 0;
      _roomsController.text = h.roomsCount?.toString() ?? '';
      _openingDateController.text = h.openingDate ?? '';
      _notesController.text = h.notes ?? '';
      _hasParking = h.hasParking;
      _selectedColorValue = h.identityColorValue ?? HotelColorPalettes.defaultColorValue;
      _status = h.status;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _arNameController, _enNameController, _codeController, _descriptionController,
      _countryController, _cityController, _districtController, _addressController, _mapsLinkController,
      _phoneController, _mobileController, _whatsappController, _emailController, _websiteController,
      _roomsController, _openingDateController, _notesController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static const _steps = ["عام", "الموقع", "التواصل", "معلومات الفندق", "الهوية البصرية"];

  Future<bool> _validateStep(int step) async {
    setState(() {
      _nameError = null;
      _codeError = null;
      _emailError = null;
    });
    if (step == 0) {
      if (_arNameController.text.trim().isEmpty) {
        setState(() => _nameError = "اسم الفندق بالعربية مطلوب");
        return false;
      }
      if (await _repository.isNameTaken(_arNameController.text, excludeId: widget.hotel?.id)) {
        setState(() => _nameError = "يوجد فندق آخر بنفس الاسم");
        return false;
      }
      if (await _repository.isCodeTaken(_codeController.text, excludeId: widget.hotel?.id)) {
        setState(() => _codeError = "هذا الكود مستخدَم لفندق آخر");
        return false;
      }
    }
    if (step == 2) {
      final email = _emailController.text.trim();
      if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        setState(() => _emailError = "صيغة بريد إلكتروني غير صحيحة");
        return false;
      }
    }
    return true;
  }

  Future<void> _next() async {
    if (!await _validateStep(_step)) return;
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _confirmAndSave();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmAndSave() async {
    await AppDialog.confirmAction(
      context: context,
      title: _isEditing ? "حفظ تعديلات الفندق" : "تأكيد إضافة الفندق",
      message: _isEditing ? "هل تريد حفظ التعديلات على \"${_arNameController.text.trim()}\"؟" : "هل تريد إضافة \"${_arNameController.text.trim()}\" كفندق جديد؟",
      onConfirm: _save,
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final hotel = Hotel(
      id: widget.hotel?.id,
      arabicName: _arNameController.text.trim(),
      englishName: _enNameController.text.trim(),
      city: _cityController.text.trim(),
      hasParking: _hasParking,
      identityColorValue: _selectedColorValue,
      active: widget.hotel?.active ?? true,
      status: _status,
      hotelCode: _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
      district: _districtController.text.trim().isEmpty ? null : _districtController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      mapsLink: _mapsLinkController.text.trim().isEmpty ? null : _mapsLinkController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      mobile: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
      whatsapp: _whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      starRating: _starRating == 0 ? null : _starRating,
      roomsCount: int.tryParse(_roomsController.text.trim()),
      openingDate: _openingDateController.text.trim().isEmpty ? null : _openingDateController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    try {
      if (widget.hotel == null) {
        await _repository.addHotel(hotel);
      } else {
        await _repository.updateHotel(hotel, previous: widget.hotel);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? "تعديل الفندق" : "إضافة فندق جديد", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.md),
              child: _buildStepContent(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.sm),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _back,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                  child: Text(_step == 0 ? "إلغاء" : "السابق"),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                flex: 2,
                child: AppButton(
                  text: _step == _steps.length - 1 ? (_isEditing ? "حفظ التعديلات" : "إضافة الفندق") : "التالي",
                  onPressed: _next,
                  isLoading: _isSaving,
                  backgroundColor: Color(_selectedColorValue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.sm),
      child: Column(
        children: [
          Row(
            children: List.generate(_steps.length, (i) {
              final done = i < _step;
              final current = i == _step;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: done || current ? Color(_selectedColorValue) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text("${_step + 1}/${_steps.length} — ${_steps[_step]}", style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildGeneralStep();
      case 1:
        return _buildLocationStep();
      case 2:
        return _buildContactStep();
      case 3:
        return _buildHotelInfoStep();
      default:
        return _buildBrandingStep();
    }
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildGeneralStep() {
    return _sectionCard([
      AppTextField(controller: _arNameController, hint: "اسم الفندق بالعربية *", icon: Icons.apartment, errorText: _nameError),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _enNameController, hint: "اسم الفندق بالإنجليزية (اختياري)", icon: Icons.language),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _codeController, hint: "الكود الداخلي للفندق (اختياري)", icon: Icons.qr_code, errorText: _codeError),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _descriptionController, hint: "وصف مختصر (اختياري)", icon: Icons.notes_outlined, maxLines: 3),
    ]);
  }

  Widget _buildLocationStep() {
    return _sectionCard([
      AppTextField(controller: _countryController, hint: "الدولة", icon: Icons.public),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _cityController, hint: "المدينة", icon: Icons.location_city),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _districtController, hint: "الحي", icon: Icons.map_outlined),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _addressController, hint: "العنوان التفصيلي", icon: Icons.location_on_outlined, maxLines: 2),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _mapsLinkController, hint: "رابط خرائط جوجل (اختياري)", icon: Icons.map_rounded),
    ]);
  }

  Widget _buildContactStep() {
    return _sectionCard([
      AppTextField(controller: _phoneController, hint: "الهاتف", icon: Icons.call_outlined, keyboardType: TextInputType.phone),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _mobileController, hint: "الجوال", icon: Icons.smartphone_outlined, keyboardType: TextInputType.phone),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _whatsappController, hint: "واتساب", icon: Icons.chat_outlined, keyboardType: TextInputType.phone),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _emailController, hint: "البريد الإلكتروني", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, errorText: _emailError),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _websiteController, hint: "الموقع الإلكتروني (اختياري)", icon: Icons.public),
    ]);
  }

  Widget _buildHotelInfoStep() {
    return _sectionCard([
      const Text("تصنيف النجوم", style: AppTextStyles.bodyBold),
      const SizedBox(height: AppSizes.sm),
      Row(
        children: List.generate(5, (i) {
          final n = i + 1;
          return IconButton(
            onPressed: () => setState(() => _starRating = _starRating == n ? 0 : n),
            icon: Icon(n <= _starRating ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.secondary, size: 28),
          );
        }),
      ),
      const SizedBox(height: AppSizes.sm),
      AppTextField(controller: _roomsController, hint: "عدد الغرف", icon: Icons.meeting_room_outlined, keyboardType: TextInputType.number),
      const SizedBox(height: AppSizes.md),
      AppTextField(controller: _openingDateController, hint: "تاريخ الافتتاح (YYYY-MM-DD)", icon: Icons.event_outlined),
      const SizedBox(height: AppSizes.md),
      SwitchListTile(
        title: const Text("تتوفر مواقف سيارات", style: AppTextStyles.body),
        value: _hasParking,
        onChanged: (v) => setState(() => _hasParking = v),
        activeThumbColor: Color(_selectedColorValue),
        contentPadding: EdgeInsets.zero,
      ),
      const SizedBox(height: AppSizes.sm),
      AppTextField(controller: _notesController, hint: "ملاحظات (اختياري)", icon: Icons.sticky_note_2_outlined, maxLines: 3),
    ]);
  }

  Widget _buildBrandingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard([
          const Text("حالة الفندق", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HotelStatuses.selectable.map((s) {
              final selected = _status == s.value;
              return ChoiceChip(
                label: Text(s.label),
                avatar: Icon(s.icon, size: 16, color: selected ? Colors.white : s.color),
                selected: selected,
                selectedColor: s.color,
                labelStyle: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.bold),
                onSelected: (_) => setState(() => _status = s.value),
              );
            }).toList(),
          ),
        ]),
        const SizedBox(height: AppSizes.lg),
        _sectionCard([
          const Text("مساحة الشعار", style: AppTextStyles.bodyBold),
          const SizedBox(height: AppSizes.sm),
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade500),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    "رفع/التقاط شعار الفندق — قريباً",
                    style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: AppSizes.lg),
        _sectionCard([
          const Text("الهوية اللونية", style: AppTextStyles.bodyBold),
          const SizedBox(height: 4),
          Text("اختر لوناً يمثّل هوية هذا الفندق — سيظهر في كل بطاقاته وشاشاته", style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: HotelColorPalettes.all.map((option) {
              final isSelected = _selectedColorValue == option.color.toARGB32();
              return InkWell(
                onTap: () => setState(() => _selectedColorValue = option.color.toARGB32()),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 84,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: isSelected ? option.color : Colors.grey.withValues(alpha: 0.25), width: isSelected ? 2 : 1),
                    boxShadow: isSelected ? [BoxShadow(color: option.color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: option.color, shape: BoxShape.circle),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option.name,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? option.color : Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ]),
        const SizedBox(height: AppSizes.lg),
        Text("معاينة حية", style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
        const SizedBox(height: AppSizes.sm),
        _buildLivePreview(),
      ],
    );
  }

  Widget _buildLivePreview() {
    final color = Color(_selectedColorValue);
    final hsl = HSLColor.fromColor(color);
    final bright = hsl.withLightness((hsl.lightness + (1 - hsl.lightness) * 0.3).clamp(0.0, 1.0)).toColor();
    final deep = hsl.withLightness((hsl.lightness * 0.55).clamp(0.0, 1.0)).toColor();
    final name = _arNameController.text.trim().isEmpty ? "اسم الفندق" : _arNameController.text.trim();
    return Container(
      height: 96,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [bright, color, deep], stops: const [0, 0.55, 1]),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(Icons.apartment_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 1))]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
