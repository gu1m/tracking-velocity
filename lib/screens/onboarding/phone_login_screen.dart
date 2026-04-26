import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_shell.dart';
import 'permissions_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneCtrl = TextEditingController(text: '+55 ');
  final _codeCtrl = TextEditingController();
  String? _verificationId;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login por telefone')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_verificationId == null) ...[
                const Text(
                  'Vamos enviar um código por SMS para confirmar seu número.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _sendCode,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Enviar código'),
                ),
              ] else ...[
                Text(
                  'Digite o código enviado para ${_phoneCtrl.text}.',
                  style: const TextStyle(
                      color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: '------',
                    counterText: '',
                  ),
                  maxLength: 6,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyCode,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirmar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendCode() async {
    setState(() => _loading = true);
    try {
      final id = await context
          .read<AuthService>()
          .sendSmsCode(_phoneCtrl.text.trim());
      if (!mounted) return;
      setState(() => _verificationId = id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthService>().verifySmsCode(
            verificationId: _verificationId!,
            code: _codeCtrl.text,
            phoneNumber: _phoneCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PermissionsScreen(
            onGranted: () async {
              await context.read<LocationService>().startBackgroundService();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AppShell()),
                (_) => false,
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
