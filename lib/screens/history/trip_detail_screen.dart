import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/driver_score.dart';
import '../../models/trip.dart';
import '../../services/export_service.dart';
import '../../services/score_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/score_gauge.dart';

/// Tela de detalhes de uma viagem específica.
/// Mostra:
///  - cabeçalho com origem/destino, hora, distância
///  - gráfico de velocidade ao longo do tempo
///  - lista de registros minuto a minuto
///  - botão para exportar essa viagem em Excel (prova p/ recorrer da multa)
class TripDetailScreen extends StatefulWidget {
  final Trip trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final df = DateFormat("dd 'de' MMM 'de' yyyy", 'pt_BR');
    final tf = DateFormat('HH:mm', 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da viagem'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Compartilhar',
            onPressed: _exporting ? null : _export,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  df.format(t.startedAt),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tf.format(t.startedAt)} → ${t.endedAt != null ? tf.format(t.endedAt!) : '–'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _whitePillRow([
                  ('${t.avgSpeedKmh.toStringAsFixed(0)} km/h', 'Média'),
                  ('${t.maxSpeedKmh.toStringAsFixed(0)} km/h', 'Pico'),
                  ('${t.distanceKm.toStringAsFixed(1)} km', 'Distância'),
                  ('${t.duration.inMinutes} min', 'Duração'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _RouteCard(trip: t),
          const SizedBox(height: 24),
          _ScoreCard(trip: t),
          const SizedBox(height: 24),
          const Text('Velocidade no tempo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            height: 220,
            child: _SpeedChart(trip: t),
          ),
          const SizedBox(height: 24),
          const Text('Registros minuto a minuto',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Cada linha é a velocidade média durante 1 minuto.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...t.records.map((r) => _RecordTile(record: r)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exporting ? null : _export,
        backgroundColor: AppColors.accent,
        icon: _exporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.file_download_rounded),
        label: Text(_exporting ? 'Gerando…' : 'Exportar prova (Excel)'),
      ),
    );
  }

  Widget _whitePillRow(List<(String, String)> items) {
    return Row(
      children: items
          .map((e) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(e.$1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          )),
                      Text(e.$2,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          )),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await ExportService().exportTrip(widget.trip);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relatório gerado!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

/// Card de pontuação do condutor na tela de detalhes da viagem.
class _ScoreCard extends StatelessWidget {
  final Trip trip;
  const _ScoreCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    // Usa o score salvo na viagem ou recalcula a partir dos records disponíveis.
    final score = trip.driverScore ??
        (trip.records.isNotEmpty
            ? ScoreService.fromRecords(
                records: trip.records,
                maxSpeedKmh: trip.maxSpeedKmh,
                avgSpeedKmh: trip.avgSpeedKmh,
              )
            : ScoreService.fromSummary(
                maxSpeedKmh: trip.maxSpeedKmh,
                avgSpeedKmh: trip.avgSpeedKmh,
                durationMinutes: trip.duration.inMinutes,
              ));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Pontuação do condutor',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ScoreGauge(score: score.value, size: 120),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _breakdown(
                      label: 'Categoria',
                      value: '${score.category.emoji} ${score.category.label}',
                      color: score.category.color,
                    ),
                    const SizedBox(height: 8),
                    _breakdown(
                      label: 'Vel. máxima registrada',
                      value: '${score.maxSpeed.toStringAsFixed(0)} km/h',
                      color: score.maxSpeed > 100
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                    const SizedBox(height: 8),
                    _breakdown(
                      label: 'Vel. média',
                      value: '${score.avgSpeed.toStringAsFixed(0)} km/h',
                      color: AppColors.primary,
                    ),
                    if (score.violations > 0) ...[
                      const SizedBox(height: 8),
                      _breakdown(
                        label: 'Minutos acima de 100',
                        value: '${score.violations} min',
                        color: AppColors.accent,
                      ),
                    ],
                    if (score.severeViolations > 0) ...[
                      const SizedBox(height: 8),
                      _breakdown(
                        label: 'Minutos acima de 130',
                        value: '${score.severeViolations} min',
                        color: AppColors.danger,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            score.value >= 90
                ? 'Excelente! Você dirigiu de forma segura e responsável.'
                : score.value >= 75
                    ? 'Boa condução. Mantenha a velocidade controlada para pontuar mais.'
                    : score.value >= 60
                        ? 'Condução regular. Reduza a velocidade máxima para melhorar.'
                        : 'Atenção: foram registradas velocidades acima do recomendado.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdown({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            )),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            )),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  final Trip trip;
  const _RouteCard({required this.trip});

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
          _row(Icons.trip_origin, AppColors.primary, 'Origem',
              trip.startAddress),
          Container(
            margin: const EdgeInsets.only(left: 9),
            width: 2,
            height: 24,
            color: AppColors.divider,
          ),
          _row(Icons.location_on_rounded, AppColors.accent, 'Destino',
              trip.endAddress ?? 'Em andamento…'),
        ],
      ),
    );
  }

  Widget _row(IconData icon, Color color, String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 2),
              Text(text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final dynamic record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final tf = DateFormat('HH:mm');
    final color = record.speedKmh >= 100
        ? AppColors.danger
        : (record.speedKmh >= 80 ? AppColors.accent : AppColors.success);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${record.speedKmh.toStringAsFixed(0)} km/h',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tf.format(record.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    )),
                Text(record.address ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedChart extends StatelessWidget {
  final Trip trip;
  const _SpeedChart({required this.trip});

  @override
  Widget build(BuildContext context) {
    final spots = trip.records
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.speedKmh))
        .toList();
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 130,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 30,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.25),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
