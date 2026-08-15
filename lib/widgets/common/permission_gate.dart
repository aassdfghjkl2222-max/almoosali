import 'package:flutter/material.dart';

import '../../services/permission_service.dart';

/// يغلّف أي شاشة حساسة بفحص صلاحية حقيقي — نقطة الإنفاذ المركزية الوحيدة
/// لحجب شاشة كاملة. حتى لو وصل المستخدم لهذه الشاشة عبر تنقّل مباشر يتجاوز
/// حجب لوحة التحكم/القائمة الجانبية (البند 10 من متطلبات نظام الصلاحيات)،
/// يُعرَض "غير مصرَّح" بدل المحتوى الفعلي بلا أي استثناء. راجع PermissionService.
class PermissionGate extends StatelessWidget {
  final String permission;
  final int? hotelId;
  final Widget child;

  const PermissionGate({super.key, required this.permission, this.hotelId, required this.child});

  @override
  Widget build(BuildContext context) {
    if (PermissionService.instance.hasPermission(permission, hotelId: hotelId)) return child;
    return Scaffold(
      appBar: AppBar(title: const Text("غير مصرَّح"), elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              const Text("ليس لديك صلاحية الوصول لهذه الشاشة", textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
