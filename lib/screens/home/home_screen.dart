import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/score_gauge.dart';
import '../../widgets/speed_dial.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationService>();
    final user = context.watch<AuthService>().currentUser;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppColors.headerGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Olá, ${user?.displayName ?? 'motorista'}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Seu tracking está protegendo você.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _StatusCard(
                  serviceRunning: loc.isServiceRunning,
                  isTracking: loc.isTrackingActive,
                ),
                const SizedBox(height: 24),
                Center(
                  child: SpeedDial(
                    speedKmh: loc.currentSpeedKmh,
                    isTracking: loc.isTrackingActive,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            loc.currentLocation,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Resumo de hoje',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.timer_rounded,
                        color: AppColors.primary,
                        label: 'Tempo gravado',
                        value:
                            '${loc.todayActiveTime.inHours}h ${loc.todayActiveTime.inMinutes.remainder(60)}min',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.straighten_rounded,
                        color: AppColors.accent,
                        label: 'Distância',
                        value: '${loc.todayDistanceKm.toStringAsFixed(1)} km',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.speed_rounded,
                        color: AppColors.success,
                        label: 'Vel. média',
                        value: '${loc.todayAvgSpeedKmh.toStringAsFixed(0)} km/h',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.flag_rounded,
                        color: AppColors.danger,
                        label: 'Pico',
                        value: '${loc.todayMaxSpeedKmh.toStringAsFixed(0)} km/h',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // ── Score do condutor ─────────────────────────────────────
                if (loc.isServiceRunning)
                  _ScoreCard(loc: loc),
                const SizedBox(height: 24),
                Card(
                  color: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide.none,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.primaryDark),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'O app só registra acima de 10 km/h. '
                            'Quando você está parado ou andando, ele economiza bateria.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool serviceRunning;
  final bool isTracking;
  const _StatusCard({
    required this.serviceRunning,
    required this.isTracking,
  });

  @override
  Widget build(BuildContext context) {
    final color = !serviceRunning
        ? AppColors.danger
        : (isTracking ? AppColors.success : AppColors.primary);
    final label = !serviceRunning
        ? 'Serviço pausado'
        : (isTracking
            ? 'Gravando velocidade'
            : 'Aguardando você acelerar');
    final desc = !serviceRunning
        ? 'Reative em Ajustes para continuar protegido.'
        : (isTracking
            ? 'A cada minuto sua velocidade média é salva localmente.'
            : 'Quando passar de 10 km/h o tracking inicia automaticamente.');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTracking
                  ? Icons.fiber_manual_record_rounded
                  : (serviceRunning
                      ? Icons.check_circle_rounded
                      : Icons.pause_circle_rounded),
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(
                      fontSize: 12,
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

/// Card de pontuação do condutor — exibe o gauge ao vivo durante o tracking.
class _ScoreCard extends StatelessWidget {
  final LocationService loc;
  const _ScoreCard({required this.loc});

  @override
  Widget build(BuildContext context) {
    final score = loc.currentTripScore;
    final isActive = loc.isTrackingActive;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Pontuação do condutor',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Ao vivo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ScoreGauge(score: score.value, size: 130),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ScoreDetail(
                      label: 'Velocidade máxima',
                      value: '${loc.todayMaxSpeedKmh.toStringAsFixed(0)} km/h',
                      icon: Icons.speed_rounded,
                      color: loc.todayMaxSpeedKmh > 100
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                    const SizedBox(height: 10),
                    _ScoreDetail(
                      label: 'Velocidade média',
                      value: '${loc.todayAvgSpeedKmh.toStringAsFixed(0)} km/h',
                      icon: Icons.av_timer_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    _ScoreDetail(
                      label: 'Tempo em movimento',
                      value:
                          '${loc.todayActiveTime.inHours}h ${loc.todayActiveTime.inMinutes.remainder(60)}min',
                      icon: Icons.timer_rounded,
                      color: AppColors.accent,
                    ),
                    if (score.violations > 0) ...[
                      const SizedBox(height: 10),
                      _ScoreDetail(
                        label: 'Infrações acima de 100',
                        value: '${score.violations} min',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.danger,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!isActive && loc.isServiceRunning) ...[
            const SizedBox(height: 12),
            Text(
              'O score será atualizado assim que você iniciar uma nova viagem.',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreDetail extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ScoreDetail({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
