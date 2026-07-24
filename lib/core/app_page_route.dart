import 'package:flutter/material.dart';

/// انتقال صفحة موحَّد للتطبيق بأكمله (تلاشٍ + انزلاق خفيف لأعلى) — يحل محل
/// التطبيقات المتكررة السابقة لنفس الفكرة (كانت مكرَّرة محلياً في أكثر من
/// شاشة). استخدمه بدل `MaterialPageRoute` في أي تنقّل يريد لمسة أكثر
/// احترافية (فتح قسم رئيسي، فتح شاشة إدارة) — الانتقالات الفرعية الكثيرة
/// (فتح نموذج إضافة بسيط، إلخ) يمكن أن تبقى MaterialPageRoute العادية بلا
/// أي مشكلة، فلا حاجة لاستبدال كل استخدام في التطبيق دفعة واحدة.
Route<T> premiumRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, animation, secondaryAnimation) => page,
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
