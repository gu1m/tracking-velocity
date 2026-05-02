import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ntp/ntp.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/feature_flags.dart';
import '../models/app_user.dart';
import '../models/driver_score.dart';
import '../models/speed_record.dart';
import '../services/score_service.dart';
import '../utils/hash_utils.dart';

/// Gerencia o tracking de velocidade via GPS.
///
/// Regras de negócio:
///  - Registra apenas quando velocidade ≥ [minTrackingSpeedKmh] (padrão 10 km/h, configurável).
///  - Agrega leituras por janela de 1 minuto → emite [SpeedRecord] via [speedRecords].
///  - Encerra a viagem após [tripIdleTimeout] abaixo do limiar (padrão 5 min, configurável).
///  - Plano Free: background tracking desativado + limite de 30 min por sessão.
///  - Plano Premium: background tracking ilimitado.
class LocationService extends ChangeNotifier {
  static const String _prefMinSpeed = 'min_tracking_speed_kmh';
  static const String _prefTripTimeout = 'trip_idle_timeout_minutes';
  static const double defaultMinSpeedKmh = 10.0;
  static const int defaultTripTimeoutMinutes = 5;
  static const Duration minuteWindow = Duration(minutes: 1);

  double _minTrackingSpeedKmh = defaultMinSpeedKmh;
  int _tripIdleTimeoutMinutes = defaultTripTimeoutMinutes;

  double get minTrackingSpeedKmh => _minTrackingSpeedKmh;
  int get tripIdleTimeoutMinutes => _tripIdleTimeoutMinutes;
  Duration get tripIdleTimeout => Duration(minutes: _tripIdleTimeoutMinutes);

  LocationService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _minTrackingSpeedKmh = prefs.getDouble(_prefMinSpeed) ?? defaultMinSpeedKmh;
    _tripIdleTimeoutMinutes = prefs.getInt(_prefTripTimeout) ?? defaultTripTimeoutMinutes;
    notifyListeners();
  }

  Future<void> setMinSpeed(double kmh) async {
    _minTrackingSpeedKmh = kmh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefMinSpeed, kmh);
    notifyListeners();
  }

  Future<void> setTripTimeout(int minutes) async {
    _tripIdleTimeoutMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefTripTimeout, minutes);
    notifyListeners();
  }

  // ── Feature flags ────────────────────────────────────────────────────────
  FeatureFlags _flags = const FeatureFlags(SubscriptionStatus.expired);
  DateTime? _sessionStartedAt;

  /// Atualiza as feature flags quando o status de assinatura mudar.
  void updateUser(AppUser? user) {
    _flags = FeatureFlags.fromUser(user);
    // Se Free e background não permitido → para o serviço
    if (!_flags.hasBackgroundTracking && _isServiceRunning) {
      pauseService();
    }
    notifyListeners();
  }

  bool get isPremium => _flags.isPremium;
  bool get showAds => _flags.showAds;
  bool get canExportReports => _flags.canExportReports;
  bool get hasUnlimitedHistory => _flags.hasUnlimitedHistory;

  // ── Estado exposto para a UI ─────────────────────────────────────────────
  bool _isServiceRunning = false;
  bool _isTrackingActive = false;
  double _currentSpeedKmh = 0;
  double _currentLat = 0;
  double _currentLon = 0;
  Duration _todayActiveTime = Duration.zero;
  double _todayDistanceKm = 0;
  double _todayMaxSpeedKmh = 0;

  bool get isServiceRunning => _isServiceRunning;
  bool get isTrackingActive => _isTrackingActive;
  bool get ntpSynced => _ntpSynced;
  double get currentSpeedKmh => _currentSpeedKmh;

  /// Retorna coordenadas formatadas enquanto não houver geocodificação reversa.
  String get currentLocation => _isTrackingActive
      ? '${_currentLat.toStringAsFixed(5)}, ${_currentLon.toStringAsFixed(5)}'
      : 'Aguardando GPS…';

  Duration get todayActiveTime => _todayActiveTime;
  double get todayDistanceKm => _todayDistanceKm;
  double get todayMaxSpeedKmh => _todayMaxSpeedKmh;
  double get todayAvgSpeedKmh {
    final hours = _todayActiveTime.inSeconds / 3600.0;
    return hours > 0 ? _todayDistanceKm / hours : 0;
  }

  // ── Estado da viagem ativa ───────────────────────────────────────────────
  String? _activeTripId;
  DateTime? _tripStartedAt;
  DateTime? _lastAboveThresholdAt;
  double _tripMaxSpeed = 0;
  double _tripTotalDistanceKm = 0;

  String? get activeTripId => _activeTripId;
  DateTime? get tripStartedAt => _tripStartedAt;
  double get tripMaxSpeed => _tripMaxSpeed;
  double get tripTotalDistanceKm => _tripTotalDistanceKm;

  // ── NTP (horário oficial) ────────────────────────────────────────────────
  /// Offset entre o relógio do dispositivo e o servidor NTP (em ms).
  /// Positivo = dispositivo adiantado; negativo = atrasado.
  Duration _ntpOffset = Duration.zero;
  bool _ntpSynced = false;

  /// Sincroniza o offset NTP de forma assíncrona (fire-and-forget).
  /// Chamado ao iniciar a viagem e ao ligar o serviço.
  Future<void> _syncNtpOffset() async {
    try {
      final offsetMs = await NTP.getNtpOffset(
        localTime: DateTime.now(),
        lookUpAddress: 'a.ntp.br',   // servidor NTP oficial BR
      ).timeout(const Duration(seconds: 8));
      _ntpOffset = Duration(milliseconds: offsetMs);
      _ntpSynced = true;
      debugPrint('[LocationService] NTP synced — offset: ${offsetMs}ms');
    } catch (e) {
      debugPrint('[LocationService] NTP sync falhou: $e — usando relógio local.');
    }
  }

  /// Aplica o offset NTP a um DateTime do dispositivo.
  DateTime _toNtpTime(DateTime deviceTime) =>
      deviceTime.add(_ntpOffset).toUtc();

  // ── Score ao vivo ────────────────────────────────────────────────────────
  /// Score parcial calculado em tempo real durante a viagem ativa.
  DriverScore get currentTripScore => ScoreService.live(
        currentMaxSpeedKmh: _tripMaxSpeed,
        currentAvgSpeedKmh: todayAvgSpeedKmh,
        elapsedMinutes: _todayActiveTime.inMinutes,
      );

  // ── Agregação por minuto ─────────────────────────────────────────────────
  final List<double> _minuteSpeeds = [];
  double _minuteMaxSpeed = 0;
  double _minuteDistanceKm = 0;
  DateTime? _minuteStart;
  double? _prevLat;
  double? _prevLon;

  // ── Stream de SpeedRecords prontos para persistir ────────────────────────
  final StreamController<SpeedRecord> _recordCtrl =
      StreamController<SpeedRecord>.broadcast();

  /// Emite um [SpeedRecord] ao final de cada janela de 1 minuto acima do
  /// limiar. Consuma este stream no StorageService para persistir os dados.
  Stream<SpeedRecord> get speedRecords => _recordCtrl.stream;

  // ── Ciclo de vida das viagens ─────────────────────────────────────────────
  final StreamController<TripStartedEvent> _tripStartedCtrl =
      StreamController<TripStartedEvent>.broadcast();
  final StreamController<TripEndedEvent> _tripEndedCtrl =
      StreamController<TripEndedEvent>.broadcast();

  /// Emitido quando uma nova viagem começa (velocidade > limiar após inatividade).
  Stream<TripStartedEvent> get tripStarted => _tripStartedCtrl.stream;

  /// Emitido quando uma viagem é encerrada (timeout de inatividade).
  Stream<TripEndedEvent> get tripEnded => _tripEndedCtrl.stream;

  // ── Comunicação com o isolate de background ──────────────────────────────
  StreamSubscription<Map<String, dynamic>?>? _updateSub;

  // ── Permissões ───────────────────────────────────────────────────────────

  /// Solicita as permissões necessárias para o tracking.
  /// Retorna true se ao menos a permissão básica de localização foi concedida.
  Future<bool> requestPermissions() async {
    // Android 10+: obrigatório pedir whenInUse ANTES de always.
    // Pedir always diretamente retorna denied sem mostrar o diálogo.
    PermissionStatus status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      await Permission.locationAlways.request();
    }
    await Permission.notification.request();
    return status.isGranted;
  }

  // ── Ciclo de vida do serviço ─────────────────────────────────────────────

  /// Inicia (ou reconecta ao) serviço de background.
  /// Plano Free: roda apenas em foreground (sem background real).
  /// Plano Premium: roda em background ilimitado.
  Future<void> startBackgroundService() async {
    final granted = await requestPermissions();
    if (!granted) {
      debugPrint('[LocationService] Permissão de localização negada.');
      return;
    }

    // Free: não inicia o serviço de background — apenas foreground
    if (!_flags.hasBackgroundTracking) {
      debugPrint('[LocationService] Plano Free — apenas foreground tracking.');
      _isServiceRunning = true;
      _sessionStartedAt = DateTime.now();
      notifyListeners();
      return;
    }

    final service = FlutterBackgroundService();
    final alreadyRunning = await service.isRunning();
    if (!alreadyRunning) {
      await service.startService();
    }

    // (Re)conecta o listener no isolate principal.
    _updateSub?.cancel();
    _updateSub = service.on('update').listen(_handleUpdate);

    _isServiceRunning = true;
    _sessionStartedAt = DateTime.now();
    notifyListeners();

    // Sincroniza NTP em background (não bloqueia a UI).
    _syncNtpOffset().ignore();
  }

  /// Pausa o serviço (ex: usuário desativa nas configurações).
  Future<void> pauseService() async {
    FlutterBackgroundService().invoke('stop');
    await _updateSub?.cancel();
    _isServiceRunning = false;
    _isTrackingActive = false;
    _currentSpeedKmh = 0;
    notifyListeners();
  }

  // ── Processamento das leituras GPS ───────────────────────────────────────

  void _handleUpdate(Map<String, dynamic>? data) {
    if (data == null) return;

    // Free: verifica limite de sessão
    if (_sessionStartedAt != null && _flags.maxSessionDuration != null) {
      final elapsed = DateTime.now().difference(_sessionStartedAt!);
      if (elapsed >= _flags.maxSessionDuration!) {
        debugPrint('[LocationService] Limite de sessão Free atingido (30 min).');
        pauseService();
        return;
      }
    }

    final speedKmh = (data['speedKmh'] as num).toDouble();
    final lat = (data['latitude'] as num).toDouble();
    final lon = (data['longitude'] as num).toDouble();
    final accuracy = (data['accuracy'] as num).toDouble();
    final ts = DateTime.parse(data['timestamp'] as String);

    _currentSpeedKmh = speedKmh;
    _currentLat = lat;
    _currentLon = lon;

    final isMoving = speedKmh >= minTrackingSpeedKmh;

    if (isMoving) {
      _lastAboveThresholdAt = ts;
      if (_activeTripId == null) _startTrip(lat, lon, ts);
      _accumulate(speedKmh, lat, lon, accuracy, ts);
      _isTrackingActive = true;
    } else {
      _isTrackingActive = false;
      if (_activeTripId != null && _lastAboveThresholdAt != null) {
        final idle = ts.difference(_lastAboveThresholdAt!);
        if (idle >= tripIdleTimeout) _endTrip(ts);
      }
    }

    notifyListeners();
  }

  void _startTrip(double lat, double lon, DateTime ts) {
    final tripId = 'trip_${ts.millisecondsSinceEpoch}';
    _activeTripId = tripId;
    _tripStartedAt = ts;
    _tripMaxSpeed = 0;
    _tripTotalDistanceKm = 0;
    _minuteStart = ts;
    _minuteSpeeds.clear();
    _minuteMaxSpeed = 0;
    _minuteDistanceKm = 0;
    _prevLat = lat;
    _prevLon = lon;

    _tripStartedCtrl.add(TripStartedEvent(
      tripId: tripId,
      startedAt: ts,
      latitude: lat,
      longitude: lon,
    ));
  }

  void _accumulate(
      double speed, double lat, double lon, double accuracy, DateTime ts) {
    _minuteSpeeds.add(speed);
    if (speed > _minuteMaxSpeed) _minuteMaxSpeed = speed;
    if (speed > _tripMaxSpeed) _tripMaxSpeed = speed;

    if (_prevLat != null && _prevLon != null) {
      final distM =
          Geolocator.distanceBetween(_prevLat!, _prevLon!, lat, lon);
      final distKm = distM / 1000.0;
      _minuteDistanceKm += distKm;
      _tripTotalDistanceKm += distKm;
    }
    _prevLat = lat;
    _prevLon = lon;

    if (_minuteStart != null && ts.difference(_minuteStart!) >= minuteWindow) {
      _flushMinute(lat, lon, accuracy, ts);
    }
  }

  void _flushMinute(double lat, double lon, double accuracy, DateTime ts) {
    if (_minuteSpeeds.isEmpty || _activeTripId == null) return;

    final avgSpeed =
        _minuteSpeeds.reduce((a, b) => a + b) / _minuteSpeeds.length;

    // Aplica offset NTP ao timestamp do início do minuto.
    final ntpTimestamp = _toNtpTime(_minuteStart!);

    // Calcula hash SHA-256 de integridade do registro.
    final hash = HashUtils.computeRecordHash(
      tripId: _activeTripId!,
      timestamp: ntpTimestamp,
      latitude: lat,
      longitude: lon,
      speedKmh: avgSpeed,
      maxSpeedKmh: _minuteMaxSpeed,
      accuracy: accuracy,
    );

    _recordCtrl.add(SpeedRecord(
      tripId: _activeTripId!,
      timestamp: ntpTimestamp,
      speedKmh: avgSpeed,
      maxSpeedKmh: _minuteMaxSpeed,
      latitude: lat,
      longitude: lon,
      accuracy: accuracy,
      hash: hash,
    ));

    _todayActiveTime += minuteWindow;
    _todayDistanceKm += _minuteDistanceKm;
    if (_minuteMaxSpeed > _todayMaxSpeedKmh) _todayMaxSpeedKmh = _minuteMaxSpeed;

    // Reinicia o buffer do minuto.
    _minuteSpeeds.clear();
    _minuteMaxSpeed = 0;
    _minuteDistanceKm = 0;
    _minuteStart = ts;
  }

  void _endTrip(DateTime ts) {
    // Persiste leituras parciais do último minuto incompleto.
    if (_minuteSpeeds.isNotEmpty) {
      _flushMinute(_currentLat, _currentLon, 0, ts);
    }

    if (_activeTripId != null && _tripStartedAt != null) {
      // Duração real da viagem em minutos.
      final durationMin = ts.difference(_tripStartedAt!).inMinutes;

      // Velocidade média: distância / horas.
      final hours = ts.difference(_tripStartedAt!).inSeconds / 3600.0;
      final avgSpeed = hours > 0 ? _tripTotalDistanceKm / hours : 0.0;

      // Calcula o score final da viagem.
      final score = ScoreService.fromSummary(
        maxSpeedKmh: _tripMaxSpeed,
        avgSpeedKmh: avgSpeed,
        durationMinutes: durationMin,
      );

      _tripEndedCtrl.add(TripEndedEvent(
        tripId: _activeTripId!,
        startedAt: _tripStartedAt!,
        endedAt: ts,
        avgSpeedKmh: avgSpeed,
        maxSpeedKmh: _tripMaxSpeed,
        distanceKm: _tripTotalDistanceKm,
        score: score,
      ));
    }

    _activeTripId = null;
    _tripStartedAt = null;
    _lastAboveThresholdAt = null;
    _tripMaxSpeed = 0;
    _tripTotalDistanceKm = 0;
    _isTrackingActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _recordCtrl.close();
    _tripStartedCtrl.close();
    _tripEndedCtrl.close();
    super.dispose();
  }
}

// ── Eventos de ciclo de vida da viagem ────────────────────────────────────────

class TripStartedEvent {
  final String tripId;
  final DateTime startedAt;
  final double latitude;
  final double longitude;

  const TripStartedEvent({
    required this.tripId,
    required this.startedAt,
    required this.latitude,
    required this.longitude,
  });
}

class TripEndedEvent {
  final String tripId;
  final DateTime startedAt;
  final DateTime endedAt;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double distanceKm;
  final DriverScore score;

  const TripEndedEvent({
    required this.tripId,
    required this.startedAt,
    required this.endedAt,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.distanceKm,
    required this.score,
  });
}
