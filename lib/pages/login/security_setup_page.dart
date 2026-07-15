import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_text_styles.dart';
import '../../services/security_service.dart';
import '../dashboard/pages/hotels_page.dart';

class SecuritySetupPage extends StatefulWidget {
  const SecuritySetupPage({super.key});

  @override
  State<SecuritySetupPage> createState() => _SecuritySetupPageState();
}

class _SecuritySetupPageState extends State<SecuritySetupPage> {
  int _pinLength = 4;
  String _pin = "";
  String _confirmPin = "";
  bool _isConfirming = false;
  final _securityService = SecurityService.instance;

  void _handleNumberPress(String number) {
    setState(() {
      if (!_isConfirming) {
        if (_pin.length < _pinLength) {
          _pin += number;
          if (_pin.length == _pinLength) {
            _isConfirming = true;
          }
        }
      } else {
        if (_confirmPin.length < _pinLength) {
          _confirmPin += number;
          if (_confirmPin.length == _pinLength) {
            _verifyAndSave();
          }
        }
      }
    });
  }

  void _handleDelete() {
    setState(() {
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyAndSave() async {
    if (_pin == _confirmPin) {
      await _securityService.setPin(_pin);
      await _securityService.setPinLength(_pinLength);
      
      if (!mounted) return;
      _showBiometricPrompt();
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الرموز غير متطابقة، حاول مرة أخرى")),
      );
      setState(() {
        _pin = "";
        _confirmPin = "";
        _isConfirming = false;
      });
    }
  }

  Future<void> _showBiometricPrompt() async {
    final canCheck = await _securityService.canCheckBiometrics();
    if (!canCheck) {
      _finishSetup();
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text("تفعيل البصمة", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("هل ترغب في تفعيل الدخول بالبصمة لتسريع الدخول؟"),
        actions: [
          TextButton(
            onPressed: () {
              _securityService.setBiometricEnabled(false);
              Navigator.pop(context);
              _finishSetup();
            },
            child: const Text("لاحقاً"),
          ),
          TextButton(
            onPressed: () async {
              await _securityService.setBiometricEnabled(true);
              if (!context.mounted) return;
              Navigator.pop(context);
              _finishSetup();
            },
            child: const Text("موافق", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _finishSetup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HotelsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.security, size: 80, color: AppColors.primary),
            const SizedBox(height: 20),
            Text(
              _isConfirming ? "تأكيد الرمز السري" : "إنشاء رمز سري",
              style: AppTextStyles.headline,
            ),
            const SizedBox(height: 10),
            if (!_isConfirming)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLengthOption(4),
                  const SizedBox(width: 20),
                  _buildLengthOption(6),
                ],
              ),
            const Spacer(),
            _buildPinDisplay(),
            const Spacer(),
            _buildKeyboard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLengthOption(int length) {
    bool isSelected = _pinLength == length;
    return InkWell(
      onTap: () => setState(() {
        _pinLength = length;
        _pin = "";
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primary),
        ),
        child: Text(
          "$length أرقام",
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPinDisplay() {
    String currentDisplay = _isConfirming ? _confirmPin : _pin;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (index) {
        bool hasValue = index < currentDisplay.length;
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasValue ? AppColors.primary : Theme.of(context).dividerColor,
          ),
        );
      }),
    );
  }

  Widget _buildKeyboard() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((number) => _buildKey(number)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            _buildKey('0'),
            _buildKey('del', icon: Icons.backspace_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: InkWell(
        onTap: () {
          if (value == 'del') {
            _handleDelete();
          } else {
            _handleNumberPress(value);
          }
        },
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: Theme.of(context).colorScheme.onSurface)
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
