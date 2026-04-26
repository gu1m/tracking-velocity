import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';

/// Tela crítica do app: explica que precisamos da permissão de
/// localização SEMPRE (background) para funcionar como prometido.
///
/// Boas práticas iOS/Android: sempre explicar ANTES de pedir,
/// dar opção de "abrir ajustes" caso o usuário tenha negado.
class PermissionsScreen extends StatefulWidget {
  final Future<void> Function() onGranted;
  const PermissionsScreen({super.key, required this.onGranted});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      // Primeiro pede whileInUse, depois faz upgrade para always.
      // Esse é o caminho correto exigido pelo iOS e pelo Android 10+.
      final whileInUse = await Permission.locationWhenInUse.request();
      if (whileInUse.isGranted) {
        await Permission.locationAlways.request();
      }

      if (!mounted) return;
      await widget.onGranted();
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.my_location_rounded,
                    size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Liberação de localização',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Para registrar a sua velocidade automaticamente, '
                'precisamos da localização do GPS — inclusive em segundo plano.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              const _Bullet(
                icon: Icons.battery_charging_full_rounded,
                title: 'Bateria preservada',
                description:
                    'O app só lê o GPS quando você está em movimento (>10 km/h).',
              ),
              const _Bullet(
                icon: Icons.lock_outline_rounded,
                title: 'Privacidade',
                description:
                    'Seus dados ficam no aparelho. Nada é compartilhado sem você pedir.',
              ),
              const _Bullet(
                icon: Icons.shield_rounded,
                title: 'Pronto pra defesa',
                description:
                    'Quando precisar, exporte um relatório com todos os dados de GPS.',
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _requesting ? null : _request,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(_requesting
                    ? 'Aguardando…'
                    : 'Permitir localização'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  // Permite seguir mesmo sem permissão (mas o serviço
                  // não vai gravar nada). Mantém a fricção baixa.
                  await widget.onGranted();
                },
                child: const Text('Agora não'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _Bullet({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
