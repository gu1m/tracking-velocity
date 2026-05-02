import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utilitários de hash para autenticidade dos registros GPS (Fase 1).
class HashUtils {
  HashUtils._();

  /// Calcula o SHA-256 de integridade de um SpeedRecord.
  ///
  /// A string canônica é:
  ///   tripId|timestamp(ISO-8601)|lat(6 casas)|lon(6 casas)|speed(4 casas)|maxSpeed(4 casas)|accuracy(2 casas)
  ///
  /// Qualquer alteração em qualquer campo invalida o hash.
  static String computeRecordHash({
    required String tripId,
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    required double speedKmh,
    required double maxSpeedKmh,
    required double accuracy,
  }) {
    final canonical =
        '$tripId'
        '|${timestamp.toUtc().toIso8601String()}'
        '|${latitude.toStringAsFixed(6)}'
        '|${longitude.toStringAsFixed(6)}'
        '|${speedKmh.toStringAsFixed(4)}'
        '|${maxSpeedKmh.toStringAsFixed(4)}'
        '|${accuracy.toStringAsFixed(2)}';

    return sha256.convert(utf8.encode(canonical)).toString();
  }
}
