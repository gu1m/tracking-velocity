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

  /// Remove todas as viagens e registros de velocidade do usuário local.
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
      );

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }
}
