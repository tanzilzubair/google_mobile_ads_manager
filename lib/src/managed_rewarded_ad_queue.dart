part of 'mobile_ads_manager.dart';

/// The class used to provide information on the rewarded ads to be
/// initialized
class RewardedAdInitializer {
  RewardedAdInitializer({
    required this.adUnitId,
    required this.count,
    this.fullScreenContentCallback,
    this.rewardedAdLoadCallback,
    this.adRequest = const AdRequest(),
  });

  /// The Ad Unit Id of the ad to be initialized
  final String adUnitId;

  /// The number of Ads an instance of [ManagedRewardedAdQueue] initialized with
  /// this instance will always try to pre-load and keep 'on-hand'
  final int count;

  /// The optional [FullScreenContentCallback] to attach to each [RewardedAd] managed by an instance
  /// of [ManagedRewardedAdAdQueue] initialized with this instance
  final FullScreenContentCallback<RewardedAd>? fullScreenContentCallback;

  /// The optional [RewardedAdAdLoadCallback] to attach to each [RewardedAd] managed by an instance
  /// of [ManagedRewardedAdAdQueue] initialized with this instance
  final RewardedAdLoadCallback? rewardedAdLoadCallback;

  /// The optional [AdRequest] to use when loading the ad
  final AdRequest adRequest;
}

/// The fully managed queue of [RewardedAd]s
class ManagedRewardedAdQueue {
  ManagedRewardedAdQueue(this._rewardedAdInitializer)
      : adUnitId = _rewardedAdInitializer.adUnitId,
        maxAdsInQueue = _rewardedAdInitializer.count,
        adsInQueue = 0,
        _retryLoadCount = 0;

  /// The config information for which rewarded ad to manage
  final RewardedAdInitializer _rewardedAdInitializer;

  /// The Ad Unit Id of the ad managed by this instance
  late final String adUnitId;

  /// The maximum number of ads that the queue will ever have at one time,
  /// determined by [RewardedAdInitializer.count]
  late final int maxAdsInQueue;

  /// The number of ads currently preloaded and ready in the queue
  int adsInQueue;

  /// The internal count used to decide how many times to keep trying
  /// upon the failed load of an ad
  int _retryLoadCount;

  /// The queue that holds the loaded rewarded ads, once initialized.
  final Queue<RewardedAd> _queue = Queue<RewardedAd>();

  /// Initializes the [ManagedRewardedAdQueue]
  Future<void> _initializeRewardedAdQueue() async {
    try {
      await Future.wait(
        <Future>[
          for (int i = 0; i <= _rewardedAdInitializer.count; i++)
            _addRewardedAd()
        ],
      );
    } catch (e) {
      /// Rethrowing the error, to be caught by an enclosing try-catch block
      /// somewhere higher up.
      rethrow;
    }
  }

  /// Shows a rewarded ad, based on the [showChance], automatically
  /// reloading the queue after the ad is shown, or doing nothing at all
  /// if the ad is not shown (due to [showChance])
  void showRewardedAd({
    double showChance = 1.0,
    required void Function(
      AdWithoutView ad,
      RewardItem reward,
    )
        onUserEarnedReward,
  }) {
    assert(
      showChance >= 0.0 && showChance <= 1.0,
      'showChance must be a double between 0.0 and 1.0, both inclusive',
    );

    /// Determining whether to show the ad, based on showChance
    final bool showAd = determineSuccess(successChance: showChance);

    if (showAd == true) {
      /// Guarding against trying to show when the queue is empty, which will only
      /// occur if all of [RewardedAdInitializer.count] ads are shown in rapid succession and the queue is
      /// exhausted before refills are completed
      if (_queue.isNotEmpty == true) {
        /// Showing the ad
        _queue.removeFirst().show(onUserEarnedReward: onUserEarnedReward);

        /// Updating the public count of how many ads are
        /// currently available in the queue
        adsInQueue = _queue.length;

        /// Reloading the queue
        _addRewardedAd();
      }
    }
  }

  /// Adds another rewarded ad to the internal managed queue,
  /// provided it does not exceed [_rewardedAdInitializer.count] elements
  /// in the queue
  Future<void> _addRewardedAd() async {
    /// Configuring the callbacks for the ad, and combining them with the user
    /// provided ones
    final FullScreenContentCallback<RewardedAd> fullScreenContentCallback =
        FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: _rewardedAdInitializer
          .fullScreenContentCallback?.onAdShowedFullScreenContent,
      onAdClicked:
          _rewardedAdInitializer.fullScreenContentCallback?.onAdClicked,
      onAdImpression:
          _rewardedAdInitializer.fullScreenContentCallback?.onAdImpression,
      onAdWillDismissFullScreenContent: _rewardedAdInitializer
          .fullScreenContentCallback?.onAdWillDismissFullScreenContent,
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        /// Calling the user provided function
        _rewardedAdInitializer
            .fullScreenContentCallback?.onAdDismissedFullScreenContent
            ?.call(ad);

        /// Disposing the ad. The code is inside a try block to guard
        /// against developers who accidentally include a call to .dispose()
        /// in their code
        try {
          ad.dispose();
        } catch (_) {}
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) async {
        /// Calling the user provided function
        _rewardedAdInitializer
            .fullScreenContentCallback?.onAdFailedToShowFullScreenContent
            ?.call(ad, error);

        /// Disposing the ad. The code is inside a try block to guard
        /// against developers who accidentally include a call to .dispose()
        /// in [_rewardedAdInitializer.fullScreenContentCallback?.onAdFailedToShowFullScreenContent]
        try {
          ad.dispose();
        } catch (_) {}
      },
    );

    /// Loading the ad, with (limited) retry mechanisms in place, tracked ephemerally
    /// by [_retryLoadCount]
    try {
      /// Loading the ad
      await RewardedAd.load(
        adUnitId: _rewardedAdInitializer.adUnitId,
        request: _rewardedAdInitializer.adRequest,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            if (_queue.length < _rewardedAdInitializer.count) {
              /// Attaching the callbacks
              ad.fullScreenContentCallback = fullScreenContentCallback;

              /// Inserting the fully loaded ad into the queue
              _queue.add(ad);

              /// Updating the public count of how many ads are
              /// currently available in the queue
              adsInQueue = _queue.length;

              /// Calling the user provided function
              _rewardedAdInitializer.rewardedAdLoadCallback?.onAdLoaded(ad);
            } else {
              /// Disposing the ad as it was an excess, probably a result
              /// of showing and requesting ad loads in rapid succession.
              ad.dispose();
            }
          },
          onAdFailedToLoad: (LoadAdError error) async {
            /// Calling the user provided function
            _rewardedAdInitializer.rewardedAdLoadCallback
                ?.onAdFailedToLoad(error);

            /// Retrying the load on fail, via recursion, up to 3 times before cancelling
            _retryLoadCount += 1;

            if (_retryLoadCount > 3) {
              /// Resetting the load count and exiting, if the retry count exceeds 3
              _retryLoadCount = 0;
              return;
            } else {
              /// Retrying
              _addRewardedAd();
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

  /// Disposes all resources used by the [ManagedRewardedAdQueue] instance.
  /// Note that along with disposing all of the ads managed by the instance, the
  /// instance will also no longer be retrievable from
  /// [MobileAdsManager.instance.getManagedRewardedAdQueue], or
  /// [MobileAdsManager.instance.getAllManagedRewardedAdQueues]
  void dispose() {
    /// Disposing all of the ads
    for (final RewardedAd rewardedAd in _queue) {
      /// Disposing the ad. The call is inside a try-catch block to suppress errors, if
      /// for whatever reason dispose is called twice or more times on the same ad
      try {
        rewardedAd.dispose();
      } catch (_) {}
    }

    /// Removing all the ads from the internal queue
    _queue.clear();

    /// Removing this instance of [ManagedRewardedAdQueue] from the internal
    /// list of instantiated [ManagedRewardedAdQueue] maintained by
    /// [MobileAdsManager.instance._managedRewardedAdQueueList]
    MobileAdsManager.instance._managedRewardedAdQueueList
        .removeWhere((ManagedRewardedAdQueue queue) {
      /// Matching Ad Unit Ids to determine which queue to remove, as there
      /// can only be one queue per Ad Unit Id
      return queue.adUnitId == adUnitId;
    });
  }
}
