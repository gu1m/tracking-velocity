import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../services/location_service.dart';

/// Banner AdMob exibido apenas para usuários Free.
///
/// Use `AdmobBanner.ifFree(context)` para retornar o banner ou
/// um SizedBox.shrink() de acordo com o plano do usuário.
class AdmobBanner extends StatefulWidget {
  const AdmobBanner({super.key});

  /// Retorna o banner se o usuário for Free, SizedBox.shrink() se Premium.
  static Widget ifFree(BuildContext context) {
    final location = context.watch<LocationService>();
    if (!location.showAds) return const SizedBox.shrink();
    return const AdmobBanner();
  }

  @override
  State<AdmobBanner> createState() => _AdmobBannerState();
}

class _AdmobBannerState extends State<AdmobBanner> {
  BannerAd? _banner;
  bool _loaded = false;

  /// IDs de teste do Google (substitua pelos seus em produção):
  /// Android: ca-app-pub-3940256099942544/6300978111
  /// iOS:     ca-app-pub-3940256099942544/2934735716
  static const String _adUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // TESTE — troque em produção

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _banner = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMob] Falha ao carregar banner: ${error.message}');
          ad.dispose();
          _banner = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _banner == null) {
      // Espaço reservado enquanto carrega
      return const SizedBox(height: 50);
    }

    return Container(
      alignment: Alignment.center,
      width: _banner!.size.width.toDouble(),
      height: _banner!.size.height.toDouble(),
      child: AdWidget(ad: _banner!),
    );
  }
}
