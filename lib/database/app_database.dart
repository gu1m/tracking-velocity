import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ── Tabela: viagens locais ────────────────────────────────────────────────────
class LocalTrips extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  RealColumn get avgSpeedKmh => real().nullable()();
  RealColumn get maxSpeedKmh => real().nullable()();
  RealColumn get distanceKm => real().nullable()();
  TextColumn get startAddress => text().nullable()();
  TextColumn get endAddress => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Tabela: registros de velocidade ──────────────────────────────────────────
class LocalSpeedRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tripId => text()();
  TextColumn get userId => text()();
  DateTimeColumn get recordedAt => dateTime()();
  RealColumn get speedKmh => real()();
  RealColumn get maxSpeedKmh => real()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracyM => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ── Tabela: fila de sincronização ────────────────────────────────────────────
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Tipo de operação: 'create_trip' | 'end_trip' | 'speed_records'
  TextColumn get operation => text()();

  /// JSON com o payload da operação
  TextColumn get payload => text()();

  /// Número de tentativas já realizadas
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// null = pendente, timestamp = data da última falha
  DateTimeColumn get lastFailedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ── AppDatabase ───────────────────────────────────────────────────────────────
@DriftDatabase(tables: [LocalTrips, LocalSpeedRecords, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openDatabase());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openDatabase() {
    return driftDatabase(name: 'tracking_velocidade.db');
  }

  // ── LocalTrips DAOs ───────────────────────────────────────────────────────

  Future<void> upsertTrip(LocalTripsCompanion trip) =>
      into(localTrips).insertOnConflictUpdate(trip);

  Future<List<LocalTrip>> getTripsForUser(
    String userId, {
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int offset = 0,
  }) {
    final query = select(localTrips)
      ..where((t) => t.userId.equals(userId))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
      ..limit(limit, offset: offset);

    if (from != null) {
      query.where((t) => t.startedAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((t) => t.startedAt.isSmallerOrEqualValue(to));
    }

    return query.get();
  }

  Future<LocalTrip?> getTripById(String id) =>
      (select(localTrips)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> deleteTrip(String id) =>
      (delete(localTrips)..where((t) => t.id.equals(id))).go();

  // ── LocalSpeedRecords DAOs ────────────────────────────────────────────────

  Future<void> insertSpeedRecord(LocalSpeedRecordsCompanion record) =>
      into(localSpeedRecords).insert(record);

  Future<void> insertSpeedRecords(List<LocalSpeedRecordsCompanion> records) =>
      batch((b) => b.insertAll(localSpeedRecords, records));

  Future<List<LocalSpeedRecord>> getRecordsForTrip(String tripId) =>
      (select(localSpeedRecords)
            ..where((r) => r.tripId.equals(tripId))
            ..orderBy([(r) => OrderingTerm.asc(r.recordedAt)]))
          .get();

  Future<void> deleteRecordsForTrip(String tripId) =>
      (delete(localSpeedRecords)..where((r) => r.tripId.equals(tripId))).go();

  Future<List<LocalSpeedRecord>> getRecordsForDateRange(
    String userId,
    DateTime from,
    DateTime to,
  ) =>
      (select(localSpeedRecords)
            ..where((r) =>
                r.userId.equals(userId) &
                r.recordedAt.isBiggerOrEqualValue(from) &
                r.recordedAt.isSmallerOrEqualValue(to))
            ..orderBy([(r) => OrderingTerm.asc(r.recordedAt)]))
          .get();

  // ── SyncQueue DAOs ────────────────────────────────────────────────────────

  Future<int> enqueue(SyncQueueCompanion item) =>
      into(syncQueue).insert(item);

  Future<List<SyncQueueData>> getPendingSync({int limit = 20}) =>
      (select(syncQueue)
            ..where((q) => q.attempts.isSmallerThanValue(3))
            ..orderBy([(q) => OrderingTerm.asc(q.createdAt)])
            ..limit(limit))
          .get();

  Future<void> markSyncFailed(int id) async {
    final item = await (select(syncQueue)
          ..where((q) => q.id.equals(id)))
        .getSingleOrNull();
    if (item == null) return;
    await (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        attempts: Value(item.attempts + 1),
        lastFailedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteSyncItem(int id) =>
      (delete(syncQueue)..where((q) => q.id.equals(id))).go();

  Future<void> clearSyncedItems() =>
      (delete(syncQueue)..where((q) => q.attempts.isSmallerThanValue(3))).go();
}
