import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/feature_flags.dart';
import '../models/app_user.dart';
import '../models/speed_record.dart';

/// Gerencia o tracking de velocidade via GPS.
///
/// Regras de negócio:
///  - Registra apenas quando velocidade ≥ 10 km/h.
///  - Agrega leituras por janela de 1 minuto → emite [SpeedRecord] via [speedRecords].
///  - Encerra a viagem após [tripIdleTimeout] abaixo do limiar.
///  - Plano Free: background tracking desativado + limite de 30 min por sessão.
///  - Plano Premium: background tracking ilimitado.
class LocationService extends ChangeNotifier {
  static const double minTrackingSpeedKmh = 10.0;
  static const Duration tripIdleTimeout = Duration(minutes: 5);
  static const Duration minuteWindow = Duration(minutes: 1);

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
    _activeTripId = 'trip_${ts.millisecondsSinceEpoch}';
    _tripStartedAt = ts;
    _tripMaxSpeed = 0;
    _tripTotalDistanceKm = 0;
    _minuteStart = ts;
    _minuteSpeeds.clear();
    _minuteMaxSpeed = 0;
    _minuteDistanceKm = 0;
    _prevLat = lat;
    _prevLon = lon;
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

    _recordCtrl.add(SpeedRecord(
      tripId: _activeTripId!,
      timestamp: _minuteStart!,
      speedKmh: avgSpeed,
      maxSpeedKmh: _minuteMaxSpeed,
      latitude: lat,
      longitude: lon,
      accuracy: accuracy,
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
    super.dispose();
  }
}
