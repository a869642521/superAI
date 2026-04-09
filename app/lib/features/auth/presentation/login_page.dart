import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/shared/widgets/gradient_button.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      setState(() => _error = '请输入11位手机号');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).login(phone);
    } catch (e) {
      setState(() => _error = '登录失败，请检查网络连接');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              AuraAvatar(
                fallbackEmoji: '✨',
                size: 96,
                gradientColors: const [
                  StarpathColors.brandPurple,
                  StarpathColors.brandBlue,
                ],
                state: CompanionState.excited,
              ),
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (bounds) =>
                    StarpathColors.brandGradient.createShader(bounds),
                child: const Text(
                  'Starpath',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '遇见你的AI伙伴',
                style: TextStyle(
                  fontSize: 16,
                  color: StarpathColors.textSecondary,
                ),
              ),
              const Spacer(),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: InputDecoration(
                  hintText: '输入手机号',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  counterText: '',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 16),
              GradientButton(
                text: '登录 / 注册',
                onPressed: _login,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 12),
              Text(
                '登录即表示同意《用户协议》和《隐私政策》',
                style: TextStyle(
                  fontSize: 12,
                  color: StarpathColors.textTertiary,
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
