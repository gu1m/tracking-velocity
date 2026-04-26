import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../onboarding/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final loc = context.watch<LocationService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _UserCard(name: user?.displayName, email: user?.email ?? user?.phone),
          const SizedBox(height: 16),
          const _SectionTitle('Tracking'),
          _SwitchTile(
            icon: Icons.power_settings_new_rounded,
            title: 'Serviço em segundo plano',
            subtitle: loc.isServiceRunning
                ? 'Ativo — registrando quando você acelerar'
                : 'Pausado — nada será registrado',
            value: loc.isServiceRunning,
            onChanged: (v) {
              if (v) {
                loc.startBackgroundService();
              } else {
                loc.pauseService();
              }
            },
          ),
          _Tile(
            icon: Icons.tune_rounded,
            title: 'Limite mínimo de gravação',
            subtitle: '${LocationService.minTrackingSpeedKmh.toInt()} km/h',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.battery_saver_rounded,
            title: 'Tempo até encerrar viagem',
            subtitle: '${LocationService.tripIdleTimeout.inMinutes} minutos parado',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          const _SectionTitle('Privacidade'),
          _Tile(
            icon: Icons.cloud_download_rounded,
            title: 'Baixar meus dados',
            subtitle: 'Exporta tudo o que está no aparelho',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.delete_outline_rounded,
            title: 'Apagar histórico',
            subtitle: 'Remove todas as viagens deste aparelho',
            onTap: () {},
            destructive: true,
          ),
          const SizedBox(height: 8),
          const _SectionTitle('Conta'),
          _Tile(
            icon: Icons.help_outline_rounded,
            title: 'Suporte',
            subtitle: 'Atendimento por WhatsApp',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.description_outlined,
            title: 'Termos de uso',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.lock_outline_rounded,
            title: 'Política de privacidade',
            onTap: () {},
          ),
          _Tile(
            icon: Icons.logout_rounded,
            title: 'Sair',
            destructive: true,
            onTap: () async {
              await context.read<AuthService>().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Tracking Velocidade • v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String? name;
  final String? email;
  const _UserCard({this.name, this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text(
              (name ?? 'U').substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name ?? 'Usuário',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    )),
                if (email != null)
                  Text(email!,
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            )),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: const TextStyle(color: AppColors.textSecondary))
            : null,
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.textPrimary),
        title: Text(title),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppColors.textSecondary)),
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}
