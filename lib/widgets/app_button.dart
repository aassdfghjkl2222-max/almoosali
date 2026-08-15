import 'package:flutter/material.dart';

import '../core/app_sizes.dart';
import '../core/app_text_styles.dart';

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;

  final IconData? icon;

  final Color? backgroundColor;

  final Color? foregroundColor;

  final double? width;

  final double? height;

  final bool isLoading;

  final bool isExpanded;

  final BorderRadius? borderRadius;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height,
    this.isLoading = false,
    this.isExpanded = true,
    this.borderRadius,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

/// زر بلمسة "فاخرة": انكماش خفيف جداً عند الضغط (نفس أسلوب تطبيقات iOS/الأنظمة
/// الفاخرة الحديثة) بدل الاعتماد على تأثير الموجة الافتراضي فقط — يُطبَّق مرة
/// واحدة هنا فينعكس تلقائياً على كل زر في التطبيق يستخدم AppButton.
class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: widget.width,
      height: widget.height ?? AppSizes.buttonHeight,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        // مطابقة صريحة لـ onPressed هنا أيضاً — بدون هذا، المُتحسِّس الخارجي
        // (لأجل حركة الانكماش فقط) والمُتحسِّس الداخلي لـ ElevatedButton
        // يتنافسان على نفس اللمسة، وحسم "ساحة الإيماءات" (gesture arena) قد
        // يختلف بين لمسة إصبع حقيقية ولمسة مُحاكاة (مثل أدوات الاختبار) —
        // وجدنا هذا فعلياً: لمسات ADB المُصطنَعة كانت تُبتلَع بصمت بلا استدعاء
        // onPressed إطلاقاً رغم وصولها الفعلي للتطبيق.
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: widget.backgroundColor ?? Theme.of(context).colorScheme.primary,
              foregroundColor: widget.foregroundColor ?? Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: widget.borderRadius ?? BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.text,
                          style: AppTextStyles.button,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (widget.isExpanded) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}