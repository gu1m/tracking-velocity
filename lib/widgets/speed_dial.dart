import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Indicador grande de velocidade — peça central do dashboard.
/// Estilo inspirado no Waze: círculo limpo com número grande.
class SpeedDial extends StatelessWidget {
  final double speedKmh;
  final bool isTracking;

  const SpeedDial({
    super.key,
    required this.speedKmh,
    required this.isTracking,
  });

  @override
  Widget build(BuildContext context) {
    final color = isTracking ? AppColors.success : AppColors.primary;
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
        border: Border.all(color: color, width: 6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            speedKmh.toStringAsFixed(0),
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'km/h',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isTracking ? 'GRAVANDO' : 'Aguardando',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
