import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Categorias de pontuação do condutor.
enum ScoreCategory {
  exemplar,   // 90–100
  safe,       // 75–89
  regular,    // 60–74
  risky,      // 45–59
  dangerous,  // 0–44
}

extension ScoreCategoryX on ScoreCategory {
  String get label => switch (this) {
        ScoreCategory.exemplar  => 'Exemplar',
        ScoreCategory.safe      => 'Seguro',
        ScoreCategory.regular   => 'Regular',
        ScoreCategory.risky     => 'Arriscado',
        ScoreCategory.dangerous => 'Perigoso',
      };

  String get emoji => switch (this) {
        ScoreCategory.exemplar  => '🏆',
        ScoreCategory.safe      => '✅',
        ScoreCategory.regular   => '⚠️',
        ScoreCategory.risky     => '🔶',
        ScoreCategory.dangerous => '🚨',
      };

  Color get color => switch (this) {
        ScoreCategory.exemplar  => AppColors.success,
        ScoreCategory.safe      => AppColors.success,
        ScoreCategory.regular   => AppColors.warning,
        ScoreCategory.risky     => AppColors.accent,
        ScoreCategory.dangerous => AppColors.danger,
      };

  static ScoreCategory fromValue(int score) {
    if (score >= 90) return ScoreCategory.exemplar;
    if (score >= 75) return ScoreCategory.safe;
    if (score >= 60) return ScoreCategory.regular;
    if (score >= 45) return ScoreCategory.risky;
    return ScoreCategory.dangerous;
  }
}

/// Pontuação de condução calculada para uma viagem.
///
/// Quanto mais o condutor se mantém dentro dos limites de velocidade,
/// sem picos bruscos, maior é a pontuação (0–100).
class DriverScore {
  /// Pontuação final de 0 a 100.
  final int value;

  /// Categoria derivada do [value].
  final ScoreCategory category;

  /// Registros/minutos com velocidade máxima > 100 km/h.
  final int violations;

  /// Registros/minutos com velocidade máxima > 130 km/h.
  final int severeViolations;

  /// Velocidade máxima registrada na viagem.
  final double maxSpeed;

  /// Velocidade média da viagem.
  final double avgSpeed;

  const DriverScore({
    required this.value,
    required this.category,
    this.violations = 0,
    this.severeViolations = 0,
    required this.maxSpeed,
    required this.avgSpeed,
  });

  /// Score perfeito — usado como placeholder antes de qualquer dado.
  const DriverScore.perfect()
      : value = 100,
        category = ScoreCategory.exemplar,
        violations = 0,
        severeViolations = 0,
        maxSpeed = 0,
        avgSpeed = 0;

  /// Serializa para JSON (armazenamento no Drift como TEXT).
  Map<String, dynamic> toJson() => {
        'value': value,
        'violations': violations,
        'severeViolations': severeViolations,
        'maxSpeed': maxSpeed,
        'avgSpeed': avgSpeed,
      };
}
