import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_theme.dart';
import 'core/app_theme_controller.dart';
import 'core/hotel_session.dart';
import 'core/hotel_visual_identity.dart';
import 'core/training_mode_controller.dart';
import 'data/supabase/supabase_config.dart';
import 'models/hotel.dart';
import 'pages/login/security_setup_page.dart';
import 'pages/login/pin_login_page.dart';
import 'repositories/document_repository.dart';
import 'services/document_notification_service.dart';
import 'services/security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final hasPin = await SecurityService.instance.hasPin();
  await AppThemeController.bootstrap();
  await TrainingModeController.bootstrap();

  // مزامنة سحابية (Supabase) — تهيئة صامتة، بلا أي تأثير على الإقلاع الحالي
  // إن لم تُمرَّر بيانات الاتصال عبر --dart-define (راجع SupabaseConfig).
  // لا تُوقِف الإقلاع أبداً إن فشلت (مثلاً بلا اتصال إنترنت عند أول تشغيل).
  if (SupabaseConfig.isConfigured) {
    try {
      await SupabaseConfig.initialize();
    } catch (_) {
      // يُعاد المحاولة عند أول استخدام فعلي للمزامنة من BackupPage.
    }
  }

  runApp(ManazelApp(hasPin: hasPin));

  // مزامنة شاملة صامتة لتنبيهات انتهاء المستندات عند كل إقلاع — بلا await
  // عمداً حتى لا تُؤخِّر ظهور أول شاشة.
  DocumentRepository().getAllDocuments().then(DocumentNotificationService.rescheduleAll);
}

class ManazelApp extends StatelessWidget {
  final bool hasPin;
  const ManazelApp({super.key, required this.hasPin});

  @override
  Widget build(BuildContext context) {
    // ثيم التطبيق بأكمله يتبع الفندق الحالي (HotelSession.current) والوضع
    // الداكن/حجم الخط/اللغة (AppThemeController) معاً — المصدر الوحيد
    // للحقيقة لكل مظهر التطبيق: أي شاشة أو Dialog أو BottomSheet أو
    // SnackBar تُبنى من هذه اللحظة فصاعداً تتبع هذا فوراً دون إعادة تشغيل
    // التطبيق ودون أي تعديل داخل تلك الشاشة نفسها.
    return ValueListenableBuilder<Hotel?>(
      valueListenable: HotelSession.current,
      builder: (context, currentHotel, _) {
        final identity = HotelVisualIdentity.identityForHotel(currentHotel);
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: AppThemeController.themeMode,
          builder: (context, mode, _) {
            return ValueListenableBuilder<double>(
              valueListenable: AppThemeController.fontScale,
              builder: (context, fontScale, _) {
                return ValueListenableBuilder<Locale>(
                  valueListenable: AppThemeController.locale,
                  builder: (context, locale, _) {
                    return MaterialApp(
                      debugShowCheckedModeBanner: false,
                      title: 'Manazel',
                      theme: AppTheme.createTheme(identity),
                      darkTheme: AppTheme.createTheme(identity, brightness: Brightness.dark),
                      themeMode: mode,
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)),
                          child: ValueListenableBuilder<bool>(
                            valueListenable: TrainingModeController.isActive,
                            builder: (context, isTraining, _) {
                              if (!isTraining) return child!;
                              return Column(
                                children: [
                                  SafeArea(
                                    bottom: false,
                                    child: Container(
                                      width: double.infinity,
                                      color: Colors.amber.shade800,
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: const Text(
                                        '🎓 وضع التدريب',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: child!),
                                ],
                              );
                            },
                          ),
                        );
                      },
                      localizationsDelegates: const [
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                      ],
                      supportedLocales: const [
                        Locale('ar', 'SA'),
                        Locale('en', 'US'),
                      ],
                      locale: locale,
                      home: hasPin ? const PinLoginPage() : const SecuritySetupPage(),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}