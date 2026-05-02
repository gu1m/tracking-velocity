import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/driver_score.dart';
import '../models/trip.dart';
import '../theme/app_theme.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;

  const TripCard({super.key, required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat("dd 'de' MMM • HH:mm", 'pt_BR');
    final maxColor = trip.maxSpeedKmh >= 100
        ? AppColors.danger
        : (trip.maxSpeedKmh >= 80 ? AppColors.accent : AppColors.success);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.route_rounded,
                        color: AppColors.primaryDark, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      df.format(trip.startedAt),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // Score badge (Fase 2) ou pico de velocidade (fallback).
                  if (trip.driverScore != null)
                    _ScoreBadge(score: trip.driverScore!)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: maxColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Pico ${trip.maxSpeedKmh.toStringAsFixed(0)} km/h',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: maxColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _addressRow(
                icon: Icons.trip_origin,
                color: AppColors.primary,
                text: trip.startAddress,
              ),
              const SizedBox(height: 6),
              _addressRow(
                icon: Icons.location_on_rounded,
                color: AppColors.accent,
                text: trip.endAddress ?? 'Em andamento…',
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat(
                    icon: Icons.speed_rounded,
                    label: 'Média',
                    value: '${trip.avgSpeedKmh.toStringAsFixed(0)} km/h',
                  ),
                  const SizedBox(width: 24),
                  _stat(
                    icon: Icons.straighten_rounded,
                    label: 'Distância',
                    value: '${trip.distanceKm.toStringAsFixed(1)} km',
                  ),
                  const SizedBox(width: 24),
                  _stat(
                    icon: Icons.schedule_rounded,
                    label: 'Duração',
                    value: '${trip.duration.inMinutes} min',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Column(
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Badge compacto de score — exibido no canto superior direito do TripCard.
class _ScoreBadge extends StatelessWidget {
  final DriverScore score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score.category.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            score.category.emoji,
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(width: 4),
          Text(
            '${score.value}pts',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
