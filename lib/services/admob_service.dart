import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerAdLoaded = false;
  bool _isInterstitialAdLoaded = false;

  // 개발 모드 여부 (배포 시 false로 변경)
  static const bool _isDevelopmentMode = false;

  // iOS 광고 ID
  static const String _iosBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _iosInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  // Android 광고 ID
  static const String _androidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _androidInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // 프로덕션 iOS 광고 ID
  static const String _productionIosBannerAdUnitId =
      'ca-app-pub-1259081879380860/9195843405';
  static const String _productionIosInterstitialAdUnitId =
      'ca-app-pub-1259081879380860/9450191948';

  // 프로덕션 Android 광고 ID
  static const String _productionAndroidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _productionAndroidInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // 현재 플랫폼에 따른 배너 광고 ID 반환
  String get _bannerAdUnitId {
    if (_isDevelopmentMode) {
      return Platform.isIOS ? _iosBannerAdUnitId : _androidBannerAdUnitId;
    } else {
      return Platform.isIOS
          ? _productionIosBannerAdUnitId
          : _productionAndroidBannerAdUnitId;
    }
  }

  // 현재 플랫폼에 따른 전면 광고 ID 반환
  String get _interstitialAdUnitId {
    if (_isDevelopmentMode) {
      return Platform.isIOS
          ? _iosInterstitialAdUnitId
          : _androidInterstitialAdUnitId;
    } else {
      return Platform.isIOS
          ? _productionIosInterstitialAdUnitId
          : _productionAndroidInterstitialAdUnitId;
    }
  }

  // 배너 광고 로드
  Future<void> loadBannerAd() async {
    if (_bannerAd != null) {
      _bannerAd!.dispose();
    }

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerAdLoaded = true;
        },
        onAdFailedToLoad: (ad, error) {
          _isBannerAdLoaded = false;
          ad.dispose();
        },
        onAdClicked: (ad) {
          // 광고 클릭 처리
        },
        onAdClosed: (ad) {
          // 광고 닫힘 처리
        },
      ),
    );

    try {
      await _bannerAd!.load();
    } catch (e) {
      _isBannerAdLoaded = false;
    }
  }

  // 전면 광고 로드
  Future<void> loadInterstitialAd() async {
    if (_interstitialAd != null) {
      _interstitialAd!.dispose();
    }

    try {
      await InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialAdLoaded = true;
          },
          onAdFailedToLoad: (error) {
            _isInterstitialAdLoaded = false;
          },
        ),
      );
    } catch (e) {
      _isInterstitialAdLoaded = false;
    }
  }

  // 전면 광고 표시
  Future<void> showInterstitialAd() async {
    if (_interstitialAd != null && _isInterstitialAdLoaded) {
      await _interstitialAd!.show();
      _isInterstitialAdLoaded = false;
    }
  }

  // AdMob 초기화
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      // 초기화 실패 처리
    }
  }

  // 배너 광고 가져오기
  BannerAd? get bannerAd => _bannerAd;
  bool get isBannerAdLoaded => _isBannerAdLoaded;

  // 전면 광고 상태 가져오기
  bool get isInterstitialAdLoaded => _isInterstitialAdLoaded;

  // 리소스 정리
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
  }
}
