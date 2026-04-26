/// Registro pontual de velocidade capturado pelo GPS.
///
/// O app salva a velocidade média por minuto quando o usuário está acima
/// de 10 km/h. Essa é a unidade básica que vai compor uma viagem (Trip).
class SpeedRecord {
  final int? id;
  final String tripId;
  final DateTime timestamp;
  final double speedKmh;       // Velocidade média no minuto
  final double maxSpeedKmh;    // Pico no minuto
  final double latitude;
  final double longitude;
  final double accuracy;       // precisão do GPS em metros
  final String? address;       // endereço reverso (preenchido sob demanda)

  const SpeedRecord({
    this.id,
    required this.tripId,
    required this.timestamp,
    required this.speedKmh,
    required this.maxSpeedKmh,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.address,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'timestamp': timestamp.toIso8601String(),
        'speed_kmh': speedKmh,
        'max_speed_kmh': maxSpeedKmh,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'address': address,
      };

  factory SpeedRecord.fromMap(Map<String, dynamic> map) => SpeedRecord(
        id: map['id'] as int?,
        tripId: map['trip_id'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        speedKmh: (map['speed_kmh'] as num).toDouble(),
        maxSpeedKmh: (map['max_speed_kmh'] as num).toDouble(),
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracy: (map['accuracy'] as num).toDouble(),
        address: map['address'] as String?,
      );
}
