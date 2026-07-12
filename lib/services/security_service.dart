import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._();
  SecurityService._();

  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  static const _pinKey = 'user_pin';
  static const _pinLengthKey = 'pin_length';
  static const _biometricEnabledKey = 'biometric_enabled';

  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null;
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
    await _storage.write(key: _pinLengthKey, value: pin.length.toString());
  }

  Future<bool> verifyPin(String pin) async {
    final savedPin = await _storage.read(key: _pinKey);
    return savedPin == pin;
  }

  Future<int> getPinLength() async {
    final lengthStr = await _storage.read(key: _pinLengthKey);
    return int.tryParse(lengthStr ?? '4') ?? 4;
  }

  Future<void> setPinLength(int length) async {
    await _storage.write(key: _pinLengthKey, value: length.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final enabled = await _storage.read(key: _biometricEnabledKey);
    return enabled == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// أنواع المصادقة البيومترية المتاحة فعلياً على هذا الجهاز (بصمة/وجه/غيرها) —
  /// تُستخدم لعرض تسمية دقيقة في شاشة الإعدادات ("تسجيل الدخول بالوجه" فقط
  /// إن كان الجهاز يدعمه فعلاً) دون إضافة مفتاح تخزين منفصل لكل نوع.
  Future<List<BiometricType>> getAvailableBiometricTypes() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return false;

      return await _localAuth.authenticate(
        localizedReason: 'يرجى المصادقة للدخول إلى التطبيق',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
