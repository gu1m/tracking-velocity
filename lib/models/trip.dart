import 'speed_record.dart';

/// Uma viagem é uma sequência contínua de registros de velocidade
/// capturada enquanto o usuário esteve acima de 10 km/h.
///
/// Quando o usuário fica abaixo de 10 km/h por mais de N minutos
/// (ex: 5), a viagem atual é encerrada e uma nova começa quando o
/// usuário voltar a se mover.
class Trip {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double distanceKm;
  final String startAddress;
  final String? endAddress;
  final List<SpeedRecord> records;

  const Trip({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.distanceKm,
    required this.startAddress,
    this.endAddress,
    this.records = const [],
  });

  Duration get duration =>
      (endedAt ?? DateTime.now()).difference(startedAt);

  bool get isActive => endedAt == null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'avg_speed_kmh': avgSpeedKmh,
        'max_speed_kmh': maxSpeedKmh,
        'distance_km': distanceKm,
        'start_address': startAddress,
        'end_address': endAddress,
      };

  factory Trip.fromMap(Map<String, dynamic> map,
          {List<SpeedRecord> records = const []}) =>
      Trip(
        id: map['id'] as String,
        startedAt: DateTime.parse(map['started_at'] as String),
        endedAt: map['ended_at'] != null
            ? DateTime.parse(map['ended_at'] as String)
            : null,
        avgSpeedKmh: (map['avg_speed_kmh'] as num).toDouble(),
        maxSpeedKmh: (map['max_speed_kmh'] as num).toDouble(),
        distanceKm: (map['distance_km'] as num).toDouble(),
        startAddress: map['start_address'] as String,
        endAddress: map['end_address'] as String?,
        records: records,
      );
}
