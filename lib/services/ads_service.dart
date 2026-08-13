import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad unit IDs. These are Google's official *test* IDs — they always serve
/// a clearly-labelled test ad and are safe to ship in debug builds, but
/// they never earn real revenue. Before publishing, create a real AdMob
/// account + ad units at https://apps.admob.com and swap these three
/// values (see PLAYSTORE_CHECKLIST.md § AdMob for the full walkthrough).
/// The app ID itself lives in android_additions/manifest_application.xml
/// and needs the same swap.
class AdUnitIds {
  static const banner = kAndroidBannerTestId;
  static const interstitial = kAndroidInterstitialTestId;

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

  /// Simple frequency cap so an interstitial doesn't fire on every single
  /// unlock — that would make the "earn your unlock" moment feel punished
  /// rather than rewarded. Every 3rd successful unlock shows one instead.
  int _unlocksSinceLastAd = 0;
  static const _unlocksBetweenAds = 3;

  /// Call once, early in main() before runApp. Requests EU/UK consent
  /// first (required by AdMob policy — ads must not be requested with
  /// personalization before consent is resolved for those users), then
  /// initializes the Mobile Ads SDK and preloads the first interstitial.
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
        // Fail open: if the consent info update itself fails (e.g. no
        // network on first launch), don't block the whole app on it —
        // MobileAds.instance.initialize() will just proceed with
        // non-personalized defaults where required.
        debugPrint('AdsService: consent info update failed: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    // Safety timeout — never let a slow/broken consent network call hang
    // app startup indefinitely.
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
  /// Respects the frequency cap above — most calls are a no-op besides the
  /// counter increment.
  void maybeShowInterstitialAfterUnlock() {
    _unlocksSinceLastAd++;
    if (_unlocksSinceLastAd < _unlocksBetweenAds) return;
    final ad = _interstitialAd;
    if (ad == null) {
      // Not ready this time (still loading, or previous load failed) —
      // don't reset the counter, so we try again on the next unlock
      // instead of silently skipping this "turn".
      _loadInterstitial();
      return;
    }
    _unlocksSinceLastAd = 0;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial(); // preload the next one
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
