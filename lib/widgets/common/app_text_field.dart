import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_sizes.dart';
import '../../core/app_text_styles.dart';
import '../../core/formatters/thousands_separator_formatter.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData? icon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool readOnly;
  final VoidCallback? onTap;
  final int? maxLines;

  /// عند true يُنسَّق ما يُكتب في الحقل تلقائياً بفاصل آلاف (1,000) —
  /// يُستخدم فقط في حقول المبالغ/الكميات، وليس في أرقام الهوية
  /// (كالرقم الضريبي أو الجوال أو رمز PIN).
  final bool formatThousands;

  /// منسّقات إدخال مخصّصة (مثل قصر الإدخال على أرقام فقط بطول ثابت لحقل
  /// الرقم الضريبي) — تُتجاهَل إن كان formatThousands مفعَّلاً.
  final List<TextInputFormatter>? inputFormatters;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
    this.onChanged,
    this.errorText,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.formatThousands = false,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSizes.xs),
        ],
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: formatThousands ? const TextInputType.numberWithOptions(decimal: true) : keyboardType,
          inputFormatters: formatThousands ? const [ThousandsSeparatorInputFormatter()] : inputFormatters,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          focusNode: focusNode,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: icon == null ? null : Icon(icon),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.danger, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
