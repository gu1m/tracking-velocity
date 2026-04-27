import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';

// Gerado pelo `flutterfire configure`
import 'firebase_options.dart';

import 'models/app_user.dart';
import 'services/auth_service.dart';
import 'services/background_location.dart';
import 'services/billing_service.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/permissions_screen.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  // ── Firebase ──────────────────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── AdMob ─────────────────────────────────────────────────────────────────
  await MobileAds.instance.initialize();

  // ── Background GPS ────────────────────────────────────────────────────────
  await initializeBackgroundService();

  runApp(const TrackingVelocidadeApp());
}

class TrackingVelocidadeApp extends StatelessWidget {
  const TrackingVelocidadeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => StorageService()),
        ChangeNotifierProvider(create: (_) => BillingService()),
      ],
      child: MaterialApp(
        title: 'Tracking Velocidade',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('pt', 'BR')],
        home: const _Root(),
      ),
    );
  }
}

/// Decide a tela com base no estado de auth e permissões.
/// Toda navegação pós-login passa por aqui — sem push imperativo nas telas de login.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  /// null = ainda checando, true = concedida, false = não concedida
  bool? _hasPermission;
  String? _initializedUid;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (mounted) {
      setState(() => _hasPermission = status.isGranted);
    }
  }

  Future<void> _onPermissionGranted() async {
    final locationService = context.read<LocationService>();
    await locationService.startBackgroundService();
    if (mounted) setState(() => _hasPermission = true);
  }

  /// Inicializa StorageService e LocationService sempre que o usuário mudar.
  void _initializeServicesForUser(AppUser user) {
    if (_initializedUid == user.uid) return;
    _initializedUid = user.uid;
    context.read<StorageService>().initialize(user);
    context.read<LocationService>().updateUser(user);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // Carregando auth
    if (auth.isLoading || _hasPermission == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Não autenticado → onboarding
    if (!auth.isAuthenticated) {
      _initializedUid = null;
      return const OnboardingScreen();
    }

    // Inicializa serviços para o usuário logado (idempotente — executa 1x por uid)
    _initializeServicesForUser(auth.currentUser!);

    // Autenticado mas sem permissão → tela de permissões
    if (!_hasPermission!) {
      return PermissionsScreen(onGranted: _onPermissionGranted);
    }

    // Autenticado e com permissão → app principal
    return const AppShell();
  }
}
