import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob identifiers are build-time configurable. The repository keeps
/// Google's official test IDs by default; production CI can inject real IDs
/// without committing them to source control.
class AdUnitIds {
  static const banner = String.fromEnvironment(
    'KADD_ADMOB_BANNER_ID',
    defaultValue: kAndroidBannerTestId,
  );
  static const interstitial = String.fromEnvironment(
    'KADD_ADMOB_INTERSTITIAL_ID',
    defaultValue: kAndroidInterstitialTestId,
  );

  static const kAndroidBannerTestId = 'ca-app-pub-3940256099942544/6300978111';
  static const kAndroidInterstitialTestId = 'ca-app-pub-3940256099942544/1033173712';
}

/// Central place for everything AdMob: SDK init, GDPR/UK consent (UMP) via
/// the bundled User Messaging Platform APIs, and loading/showing the
/// interstitial. Banner ads are created directly by [BannerAdWidget] (they
/// need to own their own instance per widget), but they still read
/// [AdUnitIds.banner] from here.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  bool _loadingInterstitial = false;

  /// Existing frequency cap: every 3rd successful unlock shows an ad when
  /// one is ready. This behavior is intentionally unchanged.
  int _unlocksSinceLastAd = 0;
  static const _unlocksBetweenAds = 3;

  Future<void> init() async {
    if (_initialized) return;
    await _requestConsent();
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
  }

  Future<void> _requestConsent() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            await _loadAndShowConsentFormIfRequired();
          }
        } catch (e) {
          debugPrint('AdsService: consent form step failed, continuing: $e');
        }
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        debugPrint('AdsService: consent info update failed: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  Future<void> _loadAndShowConsentFormIfRequired() {
    final completer = Completer<void>();
    ConsentForm.loadConsentForm(
      (ConsentForm form) async {
        final status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          form.show((FormError? formError) {
            if (!completer.isCompleted) completer.complete();
          });
        } else {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (FormError error) {
        debugPrint('AdsService: loading consent form failed: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  void _loadInterstitial() {
    if (_loadingInterstitial || _interstitialAd != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdsService: interstitial failed to load: $error');
          _interstitialAd = null;
          _loadingInterstitial = false;
        },
      ),
    );
  }

  /// Call after a successful unlock (reps verified or prayer-rug verified).
  void maybeShowInterstitialAfterUnlock() {
    _unlocksSinceLastAd++;
    if (_unlocksSinceLastAd < _unlocksBetweenAds) return;
    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _unlocksSinceLastAd = 0;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
    );
    ad.show();
  }
}
