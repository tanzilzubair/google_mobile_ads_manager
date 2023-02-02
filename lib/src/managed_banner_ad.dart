part of 'mobile_ads_manager.dart';

/// The class used to provide information on the banner ads to be
/// initialized
class BannerAdInitializer {
  BannerAdInitializer({
    required this.adUnitId,
    required this.bannerAdSize,
    this.adRequest = const AdRequest(),
    this.bannerAdListener = const BannerAdListener(),
  });

  /// The Ad Unit Id of the ad to be initialized
  final String adUnitId;

  /// The size of the banner Ad
  final AdSize bannerAdSize;

  /// The optional [AdRequest] to use when loading the ad
  final AdRequest adRequest;

  /// The optional [BannerAdListener] to use when loading the ad
  final BannerAdListener bannerAdListener;
}

class ManagedBannerAd {
  ManagedBannerAd(this._bannerAdInitializer)
      : adUnitId = _bannerAdInitializer.adUnitId,
        _retryLoadCount = 0;

  /// The config information for the banner ad to manage
  final BannerAdInitializer _bannerAdInitializer;

  /// The Ad Unit Id of the ad managed by this instance
  late final String adUnitId;

  /// The actual banner Ad
  late final BannerAd _bannerAd;

  /// The internal count used to decide how many times to keep trying
  /// upon the failed load of an ad
  int _retryLoadCount;

  Future<void> _initializeBannerAd() async {
    /// Configuring the callbacks for the ad, and combining them with the user
    /// provided ones
    final BannerAdListener bannerAdListener = BannerAdListener(
      onAdLoaded: _bannerAdInitializer.bannerAdListener.onAdLoaded,
      onAdFailedToLoad: (Ad ad, LoadAdError error) {
        /// Calling the user provided function
        _bannerAdInitializer.bannerAdListener.onAdFailedToLoad?.call(ad, error);

        /// Disposing the ad. The code is inside a try block to guard
        /// against developers who accidentally include a call to .dispose()
        /// in [_bannerAdInitializer.bannerAdListener.onAdFailedToLoad?]
        ///
        /// Note that, for banner Ads, disposing ads that DO load successfully
        /// is entirely on the developer implementing the library, as there is
        /// no automatic way to set that up, since it is to happen whenever an
        /// [AdWidget] containing the banner Ad is removed from the Widget tree
        try {
          ad.dispose();
        } catch (_) {}

        /// Retrying the load on fail, via recursion, up to 3 times before cancelling
        _retryLoadCount += 1;

        if (_retryLoadCount > 3) {
          /// Resetting the load count and propagating the error up, if the retry count exceeds 3
          _retryLoadCount = 0;
          throw error;
        } else {
          /// Retrying
          _loadAd();
        }
      },
      onAdOpened: _bannerAdInitializer.bannerAdListener.onAdOpened,
      onAdClosed: _bannerAdInitializer.bannerAdListener.onAdClosed,
      onAdImpression: _bannerAdInitializer.bannerAdListener.onAdImpression,
    );

    /// Configuring the ad
    _bannerAd = BannerAd(
      size: _bannerAdInitializer.bannerAdSize,
      adUnitId: _bannerAdInitializer.adUnitId,
      listener: bannerAdListener,
      request: _bannerAdInitializer.adRequest,
    );

    /// Loading the ad. If the ad fails, the onAdFailedToLoad callback configured above
    /// sets up the retry mechanism, and calls _loadAd() via recursion
    _loadAd();
  }

  /// Loads the banner Ad
  Future<void> _loadAd() async {
    /// Loading the ad, with (limited) retry mechanisms in place, tracked ephemerally
    /// by [_retryLoadCount]
    try {
      /// Loading the ad
      await _bannerAd.load();
    } catch (e) {
      /// Rethrowing the error, to be caught by an enclosing try-catch block
      /// somewhere higher up.
      rethrow;
    }
  }

  /// Used to retrieve the banner ad.
  ///
  /// Note: Do NOT call dispose on the Ad directly. Dispose should be
  /// called on the [ManagedBannerAd] instance, as otherwise references
  /// to disposed ads may remain inside the [MobileAdsManager]
  BannerAd getAd() {
    return _bannerAd;
  }

  /// Disposes all resources used by the [ManagedBannerAd] instance.
  /// Along with disposing all of the ads managed by the instance, the
  /// instance will also no longer be retrievable from
  /// [MobileAdsManager.instance.getManagedBannerAd], or
  /// [MobileAdsManager.instance.getAllManagedBannerAds]
  ///
  /// Note that, for banner ads, disposing ads is entirely on the developer
  /// implementing the library, as there is no automatic way to set that up
  /// (except for when the banner ad fails to load), since it is to happen
  /// whenever an [AdWidget] containing the banner ad is removed from the Widget tree
  void dispose() {
    /// Disposing the ad. The call is inside a try-catch block to suppress errors, if
    /// for whatever reason dispose is called twice or more times.
    try {
      _bannerAd.dispose();
    } catch (_) {}

    /// Removing the reference to this instance of [ManagedBannerAd] from
    /// [MobileAdsManager.instance]
    MobileAdsManager.instance._managedBannerAdList
        .removeWhere((ManagedBannerAd ad) {
      /// Matching Ad Unit Ids to determine which ad to remove, as there
      /// can only be one queue per Ad Unit Id
      return ad.adUnitId == adUnitId;
    });
  }
}
