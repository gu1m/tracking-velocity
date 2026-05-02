import '../models/driver_score.dart';
import '../models/speed_record.dart';

/// Calcula a pontuação de condução (0–100) a partir dos dados de uma viagem.
///
/// Algoritmo (baseado no pior evento registrado + velocidade média sustentada):
///
/// Base: 100 pts
/// Penalidades por velocidade máxima:
///   > 180 km/h → −35   > 150 km/h → −25   > 130 km/h → −15
///   > 110 km/h → −8    > 100 km/h → −4
///
/// Penalidades por velocidade média:
///   > 95 km/h → −10    > 85 km/h → −5    > 75 km/h → −2
///
/// Penalidades por minutos acima do limite (quando records disponíveis):
///   Cada minuto com pico > 130 → −5
///   Cada minuto com pico > 100 → −2
///
/// Bônus por viagem segura e longa: +2 se duração ≥ 20 min e máxima ≤ 100 km/h
class ScoreService {
  ScoreService._();

  // ── Score rápido (apenas dos campos agregados da viagem) ─────────────────

  /// Calcula o score a partir do resumo da viagem — sem precisar carregar
  /// os registros individuais. Usado no TripCard e no histórico.
  static DriverScore fromSummary({
    required double maxSpeedKmh,
    required double avgSpeedKmh,
    required int durationMinutes,
  }) {
    double score = 100.0;
    int violations = 0;
    int severe = 0;

    // Penalidade por pico de velocidade.
    if (maxSpeedKmh > 180) {
      score -= 35;
      severe++;
    } else if (maxSpeedKmh > 150) {
      score -= 25;
      severe++;
    } else if (maxSpeedKmh > 130) {
      score -= 15;
      severe++;
    } else if (maxSpeedKmh > 110) {
      score -= 8;
      violations++;
    } else if (maxSpeedKmh > 100) {
      score -= 4;
      violations++;
    }

    // Penalidade por velocidade média sustentada.
    if (avgSpeedKmh > 95) {
      score -= 10;
    } else if (avgSpeedKmh > 85) {
      score -= 5;
    } else if (avgSpeedKmh > 75) {
      score -= 2;
    }

    // Bônus por viagem longa dentro do limite.
    if (durationMinutes >= 20 && maxSpeedKmh <= 100) {
      score = (score + 2).clamp(0, 100);
    }

    final s = score.round().clamp(0, 100);
    return DriverScore(
      value: s,
      category: ScoreCategoryX.fromValue(s),
      violations: violations,
      severeViolations: severe,
      maxSpeed: maxSpeedKmh,
      avgSpeed: avgSpeedKmh,
    );
  }

  // ── Score detalhado (com registros minuto a minuto) ──────────────────────

  /// Calcula o score a partir dos registros individuais — mais preciso.
  /// Usado na tela de detalhes da viagem.
  static DriverScore fromRecords({
    required List<SpeedRecord> records,
    required double maxSpeedKmh,
    required double avgSpeedKmh,
  }) {
    if (records.isEmpty) {
      return fromSummary(
        maxSpeedKmh: maxSpeedKmh,
        avgSpeedKmh: avgSpeedKmh,
        durationMinutes: 0,
      );
    }

    double score = 100.0;
    int violations = 0;
    int severe = 0;

    // Penalidade por cada minuto acima do limite.
    for (final r in records) {
      if (r.maxSpeedKmh > 130) {
        score -= 5;
        severe++;
      } else if (r.maxSpeedKmh > 100) {
        score -= 2;
        violations++;
      }
    }

    // Penalidade adicional pelo pico absoluto da viagem.
    if (maxSpeedKmh > 150) {
      score -= 15;
    } else if (maxSpeedKmh > 130) {
      score -= 8;
    } else if (maxSpeedKmh > 110) {
      score -= 4;
    }

    // Penalidade por velocidade média sustentada.
    if (avgSpeedKmh > 95) {
      score -= 8;
    } else if (avgSpeedKmh > 85) {
      score -= 4;
    } else if (avgSpeedKmh > 75) {
      score -= 1;
    }

    // Bônus por viagem longa e segura.
    if (records.length >= 20 && maxSpeedKmh <= 100) {
      score = (score + 2).clamp(0, 100);
    }

    final s = score.round().clamp(0, 100);
    return DriverScore(
      value: s,
      category: ScoreCategoryX.fromValue(s),
      violations: violations,
      severeViolations: severe,
      maxSpeed: maxSpeedKmh,
      avgSpeed: avgSpeedKmh,
    );
  }

  // ── Score ao vivo (durante a viagem, sem records finais) ─────────────────

  /// Score parcial calculado durante o tracking ativo.
  /// Usa os dados da viagem em andamento: máxima registrada até agora,
  /// velocidade atual e distância acumulada.
  static DriverScore live({
    required double currentMaxSpeedKmh,
    required double currentAvgSpeedKmh,
    required int elapsedMinutes,
  }) {
    return fromSummary(
      maxSpeedKmh: currentMaxSpeedKmh,
      avgSpeedKmh: currentAvgSpeedKmh,
      durationMinutes: elapsedMinutes,
    );
  }
}
