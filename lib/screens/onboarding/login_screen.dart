import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'email_login_screen.dart';
import 'phone_login_screen.dart';

/// Tela inicial de login. Apresenta os 4 métodos: Google, Apple,
/// E-mail e Telefone (SMS).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.speed_rounded,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              const Text(
                'Bem-vindo!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Faça login uma única vez. Depois é só dirigir — '
                'a gente registra sua velocidade automaticamente.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continuar com Google',
                color: const Color(0xFFDB4437),
                onTap: () => _handle(
                  context,
                  () => context.read<AuthService>().signInWithGoogle(),
                ),
              ),
              const SizedBox(height: 12),
              _SocialButton(
                icon: Icons.apple_rounded,
                label: 'Continuar com Apple',
                color: AppColors.textPrimary,
                onTap: () => _handle(
                  context,
                  () => context.read<AuthService>().signInWithApple(),
                ),
              ),
              const SizedBox(height: 12),
              _SocialButton(
                icon: Icons.phone_iphone_rounded,
                label: 'Continuar com telefone',
                color: AppColors.success,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PhoneLoginScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _SocialButton(
                icon: Icons.email_rounded,
                label: 'Continuar com e-mail',
                color: AppColors.primary,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const EmailLoginScreen()),
                ),
              ),
              const SizedBox(height: 24),
              const Text.rich(
                TextSpan(
                  text: 'Ao continuar você concorda com os ',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: 'Termos de Uso',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: ' e a '),
                    TextSpan(
                      text: 'Política de Privacidade',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    Future<void> Function() future,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await future();
      if (!context.mounted) return;
      Navigator.of(context).pop(); // fecha loading dialog
      // Remove todas as rotas para que o _Root (agora mostrando AppShell) fique visível.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 24),
      label: Text(label),
    );
  }
}
