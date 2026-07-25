import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';

class AppCard extends StatefulWidget {
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

  /// لون تأثير اللمس (splash/highlight) — اختياري، يفيد عندما تريد شاشة معيّنة
  /// موجة لمس متناسقة مع هوية العنصر (مثل لون الفندق) بدل لون الثيم العام
  /// الافتراضي. بلا قيمة = السلوك القديم بلا أي تغيير.
  final Color? splashColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.identityAccent,
    this.splashColor,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

/// نفس بنية الرسم السابقة تماماً (BorderDirectional بلا أي قيد ارتفاع —
/// راجع تعليق [AppCard.identityAccent] عن مشكلة IntrinsicHeight القديمة، لم
/// تُمَس هنا إطلاقاً) + ظل مزدوج أكثر نعومة وعمقاً (طبقة قريبة + طبقة بعيدة
/// خفيفة) وانكماش لمسي خفيف عند البطاقات القابلة للضغط، لمظهر أكثر فخامة.
class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);

    return Container(
      margin: widget.margin,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            splashColor: widget.splashColor,
            highlightColor: widget.splashColor?.withValues(alpha: 0.5),
            child: ClipRRect(
              borderRadius: radius,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.color ?? Theme.of(context).cardColor,
                  borderRadius: radius,
                  border: widget.identityAccent != null ? BorderDirectional(start: BorderSide(color: widget.identityAccent!, width: 4)) : null,
                  boxShadow: [
                    BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2)),
                    BoxShadow(color: AppColors.shadow.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: Padding(
                  padding: widget.padding ?? const EdgeInsets.all(16),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
