import 'package:flutter/foundation.dart';
import '../models/trip.dart';
import '../models/speed_record.dart';

/// Serviço de persistência local. A implementação real usa sqflite
/// para guardar viagens e registros, permitindo busca por:
///  - intervalo de data/hora
///  - faixa de velocidade
///  - texto livre no endereço
///
/// Aqui está um stub com dados mockados para a UI funcionar.
class StorageService extends ChangeNotifier {
  final List<Trip> _trips = _seedTrips();

  List<Trip> get trips => List.unmodifiable(_trips);

  /// Busca viagens com filtros combináveis.
  List<Trip> search({
    DateTime? from,
    DateTime? to,
    String? locationQuery,
    double? minSpeedKmh,
    double? maxSpeedKmh,
  }) {
    return _trips.where((t) {
      if (from != null && t.startedAt.isBefore(from)) return false;
      if (to != null && t.startedAt.isAfter(to)) return false;
      if (locationQuery != null && locationQuery.isNotEmpty) {
        final q = locationQuery.toLowerCase();
        final matchStart = t.startAddress.toLowerCase().contains(q);
        final matchEnd =
            (t.endAddress ?? '').toLowerCase().contains(q);
        if (!matchStart && !matchEnd) return false;
      }
      if (minSpeedKmh != null && t.maxSpeedKmh < minSpeedKmh) return false;
      if (maxSpeedKmh != null && t.avgSpeedKmh > maxSpeedKmh) return false;
      return true;
    }).toList();
  }

  Trip? getTripById(String id) {
    try {
      return _trips.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---- mock seed -------------------------------------------------
  static List<Trip> _seedTrips() {
    final now = DateTime.now();
    return [
      Trip(
        id: 'trip-001',
        startedAt: now.subtract(const Duration(hours: 3, minutes: 15)),
        endedAt: now.subtract(const Duration(hours: 2, minutes: 40)),
        avgSpeedKmh: 58.4,
        maxSpeedKmh: 92.0,
        distanceKm: 24.3,
        startAddress: 'Av. Paulista, 1500 — São Paulo/SP',
        endAddress: 'Aeroporto de Congonhas — São Paulo/SP',
        records: _seedRecords('trip-001', now.subtract(const Duration(hours: 3))),
      ),
      Trip(
        id: 'trip-002',
        startedAt: now.subtract(const Duration(days: 1, hours: 9)),
        endedAt: now.subtract(const Duration(days: 1, hours: 8, minutes: 12)),
        avgSpeedKmh: 71.2,
        maxSpeedKmh: 118.0,
        distanceKm: 47.8,
        startAddress: 'Rua Augusta, 2000 — São Paulo/SP',
        endAddress: 'Rod. Anhanguera, km 38 — Jundiaí/SP',
        records: _seedRecords('trip-002', now.subtract(const Duration(days: 1, hours: 9))),
      ),
      Trip(
        id: 'trip-003',
        startedAt: now.subtract(const Duration(days: 2, hours: 14)),
        endedAt: now.subtract(const Duration(days: 2, hours: 13, minutes: 30)),
        avgSpeedKmh: 45.6,
        maxSpeedKmh: 68.0,
        distanceKm: 18.2,
        startAddress: 'Shopping Morumbi — São Paulo/SP',
        endAddress: 'Av. Paulista, 1500 — São Paulo/SP',
        records: _seedRecords('trip-003', now.subtract(const Duration(days: 2, hours: 14))),
      ),
      Trip(
        id: 'trip-004',
        startedAt: now.subtract(const Duration(days: 5, hours: 7)),
        endedAt: now.subtract(const Duration(days: 5, hours: 6, minutes: 5)),
        avgSpeedKmh: 88.3,
        maxSpeedKmh: 124.0,
        distanceKm: 82.1,
        startAddress: 'Av. Brasil, 100 — Rio de Janeiro/RJ',
        endAddress: 'Centro — Petrópolis/RJ',
        records: _seedRecords('trip-004', now.subtract(const Duration(days: 5, hours: 7))),
      ),
      Trip(
        id: 'trip-005',
        startedAt: now.subtract(const Duration(days: 9, hours: 18)),
        endedAt: now.subtract(const Duration(days: 9, hours: 17, minutes: 45)),
        avgSpeedKmh: 32.1,
        maxSpeedKmh: 54.0,
        distanceKm: 9.7,
        startAddress: 'Vila Madalena — São Paulo/SP',
        endAddress: 'Pinheiros — São Paulo/SP',
        records: _seedRecords('trip-005', now.subtract(const Duration(days: 9, hours: 18))),
      ),
    ];
  }

  static List<SpeedRecord> _seedRecords(String tripId, DateTime start) {
    return List.generate(20, (i) {
      final speeds = [12, 28, 45, 62, 78, 88, 92, 85, 70, 55, 48, 60, 72, 80, 76, 65, 50, 35, 22, 14];
      return SpeedRecord(
        tripId: tripId,
        timestamp: start.add(Duration(minutes: i)),
        speedKmh: speeds[i].toDouble(),
        maxSpeedKmh: speeds[i].toDouble() + 5,
        latitude: -23.561 + i * 0.001,
        longitude: -46.656 + i * 0.001,
        accuracy: 5.0,
        address: 'Av. Paulista, ${1500 + i * 50}',
      );
    });
  }
}
