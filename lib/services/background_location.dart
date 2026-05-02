import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

/// Configura o FlutterBackgroundService. Deve ser chamado uma vez em main(),
/// antes do runApp, para que o serviço já esteja registrado quando o usuário
/// conceder permissão e chamar LocationService.startBackgroundService().
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onBackgroundStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'tracking_location_channel',
      initialNotificationTitle: 'Tracking Velocidade',
      initialNotificationContent: 'Monitorando sua velocidade…',
      foregroundServiceNotificationId: 888,
      // Android 14+: deve bater com foregroundServiceType="location" no manifest
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _onBackgroundStart,
      onBackground: _onIosBackground,
    ),
  );
}

/// Entry point do isolate de background — deve ser top-level e anotado com
/// @pragma para que o compilador não a remova (tree-shaking).
@pragma('vm:entry-point')
Future<void> _onBackgroundStart(ServiceInstance service) async {
  // Inicializa o binding para que plugins (geolocator, etc.) funcionem
  // no isolate secundário.
  WidgetsFlutterBinding.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) => service.setAsForegroundService());
    service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
    await service.setAsForegroundService();
  }

  // Configura stream do geolocator adequado para cada plataforma.
  final LocationSettings settings;
  if (Platform.isAndroid) {
    settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 3),
    );
  } else if (Platform.isIOS) {
    settings = AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 0,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  } else {
    settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  StreamSubscription<Position>? positionSub;

  // Quando o LocationService (main isolate) pedir parada, cancelamos o stream.
  service.on('stop').listen((_) {
    positionSub?.cancel();
    service.stopSelf();
  });

  positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
    (position) {
      // speed do geolocator está em m/s; convertemos para km/h.
      // Valor negativo significa que o GPS ainda não calculou a velocidade.
      final speedKmh = position.speed < 0
          ? 0.0
          : (position.speed * 3.6).clamp(0.0, 300.0);

      // Envia a leitura para o isolate principal (LocationService).
      service.invoke('update', {
        'speedKmh': speedKmh,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Mantém a notificação de foreground atualizada (Android).
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Tracking Velocidade',
          content: 'Velocidade: ${speedKmh.toStringAsFixed(0)} km/h',
        );
      }
    },
    onError: (Object e) => debugPrint('[BackgroundLocation] Erro: $e'),
  );
}

/// iOS exige um callback de "background fetch" separado.
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}
