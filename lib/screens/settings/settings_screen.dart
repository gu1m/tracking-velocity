import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_screen.dart';
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
          _InfoTile(
            icon: Icons.tune_rounded,
            title: 'Limite mínimo de gravação',
            subtitle: '${LocationService.minTrackingSpeedKmh.toInt()} km/h',
          ),
          _InfoTile(
            icon: Icons.battery_saver_rounded,
            title: 'Tempo até encerrar viagem',
            subtitle: '${LocationService.tripIdleTimeout.inMinutes} minutos parado',
          ),
          const SizedBox(height: 8),
          const _SectionTitle('Privacidade'),
          _Tile(
            icon: Icons.cloud_download_rounded,
            title: 'Baixar meus dados',
            subtitle: 'Exporta todas as viagens em Excel',
            onTap: () => _exportData(context),
          ),
          _Tile(
            icon: Icons.delete_outline_rounded,
            title: 'Apagar histórico',
            subtitle: 'Remove todas as viagens deste aparelho',
            onTap: () => _confirmClearHistory(context),
            destructive: true,
          ),
          const SizedBox(height: 8),
          const _SectionTitle('Conta'),
          _Tile(
            icon: Icons.help_outline_rounded,
            title: 'Suporte',
            subtitle: 'Enviar e-mail para o time',
            onTap: () => _openSupport(),
          ),
          _Tile(
            icon: Icons.description_outlined,
            title: 'Termos de uso',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsScreen()),
            ),
          ),
          _Tile(
            icon: Icons.lock_outline_rounded,
            title: 'Política de privacidade',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          _Tile(
            icon: Icons.person_remove_outlined,
            title: 'Excluir conta',
            subtitle: 'Remove todos os seus dados permanentemente',
            destructive: true,
            onTap: () => _confirmDeleteAccount(context),
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

  Future<void> _exportData(BuildContext context) async {
    final trips = context.read<StorageService>().trips;
    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma viagem registrada para exportar.')),
      );
      return;
    }
    try {
      await ExportService().exportTrips(trips);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar: $e')),
      );
    }
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar histórico'),
        content: const Text(
          'Todas as viagens salvas neste aparelho serão removidas. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<StorageService>().clearAllData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Histórico apagado.')),
    );
  }

  Future<void> _openSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'contato@trackingvelocidade.com.br',
      query: 'subject=Suporte%20Tracking%20Velocidade',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta'),
        content: const Text(
          'Todos os seus dados (viagens, registros e assinatura) serão '
          'removidos permanentemente. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir permanentemente'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<AuthService>().deleteAccount();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir conta: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
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

// Tile somente leitura — exibe informação sem indicar que é clicável.
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    this.subtitle,
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
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title,
            style: const TextStyle(color: AppColors.textPrimary)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: const TextStyle(color: AppColors.textSecondary))
            : null,
      ),
    );
  }
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
