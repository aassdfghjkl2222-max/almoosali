import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../services/security_service.dart';
import '../dashboard/pages/hotels_page.dart';

class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> with SingleTickerProviderStateMixin {
  final _securityService = SecurityService.instance;
  String _enteredPin = "";
  int _pinLength = 4;
  bool _isLoading = true;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _initSecurity();
  }

  Future<void> _initSecurity() async {
    _pinLength = await _securityService.getPinLength();
    setState(() => _isLoading = false);

    final bioEnabled = await _securityService.isBiometricEnabled();
    if (bioEnabled) {
      _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final success = await _securityService.authenticateWithBiometrics();
    if (success) {
      _onLoginSuccess();
    }
  }

  void _onLoginSuccess() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HotelsPage()),
    );
  }

  void _handleNumberPress(String number) {
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += number;
      });

      if (_enteredPin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _handleDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    final isValid = await _securityService.verifyPin(_enteredPin);
    if (isValid) {
      _onLoginSuccess();
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      setState(() {
        _enteredPin = "";
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("الرمز غير صحيح."),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.lock_outline_rounded, size: 80, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text(
              "أدخل رمز الدخول",
              style: AppTextStyles.headline,
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Padding(
                  padding: EdgeInsets.only(left: _shakeAnimation.value, right: -_shakeAnimation.value),
                  child: child,
                );
              },
              child: _buildPinDisplay(),
            ),
            const Spacer(),
            _buildKeyboard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (index) {
        bool hasValue = index < _enteredPin.length;
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasValue ? AppColors.primary : AppColors.border,
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
            _buildKey('bio', icon: Icons.fingerprint),
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
        onTap: () async {
          if (value == 'del') {
            _handleDelete();
          } else if (value == 'bio') {
            final canBio = await _securityService.canCheckBiometrics();
            if (canBio) {
               _authenticateWithBiometrics();
            }
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
                ? Icon(icon, color: icon == Icons.fingerprint ? AppColors.primary : AppColors.textPrimary)
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
