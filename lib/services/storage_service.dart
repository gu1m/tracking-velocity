import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../config/feature_flags.dart';
import '../database/app_database.dart';
import '../models/app_user.dart';
import '../models/speed_record.dart';
import '../models/trip.dart';
import '../utils/hash_utils.dart';

/// Persistência local (Drift/SQLite) + sincronização com backend Railway.
///
/// Fluxo:
///   1. LocationService emite SpeedRecords → StorageService salva localmente.
///   2. Ao encerrar viagem → calcula métricas → salva na tabela localTrips.
///   3. SyncWorker (background) sobe os dados para o Railway via HTTP.
class StorageService extends ChangeNotifier {
  final AppDatabase _db;

  AppUser? _currentUser;
  FeatureFlags _flags = const FeatureFlags(SubscriptionStatus.expired);

  List<Trip> _trips = [];
  bool _isLoading = false;

  List<Trip> get trips => List.unmodifiable(_trips);
  bool get isLoading => _isLoading;

  StorageService() : _db = AppDatabase();

  // ── Inicialização ─────────────────────────────────────────────────────────

  /// Chame após o login para carregar o histórico do usuário.
  Future<void> initialize(AppUser user) async {
    _currentUser = user;
    _flags = FeatureFlags.fromUser(user);
    await loadTrips();
  }

  // ── Leitura ───────────────────────────────────────────────────────────────

  Future<void> loadTrips() async {
    if (_currentUser == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.getTripsForUser(
        _currentUser!.uid,
        from: _flags.historyLimitDate,
        limit: _flags.maxTripsPerPage ?? 200,
      );
      _trips = rows.map(_rowToTrip).toList();
    } catch (e) {
      debugPrint('[StorageService] Erro ao carregar viagens: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Busca viagens com filtros combináveis (respeita limite Free).
  List<Trip> search({
    DateTime? from,
    DateTime? to,
    String? locationQuery,
    double? minSpeedKmh,
    double? maxSpeedKmh,
  }) {
    // Aplica limite de histórico Free
    final effectiveFrom = from == null
        ? _flags.historyLimitDate
        : from.isAfter(_flags.historyLimitDate)
            ? from
            : _flags.historyLimitDate;

    return _trips.where((t) {
      if (t.startedAt.isBefore(effectiveFrom)) return false;
      if (to != null && t.startedAt.isAfter(to)) return false;
      if (locationQuery != null && locationQuery.isNotEmpty) {
        final q = locationQuery.toLowerCase();
        final matchStart = t.startAddress.toLowerCase().contains(q);
        final matchEnd = (t.endAddress ?? '').toLowerCase().contains(q);
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

  Future<List<SpeedRecord>> getRecordsForTrip(String tripId) async {
    final rows = await _db.getRecordsForTrip(tripId);
    return rows.map(_rowToRecord).toList();
  }

  /// Retorna todos os registros de velocidade de um dia específico.
  Future<List<SpeedRecord>> getDailyRecords(DateTime date) async {
    if (_currentUser == null) return [];
    final from = DateTime(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final rows = await _db.getRecordsForDateRange(_currentUser!.uid, from, to);
    return rows.map(_rowToRecord).toList();
  }

  // ── Escrita: Viagem ───────────────────────────────────────────────────────

  /// Cria ou atualiza uma viagem localmente + enfileira para sync.
  Future<void> saveTrip({
    required String tripId,
    required String userId,
    required DateTime startedAt,
    DateTime? endedAt,
    double? avgSpeedKmh,
    double? maxSpeedKmh,
    double? distanceKm,
    String? startAddress,
    String? endAddress,
  }) async {
    await _db.upsertTrip(LocalTripsCompanion(
      id: Value(tripId),
      userId: Value(userId),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      avgSpeedKmh: Value(avgSpeedKmh),
      maxSpeedKmh: Value(maxSpeedKmh),
      distanceKm: Value(distanceKm),
      startAddress: Value(startAddress),
      endAddress: Value(endAddress),
    ));

    // Enfileira para sync com backend
    if (endedAt != null) {
      await _enqueue('end_trip', {
        'tripId': tripId,
        'endedAt': endedAt.toIso8601String(),
        'avgSpeedKmh': avgSpeedKmh,
        'maxSpeedKmh': maxSpeedKmh,
        'distanceKm': distanceKm,
        'endAddress': endAddress,
      });
    } else {
      await _enqueue('create_trip', {
        'tripId': tripId,
        'startedAt': startedAt.toIso8601String(),
        'startAddress': startAddress,
      });
    }

    await loadTrips();
  }

  /// Salva um lote de SpeedRecords localmente + enfileira para sync.
  Future<void> saveSpeedRecords(List<SpeedRecord> records) async {
    if (records.isEmpty || _currentUser == null) return;

    final companions = records
        .map((r) => LocalSpeedRecordsCompanion(
              tripId: Value(r.tripId),
              userId: Value(_currentUser!.uid),
              recordedAt: Value(r.timestamp),
              speedKmh: Value(r.speedKmh),
              maxSpeedKmh: Value(r.maxSpeedKmh),
              latitude: Value(r.latitude),
              longitude: Value(r.longitude),
              accuracyM: Value(r.accuracy),
              hash: Value(r.hash),
            ))
        .toList();

    await _db.insertSpeedRecords(companions);

    // Enfileira para sync em lote
    await _enqueue('speed_records', {
      'tripId': records.first.tripId,
      'records': records
          .map((r) => {
                'recordedAt': r.timestamp.toIso8601String(),
                'speedKmh': r.speedKmh,
                'maxSpeedKmh': r.maxSpeedKmh,
                'latitude': r.latitude,
                'longitude': r.longitude,
                'accuracyM': r.accuracy,
              })
          .toList(),
    });
  }

  Future<void> deleteTrip(String tripId) async {
    await _db.deleteTrip(tripId);
    await _db.deleteRecordsForTrip(tripId);
    _trips.removeWhere((t) => t.id == tripId);
    notifyListeners();
  }

  // ── Dados de teste ────────────────────────────────────────────────────────

  /// Insere viagens e registros GPS fictícios dos últimos 5 dias.
  /// Útil para testar o mapa de trajeto sem precisar dirigir.
  Future<void> seedTestData() async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;
    final now = DateTime.now();

    // Rotas em SP: Av. Paulista → Pinheiros → Lapa (ida e volta)
    const routes = [
      // Rota A: Paulista → Pinheiros (rumo oeste)
      _RouteSpec(lat: -23.5613, lon: -46.6565, dLat: -0.0003, dLon: -0.0008),
      // Rota B: Pinheiros → Lapa (rumo noroeste)
      _RouteSpec(lat: -23.5640, lon: -46.6940, dLat: -0.0005, dLon: -0.0010),
      // Rota C: Lapa → Barra Funda (rumo leste)
      _RouteSpec(lat: -23.5270, lon: -46.6900, dLat: 0.0002, dLon: 0.0012),
      // Rota D: Barra Funda → Consolação (rumo sul)
      _RouteSpec(lat: -23.5270, lon: -46.6500, dLat: 0.0008, dLon: -0.0005),
      // Rota E: Consolação → Itaim (diagonal sul-leste)
      _RouteSpec(lat: -23.5620, lon: -46.6450, dLat: 0.0006, dLon: 0.0009),
    ];

    for (int day = 1; day <= 5; day++) {
      final date = now.subtract(Duration(days: day));
      final isWeekend = date.weekday == 6 || date.weekday == 7;

      // Manhã: sempre
      final route = routes[(day - 1) % routes.length];
      await _insertFakeTrip(
        uid: uid,
        tripId: 'test_${date.millisecondsSinceEpoch}_am',
        start: DateTime(date.year, date.month, date.day, 7, 15 + day),
        minutes: 22 + day,
        route: route,
      );

      // Tarde: dias úteis
      if (!isWeekend) {
        final routeReturn = routes[day % routes.length];
        await _insertFakeTrip(
          uid: uid,
          tripId: 'test_${date.millisecondsSinceEpoch}_pm',
          start: DateTime(date.year, date.month, date.day, 17, 30 + day),
          minutes: 28 + day,
          route: routeReturn,
        );
      }

      // Fim de semana: um passeio mais longo
      if (isWeekend) {
        final routeWeekend = routes[(day + 2) % routes.length];
        await _insertFakeTrip(
          uid: uid,
          tripId: 'test_${date.millisecondsSinceEpoch}_wknd',
          start: DateTime(date.year, date.month, date.day, 10, 0),
          minutes: 45,
          route: routeWeekend,
        );
      }
    }

    await loadTrips();
  }

  Future<void> _insertFakeTrip({
    required String uid,
    required String tripId,
    required DateTime start,
    required int minutes,
    required _RouteSpec route,
  }) async {
    double lat = route.lat;
    double lon = route.lon;
    double maxSpeed = 0;
    double totalSpeed = 0;

    final records = <LocalSpeedRecordsCompanion>[];
    for (int m = 0; m < minutes; m++) {
      // Velocidade varia entre 20–95 km/h com pequena perturbação
      final base = 45.0 + (m % 7) * 8.0;
      final speed = base + (m % 3 - 1) * 5.0;
      final maxSpeedMin = speed + 10 + (m % 4) * 3.0;
      if (maxSpeedMin > maxSpeed) maxSpeed = maxSpeedMin;
      totalSpeed += speed;

      lat += route.dLat + (m % 2 == 0 ? 0.00005 : -0.00003);
      lon += route.dLon + (m % 3 == 0 ? 0.00004 : -0.00002);

      final recordTs = start.add(Duration(minutes: m));
      final recordHash = HashUtils.computeRecordHash(
        tripId: tripId,
        timestamp: recordTs.toUtc(),
        latitude: lat,
        longitude: lon,
        speedKmh: speed,
        maxSpeedKmh: maxSpeedMin,
        accuracy: 5.0,
      );

      records.add(LocalSpeedRecordsCompanion(
        tripId: Value(tripId),
        userId: Value(uid),
        recordedAt: Value(recordTs),
        speedKmh: Value(speed),
        maxSpeedKmh: Value(maxSpeedMin),
        latitude: Value(lat),
        longitude: Value(lon),
        accuracyM: const Value(5.0),
        hash: Value(recordHash),
      ));
    }

    final avgSpeed = totalSpeed / minutes;
    final endLat = lat;
    final endLon = lon;
    final distKm = minutes * avgSpeed / 60.0;

    await _db.upsertTrip(LocalTripsCompanion(
      id: Value(tripId),
      userId: Value(uid),
      startedAt: Value(start),
      endedAt: Value(start.add(Duration(minutes: minutes))),
      avgSpeedKmh: Value(avgSpeed),
      maxSpeedKmh: Value(maxSpeed),
      distanceKm: Value(distKm),
      startAddress: const Value('São Paulo, SP'),
      endAddress: const Value('São Paulo, SP'),
    ));

    await _db.insertSpeedRecords(records);

    debugPrint('[TestData] Viagem $tripId: $minutes min, avg ${avgSpeed.toStringAsFixed(1)} km/h, lat=${endLat.toStringAsFixed(5)} lon=${endLon.toStringAsFixed(5)}');
  }

  Future<void> clearAllData() async {
    if (_currentUser == null) return;
    final trips = await _db.getTripsForUser(_currentUser!.uid, limit: 9999);
    for (final t in trips) {
      await _db.deleteRecordsForTrip(t.id);
      await _db.deleteTrip(t.id);
    }
    _trips = [];
    notifyListeners();
  }

  // ── Sincronização com backend ─────────────────────────────────────────────

  Future<void> _enqueue(String operation, Map<String, dynamic> payload) async {
    await _db.enqueue(SyncQueueCompanion(
      operation: Value(operation),
      payload: Value(jsonEncode(payload)),
    ));
    // Tenta sincronizar imediatamente (fire-and-forget)
    _trySyncNow().ignore();
  }

  /// Processa a fila de sincronização.
  /// Chame periodicamente ou quando voltar a ter conexão.
  Future<void> syncNow(String firebaseToken) async {
    final pending = await _db.getPendingSync();
    if (pending.isEmpty) return;

    for (final item in pending) {
      try {
        await _syncItem(item, firebaseToken);
        await _db.deleteSyncItem(item.id);
      } catch (e) {
        debugPrint('[StorageService] Sync falhou para ${item.operation}: $e');
        await _db.markSyncFailed(item.id);
      }
    }
  }

  Future<void> _syncItem(SyncQueueData item, String token) async {
    final payload = jsonDecode(item.payload) as Map<String, dynamic>;
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    switch (item.operation) {
      case 'create_trip':
        await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}/trips'),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 10));

      case 'end_trip':
        final tripId = payload['tripId'] as String;
        await http
            .put(
              Uri.parse('${ApiConfig.baseUrl}/trips/$tripId/end'),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 10));

      case 'speed_records':
        final tripId = payload['tripId'] as String;
        await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}/trips/$tripId/records'),
              headers: headers,
              body: jsonEncode({'records': payload['records']}),
            )
            .timeout(const Duration(seconds: 15));
    }
  }

  Future<void> _trySyncNow() async {
    // Sem token disponível aqui — o sync completo é feito via syncNow()
    // chamado explicitamente pelo BillingService ou AuthService
  }

  // ── Converters ────────────────────────────────────────────────────────────

  Trip _rowToTrip(LocalTrip row) => Trip(
        id: row.id,
        startedAt: row.startedAt,
        endedAt: row.endedAt,
        avgSpeedKmh: row.avgSpeedKmh ?? 0,
        maxSpeedKmh: row.maxSpeedKmh ?? 0,
        distanceKm: row.distanceKm ?? 0,
        startAddress: row.startAddress ?? '',
        endAddress: row.endAddress,
        records: const [],
      );

  SpeedRecord _rowToRecord(LocalSpeedRecord row) => SpeedRecord(
        tripId: row.tripId,
        timestamp: row.recordedAt,
        speedKmh: row.speedKmh,
        maxSpeedKmh: row.maxSpeedKmh,
        latitude: row.latitude,
        longitude: row.longitude,
        accuracy: row.accuracyM ?? 0,
        hash: row.hash,
      );

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }
}

class _RouteSpec {
  final double lat;
  final double lon;
  final double dLat;
  final double dLon;
  const _RouteSpec({
    required this.lat,
    required this.lon,
    required this.dLat,
    required this.dLon,
  });
}
