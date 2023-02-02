part of 'mobile_ads_manager.dart';

/// The class used to provide information on the app open ad to be
/// initialized
class AppOpenAdInitializer {
  AppOpenAdInitializer({
    required this.adUnitId,
    this.loadChance = 1.0,
    this.showOnLoad = true,
    this.fullScreenContentCallback,
    this.appOpenAdLoadCallback,
    this.adRequest = const AdRequest(),
    this.orientation = AppOpenAd.orientationPortrait,
  }) : assert(
          loadChance >= 0.0 && loadChance <= 1.0,
          'loadChance must be a double between 0.0 and 1.0, both inclusive',
        );

  /// The Ad Unit Id of the ad to be initialized
  final String adUnitId;

  /// The probability, expressed from 0.0 - 1.0, that the Ad will load.
  /// This is similar to [showChance] when showing interstitial or rewarded ads, except
  /// that loading App Open Ads is s significant wait for users, and a horrible user
  /// experience if that Ad is subsequently not shown, since the app cannot do anything till
  /// the Ad is fully loaded.
  ///
  /// As such, this handles not simply showing the Ad, but whether it is loaded in the first place,
  /// allowing for that significant wait to be skipped, in the event the Ad is not to be shown during that
  /// session, based on the probability.
  final double loadChance;

  /// Whether the ad should automatically be shown (and subsequently disposed) on load.
  /// Disabling this means the ad must be shown manually using [ManagedAppOpenAd.showAppOpenAd],
  /// but still with automatic disposing.
  final bool showOnLoad;

  /// The optional [FullScreenContentCallback] to attach to the [AppOpenAd] managed by an instance
  /// of [ManagedAppOpenAd] initialized with this instance
  final FullScreenContentCallback<AppOpenAd>? fullScreenContentCallback;

  /// The optional [AppOpenAdLoadCallback] to attach to the [AppOpenAd] managed by an instance
  /// of [ManagedAppOpenAd] initialized with this instance
  final AppOpenAdLoadCallback? appOpenAdLoadCallback;

  /// The optional [AdRequest] to use when loading the ad
  final AdRequest adRequest;

  /// The orientation to load the Ad in. Choose one from:
  /// [AppOpenAd.orientationPortrait]
  /// [AppOpenAd.orientationLandscapeLeft]
  /// [AppOpenAd.orientationLandscapeRight]
  final int orientation;
}

/// The class used to interact with the underlying [AppOpenAd] in a secure
/// and managed way
class ManagedAppOpenAd {
  ManagedAppOpenAd(this._appOpenAdInitializer)
      : adUnitId = _appOpenAdInitializer.adUnitId;

  /// The config information for the App Open ad to manage
  final AppOpenAdInitializer _appOpenAdInitializer;

  /// The Ad Unit Id of the ad managed by this instance
  late final String adUnitId;

  /// The actual App Open Ad
  late final AppOpenAd _appOpenAd;

  /// Internal state used to check if the app is loaded before showing or disposing it
  bool _appOpenAdLoaded = false;

  Future<void> _initializeAppOpenAd() async {
    /// Configuring the callbacks for the ad, and combining them with the user
    /// provided ones
    final FullScreenContentCallback<AppOpenAd> fullScreenContentCallback =
        FullScreenContentCallback<AppOpenAd>(
      onAdShowedFullScreenContent: _appOpenAdInitializer
          .fullScreenContentCallback?.onAdShowedFullScreenContent,
      onAdClicked: _appOpenAdInitializer.fullScreenContentCallback?.onAdClicked,
      onAdImpression:
          _appOpenAdInitializer.fullScreenContentCallback?.onAdImpression,
      onAdWillDismissFullScreenContent: _appOpenAdInitializer
          .fullScreenContentCallback?.onAdWillDismissFullScreenContent,
      onAdDismissedFullScreenContent: (AppOpenAd ad) {
        /// Calling the user provided function
        _appOpenAdInitializer
            .fullScreenContentCallback?.onAdDismissedFullScreenContent
            ?.call(ad);

        /// Disposing the ad. The code is inside a try block to guard
        /// against developers who accidentally include a call to .dispose()
        /// in their code
        try {
          dispose();
        } catch (_) {}
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) async {
        /// Calling the user provided function
        _appOpenAdInitializer
            .fullScreenContentCallback?.onAdFailedToShowFullScreenContent
            ?.call(ad, error);

        /// Disposing the ad. The code is inside a try block to guard
        /// against developers who accidentally include a call to .dispose()
        /// in [_appOpenAdInitializer.fullScreenContentCallback?.onAdFailedToShowFullScreenContent]
        try {
          dispose();
        } catch (_) {}
      },
    );

    /// Loading the ad.
    /// Note that unlike all the other types of ads, App Open ads have no loading
    /// retry mechanism in place, as in most cases that would take much too long,
    /// leading to terrible user experiences. In such cases, it is better to simply
    /// not show it for that user session.
    try {
      /// Loading the ad
      await AppOpenAd.load(
        adUnitId: _appOpenAdInitializer.adUnitId,
        orientation: _appOpenAdInitializer.orientation,
        request: _appOpenAdInitializer.adRequest,
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (AppOpenAd ad) {
            /// Attaching the callbacks
            ad.fullScreenContentCallback = fullScreenContentCallback;

            /// Toggling the loading state to successful
            _appOpenAdLoaded = true;

            /// Calling the user provided function
            _appOpenAdInitializer.appOpenAdLoadCallback?.onAdLoaded(ad);

            /// Assigning the ad to the instance's state
            _appOpenAd = ad;

            /// Showing the ad, if [_appOpenAdInitializer.showOnLoad] is true
            if (_appOpenAdInitializer.showOnLoad == true) {
              ad.show();
            }
          },
          onAdFailedToLoad: (LoadAdError error) async {
            /// Calling the user provided function.
            /// Note that here particularly the user provided function is not
            /// provided directly to onAdFailedToLoad and is instead provided
            /// like this to allow it to be null
            _appOpenAdInitializer.appOpenAdLoadCallback
                ?.onAdFailedToLoad(error);
          },
        ),
      );
    } catch (e) {
      /// Rethrowing the error, to be caught by an enclosing try-catch block
      /// somewhere higher up.
      rethrow;
    }
  }

  /// Shows the App Open Ad, and automatically disposes it
  void showAppOpenAd() {
    /// Checking if the App Open Ad is loaded
    if (_appOpenAdLoaded == true) {
      /// Showing the ad, with the dispose callback attached to this ad's
      /// [FullScreenContentCallback] handling automatic disposing
      _appOpenAd.show();
    }
  }

  /// Disposes all resources used by the [ManagedAppOpenAd] instance.
  /// Note that along with disposing all of the ads managed by the instance, the
  /// instance will also no longer be retrievable from
  /// [MobileAdsManager.instance.managedOpenAd]
  void dispose() {
    /// Disposing the ad. The call is inside a try-catch block to suppress errors, if
    /// for whatever reason dispose is called twice or more times.
    try {
      _appOpenAd.dispose();
    } catch (_) {}

    /// Removing the reference to this instance of [ManagedAppOpenAd] from
    /// [MobileAdsManager.instance]
    MobileAdsManager.instance._managedAppOpenAd = null;
  }
}
