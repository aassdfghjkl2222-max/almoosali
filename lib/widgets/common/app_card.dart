import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;

  /// شريط رفيع بلون هوية الفندق الحالي عند الحافة البادئة للبطاقة (اختياري).
  /// طبقة هوية بصرية إضافية فوق التصميم الحالي، لا تغيّر [color] الوظيفي للبطاقة
  /// ولا أي محتوى داخلها — مرّر مثلاً Theme.of(context).colorScheme.primary.
  ///
  /// يُرسَم عبر [BorderDirectional] على حافة "البداية" (start — يمين الشاشة في
  /// RTL) بدل صف Row + IntrinsicHeight المستخدَم سابقاً: IntrinsicHeight كان
  /// يفرض على [child] ارتفاعاً محسوباً مسبقاً (تقديرياً) بدل ارتفاعه الطبيعي،
  /// وأي تقدير غير دقيق (شائع مع TextField/InputDecoration) يسبب
  /// "BOTTOM OVERFLOWED" فوراً عند تمدد المحتوى (ظهور حقول إضافية). الحل
  /// الحالي بلا أي قيد ارتفاع مطلقاً — البطاقة تتمدد بحرية تماماً كأي Container عادي.
  final Color? identityAccent;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.identityAccent,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ClipRRect(
            borderRadius: radius,
            child: Container(
              decoration: BoxDecoration(
                color: color ?? Theme.of(context).cardColor,
                borderRadius: radius,
                border: identityAccent != null ? BorderDirectional(start: BorderSide(color: identityAccent!, width: 4)) : null,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
