import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_theme.dart';
import 'core/hotel_session.dart';
import 'core/hotel_visual_identity.dart';
import 'models/hotel.dart';
import 'pages/login/security_setup_page.dart';
import 'pages/login/pin_login_page.dart';
import 'services/security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final hasPin = await SecurityService.instance.hasPin();

  runApp(ManazelApp(hasPin: hasPin));
}

class ManazelApp extends StatelessWidget {
  final bool hasPin;
  const ManazelApp({super.key, required this.hasPin});

  @override
  Widget build(BuildContext context) {
    // ثيم التطبيق بأكمله يتبع الفندق الحالي (HotelSession.current) —
    // هذا هو المصدر الوحيد للحقيقة لكل ألوان التطبيق: أي شاشة أو Dialog
    // أو BottomSheet أو SnackBar تُبنى من هذه اللحظة فصاعداً سترث هذا
    // الثيم تلقائياً، بلا حاجة لأي تعديل داخل تلك الشاشة نفسها.
    return ValueListenableBuilder<Hotel?>(
      valueListenable: HotelSession.current,
      builder: (context, currentHotel, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Manazel',
          theme: AppTheme.createTheme(HotelVisualIdentity.identityForHotel(currentHotel)),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ar', 'SA'),
            Locale('en', 'US'),
          ],
          locale: const Locale('ar', 'SA'),
          home: hasPin ? const PinLoginPage() : const SecuritySetupPage(),
        );
      },
    );
  }
}