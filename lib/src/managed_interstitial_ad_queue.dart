part of 'mobile_ads_manager.dart';

/// The class used to provide information on the interstitial ads to be
/// initialized
class InterstitialAdInitializer {
  InterstitialAdInitializer({
    required this.adUnitId,
    required this.count,
    this.fullScreenContentCallback,
    this.interstitialAdLoadCallback,
    this.adRequest = const AdRequest(),
  });

  /// The Ad Unit Id of the ad to be initialized
  final String adUnitId;

  /// The number of Ads an instance of [ManagedInterstitialAdQueue] initialized with
  /// this instance will always try to pre-load and keep 'on-hand'
  final int count;

  /// The optional [FullScreenContentCallback] to attach to each [InterstitialAd] managed by an instance
  /// of [ManagedInterstitialAdQueue] initialized with this instance
  final FullScreenContentCallback<InterstitialAd>? fullScreenContentCallback;

  /// The optional [InterstitialAdLoadCallback] to attach to each [InterstitialAd] managed by an instance
  /// of [ManagedInterstitialAdQueue] initialized with this instance
  final InterstitialAdLoadCallback? interstitialAdLoadCallback;

  /// The optional [AdRequest] to use when loading the ad
  final AdRequest adRequest;
}

/// The fully managed queue of [InterstitialAd]s
class ManagedInterstitialAdQueue {
  ManagedInterstitialAdQueue(this._interstitialAdInitializer)
      : adUnitId = _interstitialAdInitializer.adUnitId,
        maxAdsInQueue = _interstitialAdInitializer.count,
        adsInQueue = 0,
        _retryLoadCount = 0;

  /// The config information for which interstitial ad to manage
  final InterstitialAdInitializer _interstitialAdInitializer;

  /// The Ad Unit Id of the ad managed by this instance
  late final String adUnitId;

  /// The maximum number of ads that the queue will ever have at one time,
  /// determined by [InterstitialAdInitializer.count]
  late final int maxAdsInQueue;

  /// The number of ads currently preloaded and ready in the queue
  int adsInQueue;

  /// The internal count used to decide how many times to keep trying
  /// upon the failed load of an ad
  int _retryLoadCount;

  /// The queue that holds the loaded interstitial ads, once initialized.
  final Queue<InterstitialAd> _queue = Queue<InterstitialAd>();

  /// Initializes the [ManagedInterstitialAdQueue]
  Future<void> _initializeInterstitialAdQueue() async {
    try {
      await Future.wait(
        <Future>[
          for (int i = 0; i <= _interstitialAdInitializer.count; i++)
            _addInterstitialAd()
        ],
      );
    } catch (e) {
      /// Rethrowing the error, to be caught by an enclosing try-catch block
      /// somewhere higher up.
      rethrow;
    }
  }

  /// Shows an interstitial ad, based on the [showChance], automatically
  /// reloading the queue after the ad is shown, or doing nothing at all
  /// if the ad is not shown (due to [showChance])
  void showInterstitialAd({double showChance = 1.0}) {
    assert(
      showChance >= 0.0 && showChance <= 1.0,
      'showChance must be a double between 0.0 and 1.0, both inclusive',
    );

    /// Determining whether to show the ad, based on showChance
    final bool showAd = determineSuccess(successChance: showChance);

    if (showAd == true) {
      /// Guarding against trying to show when the queue is empty, which will only
      /// occur if all of [InterstitialAdInitializer.count] ads are shown in rapid succession and the queue is
      /// exhausted before refills are completed
      if (_queue.isNotEmpty == true) {
        /// Showing the ad
        _queue.removeFirst().show();

        /// Updating the public count of how many ads are
        /// currently available in the queue
        adsInQueue = _queue.length;

        /// Reloading the queue
        _addInterstitialAd();
      }
    }
  }

  /// Adds another interstitial ad to the internal managed queue,
  /// provided it does not exceed [_interstitialAdInitializer.count] elements
  /// in the queue
  Future<void> _addInterstitialAd() async {
    /// Configuring the callbacks for the ad, and combining them with the user
    /// provided ones
    final FullScreenContentCallback<InterstitialAd> fullScreenContentCallback =
        FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: _interstitialAdInitializer
          .fullScreenContentCallback?.onAdShowedFullScreenContent,
      onAdClicked:
          _interstitialAdInitializer.fullScreenContentCallback?.onAdClicked,
      onAdImpression:
          _interstitialAdInitializer.fullScreenContentCallback?.onAdImpression,
      onAdWillDismissFullScreenContent: _interstitialAdInitializer
          .fullScreenContentCallback?.onAdWillDismissFullScreenContent,
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        /// Calling the user provided function
        _interstitialAdInitializer
            .fullScreenContentCallback?.onAdDismissedFullScreenContent
            ?.call(ad);

        /// Disposing the ad. The code is inside a try block to guard
        /// against developers who accidentally include a call to .dispose()
        /// in their code
        try {
          ad.dispose();
        } catch (_) {}
      },
      onAdFailedToShowFullScreenContent:
          (InterstitialAd ad, AdError error) async {
        /// Calling the user provided function
        _interstitialAdInitializer
            .fullScreenContentCallback?.onAdFailedToShowFullScreenContent
            ?.call(ad, error);

        /// Disposing the ad. The code is inside a try block to guard
        /// against developers who accidentally include a call to .dispose()
        /// in [_interstitialAdInitializer.fullScreenContentCallback?.onAdFailedToShowFullScreenContent]
        try {
          ad.dispose();
        } catch (_) {}
      },
    );

    /// Loading the ad, with (limited) retry mechanisms in place, tracked ephemerally
    /// by [_retryLoadCount]
    try {
      /// Loading the ad
      await InterstitialAd.load(
        adUnitId: _interstitialAdInitializer.adUnitId,
        request: _interstitialAdInitializer.adRequest,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            if (_queue.length < _interstitialAdInitializer.count) {
              /// Attaching the callbacks
              ad.fullScreenContentCallback = fullScreenContentCallback;

              /// Inserting the fully loaded ad into the queue
              _queue.add(ad);

              /// Updating the public count of how many ads are
              /// currently available in the queue
              adsInQueue = _queue.length;

              /// Calling the user provided function
              _interstitialAdInitializer.interstitialAdLoadCallback
                  ?.onAdLoaded(ad);
            } else {
              /// Disposing the ad as it was an excess, probably a result
              /// of showing and requesting ad loads in rapid succession.
              ad.dispose();
            }
          },
          onAdFailedToLoad: (LoadAdError error) async {
            /// Calling the user provided function
            _interstitialAdInitializer.interstitialAdLoadCallback
                ?.onAdFailedToLoad(error);

            /// Retrying the load on fail, via recursion, up to 3 times before cancelling
            _retryLoadCount += 1;

            if (_retryLoadCount > 3) {
              /// Resetting the load count and exiting, if the retry count exceeds 3
              _retryLoadCount = 0;
              return;
            } else {
              /// Retrying
              _addInterstitialAd();
            }
          },
        ),
      );
    } catch (e) {
      /// Rethrowing the error, to be caught by an enclosing try-catch block
      /// somewhere higher up.
      rethrow;
    }
  }

  /// Disposes all resources used by the [ManagedInterstitialAdQueue] instance.
  /// Note that along with disposing all of the ads managed by the instance, the
  /// instance will also no longer be retrievable from
  /// [MobileAdsManager.instance.getManagedInterstitialAdQueue], or
  /// [MobileAdsManager.instance.getAllManagedInterstitialAdQueues]
  void dispose() {
    /// Disposing all of the ads
    for (final InterstitialAd interstitialAd in _queue) {
      /// Disposing the ad. The call is inside a try-catch block to suppress errors, if
      /// for whatever reason dispose is called twice or more times.
      try {
        interstitialAd.dispose();
      } catch (_) {}
    }

    /// Removing all the ads from the internal queue
    _queue.clear();

    /// Removing this instance of [ManagedInterstitialAdQueue] from the internal
    /// list of instantiated [ManagedInterstitialAdQueue] maintained by
    /// [MobileAdsManager.instance._managedInterstitialAdQueueList]
    MobileAdsManager.instance._managedInterstitialAdQueueList
        .removeWhere((ManagedInterstitialAdQueue queue) {
      /// Matching Ad Unit Ids to determine which queue to remove, as there
      /// can only be one queue per Ad Unit Id
      return queue.adUnitId == adUnitId;
    });
  }
}
