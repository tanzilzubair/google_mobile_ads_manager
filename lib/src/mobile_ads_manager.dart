import 'dart:async';
import 'dart:collection';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads_manager/src/utilities.dart';

part 'managed_app_open_ad.dart';
part 'managed_banner_ad.dart';
part 'managed_interstitial_ad_queue.dart';
part 'managed_rewarded_ad_queue.dart';

enum LoadingStrategy {
  completeLoading,
  balancedLoading,
  fastLoading,
}

/// Used to interact with the MobileAds SDK, initialize and retrieve managed versions of
/// of App Open, Banner, Interstitial and Rewarded ads, as well as dispose them.
class MobileAdsManager {
  /// Private constructor
  MobileAdsManager._();

  /// Setting up the AdManager singleton
  static final MobileAdsManager _instance = MobileAdsManager._();

  /// Getter for static instance
  static MobileAdsManager get instance => _instance;

  /// The [ManagedAppOpenAd], which may or may not be null, depending on whether
  /// it was initialized, or whether it was initialized and the showed and disposed
  ManagedAppOpenAd? _managedAppOpenAd;

  /// The list of [ManagedBannerAd]s, which is an internal reference to
  /// all instantiated [ManagedBannerAd]s, and what
  /// [getManagedBannerAd] uses to find the appropriate queue
  final List<ManagedBannerAd> _managedBannerAdList = <ManagedBannerAd>[];

  /// The list of [ManagedInterstitialAdQueue]s, which is an internal reference to
  /// all instantiated [ManagedInterstitialAdQueue]s, and what
  /// [getManagedInterstitialAdQueue] uses to find the appropriate queue
  final List<ManagedInterstitialAdQueue> _managedInterstitialAdQueueList =
      <ManagedInterstitialAdQueue>[];

  /// The list of [ManagedRewardedAdQueue]s, which is an internal reference toZ
  /// all instantiated [ManagedRewardedAdQueue]s, and what
  /// [getManagedInterstitialAdQueue] uses to find the appropriate queue
  final List<ManagedRewardedAdQueue> _managedRewardedAdQueueList =
      <ManagedRewardedAdQueue>[];

  /// Flag checked against to determine whether the JUST the SDK has been initialized or not.
  /// Used internally to guard calls to public functions and prevent them from being called
  /// without first initializing [MobileAdsManager]
  bool _sdkInitializationComplete = false;

  /// Public flag that can be checked against to determine whether the [initializeSDK]
  /// method has (fully) successfully completed or not
  bool initializationComplete = false;

  /// Initializes the AdMob SDK, along with fully managed queues for all ads provided
  Future<void> initializeSDK({
    LoadingStrategy loadingStrategy = LoadingStrategy.balancedLoading,
    AppOpenAdInitializer? appOpenAd,
    List<InterstitialAdInitializer>? interstitialAds,
    List<RewardedAdInitializer>? rewardedAds,
    List<BannerAdInitializer>? bannerAds,
    void Function(Object? error, StackTrace stackTrace)?
        onSDKInitializationError,
    void Function(Object? error, StackTrace stackTrace)?
        onAdsInitializationError,
  }) async {
    assert(
      !(loadingStrategy == LoadingStrategy.fastLoading && appOpenAd != null),
      'App Open ads must show soon after app open; as such, cannot fast load',
    );

    /// Asynchronously initializes SDK and requests appropriate ads. Does not
    /// await for anything. Technically unsafe, but done under the assumption
    /// things will be ready by the time they're needed. [initializationComplete]
    /// can be checked against, to ensure safety when calling methods after a
    /// fast load.
    if (loadingStrategy == LoadingStrategy.fastLoading) {
      /// Guarding against errors
      try {
        /// Initializing the SDK, followed by all the ads. Nothing is awaited for,
        /// with the assumption everything will finish loading before they're needed.
        MobileAds.instance.initialize().then(
          (InitializationStatus _) async {
            /// Flag checked against to determine whether the JUST the SDK has been initialized or not.
            /// Used internally to guard calls to public functions and prevent them from being called
            /// without first initializing [MobileAdsManager]
            _sdkInitializationComplete = true;

            /// Initializing App Open Ad
            if (appOpenAd != null) {
              /// Guarding against errors
              try {
                _initializeAppOpenAd(appOpenAdInitializer: appOpenAd);
              } catch (e, stackTrace) {
                /// Handling errors
                onAdsInitializationError?.call(e, stackTrace);
              }
            }

            /// Guarding against errors
            try {
              /// Starting parallel Ad load. On error, it throws the first error that occurs, and the rest
              /// are discarded.
              Future.wait(<Future>[
                /// Initializing interstitial Ads
                if (interstitialAds != null)
                  for (InterstitialAdInitializer ad in interstitialAds)
                    initializeInterstitialAds(interstitialAdInitializer: ad),

                /// Initializing rewarded Ads
                if (rewardedAds != null)
                  for (RewardedAdInitializer ad in rewardedAds)
                    initializeRewardedAds(rewardedAdInitializer: ad),

                /// Initializing banner Ads
                if (bannerAds != null)
                  for (BannerAdInitializer ad in bannerAds)
                    initializeBannerAds(bannerAdInitializer: ad),
              ]).then(
                (List<dynamic> _) {
                  /// On success
                  initializationComplete = true;
                },
              );
            } catch (e, stackTrace) {
              onAdsInitializationError?.call(e, stackTrace);
            }

            return;
          },
        );
      } catch (e, stackTrace) {
        onSDKInitializationError?.call(e, stackTrace);
      }

      return;
    }

    /// Asynchronously initializes SDK and requests appropriate ads. Does not
    /// await for anything except the App Open ad. Technically unsafe, but done
    /// under the assumption only the App Open ad needs access at once, and the
    /// rest will be ready by the time they're needed. [initializationComplete]
    /// can be checked against, to ensure safety when calling methods after a
    /// balanced load.
    if (loadingStrategy == LoadingStrategy.balancedLoading) {
      /// Guarding against errors
      try {
        /// Initializing the SDK, followed by all the ads. The App Open ad is awaited for,
        /// and completes before its needed, with the assumption everything else will finish
        /// loading before its needed.
        await MobileAds.instance.initialize().then(
          (InitializationStatus _) async {
            /// Flag checked against to determine whether the JUST the SDK has been initialized or not.
            /// Used internally to guard calls to public functions and prevent them from being called
            /// without first initializing [MobileAdsManager]
            _sdkInitializationComplete = true;

            /// Initializing App Open Ad
            if (appOpenAd != null) {
              /// Guarding against errors
              try {
                await _initializeAppOpenAd(appOpenAdInitializer: appOpenAd);
              } catch (e, stackTrace) {
                /// Handling errors
                onAdsInitializationError?.call(e, stackTrace);
              }
            }

            /// Guarding against errors
            try {
              /// Starting parallel Ad load. On error, it throws the first error that occurs, and the rest
              /// are discarded.
              Future.wait(<Future>[
                /// Initializing interstitial Ads
                if (interstitialAds != null)
                  for (InterstitialAdInitializer ad in interstitialAds)
                    initializeInterstitialAds(interstitialAdInitializer: ad),

                /// Initializing rewarded Ads
                if (rewardedAds != null)
                  for (RewardedAdInitializer ad in rewardedAds)
                    initializeRewardedAds(rewardedAdInitializer: ad),

                /// Initializing banner Ads
                if (bannerAds != null)
                  for (BannerAdInitializer ad in bannerAds)
                    initializeBannerAds(bannerAdInitializer: ad),
              ]).then(
                (List<dynamic> _) {
                  /// On success
                  initializationComplete = true;
                },
              );
            } catch (e, stackTrace) {
              onAdsInitializationError?.call(e, stackTrace);
            }

            return;
          },
        );
      } catch (e, stackTrace) {
        onSDKInitializationError?.call(e, stackTrace);
      }

      return;
    }

    /// Asynchronously initializes SDK and requests appropriate ads. Await for
    /// everything, ensuring all subsequent calls are safe.[initializationComplete]
    /// can be checked against, but is not needed, when calling methods after a
    /// complete load, unless of course some error prevented the ads from loading
    /// entirely.
    if (loadingStrategy == LoadingStrategy.completeLoading) {
      /// Guarding against errors
      try {
        /// Initializing the SDK, followed by all the ads. Everything is awaited
        /// for, and will finish loading before its needed.
        await MobileAds.instance.initialize().then(
          (InitializationStatus _) async {
            /// Flag checked against to determine whether the JUST the SDK has been initialized or not.
            /// Used internally to guard calls to public functions and prevent them from being called
            /// without first initializing [MobileAdsManager]
            _sdkInitializationComplete = true;

            /// Initializing App Open Ad
            if (appOpenAd != null) {
              /// Guarding against errors
              try {
                await _initializeAppOpenAd(appOpenAdInitializer: appOpenAd);
              } catch (e, stackTrace) {
                /// Handling errors
                onAdsInitializationError?.call(e, stackTrace);
              }
            }

            /// Guarding against errors
            try {
              /// Starting parallel Ad load. On error, it throws the first error that occurs, and the rest
              /// are discarded.
              await Future.wait(<Future>[
                /// Initializing interstitial Ads
                if (interstitialAds != null)
                  for (InterstitialAdInitializer ad in interstitialAds)
                    initializeInterstitialAds(interstitialAdInitializer: ad),

                /// Initializing rewarded Ads
                if (rewardedAds != null)
                  for (RewardedAdInitializer ad in rewardedAds)
                    initializeRewardedAds(rewardedAdInitializer: ad),

                /// Initializing banner Ads
                if (bannerAds != null)
                  for (BannerAdInitializer ad in bannerAds)
                    initializeBannerAds(bannerAdInitializer: ad),
              ]).then(
                (List<dynamic> _) {
                  /// On success
                  initializationComplete = true;
                },
              );
            } catch (e, stackTrace) {
              onAdsInitializationError?.call(e, stackTrace);
            }

            return;
          },
        );
      } catch (e, stackTrace) {
        onSDKInitializationError?.call(e, stackTrace);
      }

      return;
    }
  }

  /// Used internally when initializing the AppOpenAd, which is conditional
  /// and determined by [AppOpenAdInitializer.loadChance]
  Future<ManagedAppOpenAd?> _initializeAppOpenAd({
    required AppOpenAdInitializer appOpenAdInitializer,
  }) async {
    /// Preventing undefined behavior
    assert(
      _sdkInitializationComplete,
      'MobileAdsManager must be initialized before calls to initialize ads with it',
    );

    /// Determining whether to load the ad, based on loadChance
    final bool showAppOpenAd = determineSuccess(
      successChance: appOpenAdInitializer.loadChance,
    );

    if (showAppOpenAd == true) {
      /// Setting up the [ManagedAppOpenAd] instance
      final ManagedAppOpenAd ad = ManagedAppOpenAd(appOpenAdInitializer);

      /// Initializing the ad, which handles loading it. If errors occur, they are
      /// rethrown to be handled by the enclosing try-catch block
      try {
        await ad._initializeAppOpenAd();
      } catch (e) {
        rethrow;
      }

      /// Making it retrievable from [MobileAdsManager.instance.managedOpenAd]
      _managedAppOpenAd = ad;

      return ad;
    } else {
      return null;
    }
  }

  /// Used to retrieve the [ManagedAppOpenAd], which may or may not be null, depending on whether
  /// it was initialized, or whether it was initialized, showed, and then disposed. A method is used
  /// instead of a getter for API consistency's sake
  ManagedAppOpenAd? getManagedAppOpenAd() {
    return _managedAppOpenAd;
  }

  /// Used internally and publicly to initialize a fully managed queue of [InterstitialAd]s
  Future<ManagedInterstitialAdQueue> initializeInterstitialAds({
    required InterstitialAdInitializer interstitialAdInitializer,
  }) async {
    /// Preventing undefined behavior
    assert(
      _sdkInitializationComplete,
      'MobileAdsManager must be initialized before calls to initialize ads with it',
    );

    /// Preventing multiple queues to be spun up for the same Ad Unit Id. This behavior is assumed
    /// when removing queues from [MobileAdsManager.instance._managedInterstitialAdQueueList], but is
    /// enforced because it's just a better pattern
    for (final ManagedInterstitialAdQueue queue
        in MobileAdsManager.instance._managedInterstitialAdQueueList) {
      assert(
        queue.adUnitId != interstitialAdInitializer.adUnitId,
        'Each Ad Unit Id can only be used to create one queue. If you need many ads to be preloaded, because '
        'you use one Interstitial Ad Unit Id for everything, for example, bump up the value of InterstitialAdInitializer.count',
      );
    }

    /// Setting up the [ManagedInterstitialAdQueue] instance
    final ManagedInterstitialAdQueue queue =
        ManagedInterstitialAdQueue(interstitialAdInitializer);

    /// Initializing the queue, which handles pre-loading it with ads. If errors occur, they are
    /// rethrown to be handled by the enclosing try-catch block
    try {
      await queue._initializeInterstitialAdQueue();
    } catch (e) {
      rethrow;
    }

    /// Adding it to the managed list, so that it can later be
    /// searched for
    _managedInterstitialAdQueueList.add(queue);

    return queue;
  }

  /// Used to retrieve the particular instance of [ManagedInterstitialAdQueue] associated with a
  /// particular Ad Unit ID
  ManagedInterstitialAdQueue? getManagedInterstitialAdQueue({
    required String adUnitId,
  }) {
    ManagedInterstitialAdQueue? desiredQueue;

    /// Searching for the desired queue
    for (final ManagedInterstitialAdQueue queue
        in _managedInterstitialAdQueueList) {
      if (queue.adUnitId == adUnitId) {
        desiredQueue = queue;
      }
    }

    /// Returning the found queue, or null if no queue that manages ads with
    /// that Ad Unit ID exists
    return desiredQueue;
  }

  /// Used to retrieve every initialized instance of [ManagedInterstitialAdQueue] declared using
  /// MobileAdsManager
  List<ManagedInterstitialAdQueue> getAllManagedInterstitialAdQueues() {
    return _managedInterstitialAdQueueList;
  }

  /// Used internally and publicly to initialize a fully managed queue of [RewardedAd]s
  Future<ManagedRewardedAdQueue> initializeRewardedAds({
    required RewardedAdInitializer rewardedAdInitializer,
  }) async {
    /// Preventing undefined behavior
    assert(
      _sdkInitializationComplete,
      'MobileAdsManager must be initialized before calls to initialize ads with it',
    );

    /// Preventing multiple queues to be spun up for the same Ad Unit Id. This behavior is assumed
    /// when removing queues from [MobileAdsManager.instance._managedRewardedAdQueueList], but is
    /// enforced because it's just a better pattern
    for (final ManagedRewardedAdQueue queue
        in MobileAdsManager.instance._managedRewardedAdQueueList) {
      assert(
        queue.adUnitId != rewardedAdInitializer.adUnitId,
        'Each Ad Unit Id can only be used to create one queue. If you need many ads to be preloaded, because '
        'you use one Rewarded Ad Unit Id for everything, for example, bump up the value of RewardedAdInitializer.count',
      );
    }

    /// Setting up the [ManagedRewardedAdQueue] instance
    final ManagedRewardedAdQueue queue =
        ManagedRewardedAdQueue(rewardedAdInitializer);

    /// Initializing the queue, which handles pre-loading it with ads. If errors occur, they are
    /// rethrown to be handled by the enclosing try-catch block
    try {
      await queue._initializeRewardedAdQueue();
    } catch (e) {
      rethrow;
    }

    /// Adding it to the managed list, so that it can later be
    /// searched for
    _managedRewardedAdQueueList.add(queue);

    return queue;
  }

  /// Used to retrieve the particular instance of [ManagedRewardedAdQueue] associated with a
  /// particular Ad Unit ID
  ManagedRewardedAdQueue? getManagedRewardedAdQueue({
    required String adUnitId,
  }) {
    ManagedRewardedAdQueue? desiredQueue;

    /// Searching for the desired queue
    for (final ManagedRewardedAdQueue queue in _managedRewardedAdQueueList) {
      if (queue.adUnitId == adUnitId) {
        desiredQueue = queue;
      }
    }

    /// Returning the found queue, or null if no queue that manages ads with
    /// that Ad Unit ID exists
    return desiredQueue;
  }

  /// Used to retrieve every initialized instance of [ManagedRewardedAdQueue] declared using
  /// MobileAdsManager
  List<ManagedRewardedAdQueue> getAllManagedRewardedAdQueues() {
    return _managedRewardedAdQueueList;
  }

  Future<ManagedBannerAd> initializeBannerAds({
    required BannerAdInitializer bannerAdInitializer,
  }) async {
    /// Preventing undefined behavior
    assert(
      _sdkInitializationComplete,
      'MobileAdsManager must be initialized before calls to initialize ads with it',
    );

    /// Preventing multiple Banner Ads from being spun up for the same Ad Unit Id. This behavior is assumed
    /// when removing Banner Ads from [MobileAdsManager.instance._managedBannerAdList], but is
    /// enforced because it's just a better pattern
    for (final ManagedBannerAd ad
        in MobileAdsManager.instance._managedBannerAdList) {
      assert(
        ad.adUnitId != bannerAdInitializer.adUnitId,
        'Each Ad Unit Id can only be used to create one Banner Ad. If you need multiple Banner ads, consider '
        'setting up multiple Ad Unit Ids',
      );
    }

    /// Setting up the [ManagedAppOpenAd] instance
    final ManagedBannerAd ad = ManagedBannerAd(bannerAdInitializer);

    /// Initializing the ad, which handles loading it. If errors occur, they are
    /// rethrown to be handled by the enclosing try-catch block
    try {
      await ad._initializeBannerAd();
    } catch (e) {
      rethrow;
    }

    /// Adding it to the managed list, so that it can later be
    /// searched for
    _managedBannerAdList.add(ad);

    return ad;
  }

  /// Used to retrieve the particular instance of [ManagedBannerAd] associated with a
  /// particular Ad Unit ID
  ManagedBannerAd? getManagedBannerAd({
    required String adUnitId,
  }) {
    ManagedBannerAd? desiredAd;

    /// Searching for the desired ad
    for (final ManagedBannerAd ad in _managedBannerAdList) {
      if (ad.adUnitId == adUnitId) {
        desiredAd = ad;
      }
    }

    /// Returning the found ad, or null if no ad with
    /// that Ad Unit ID exists
    return desiredAd;
  }

  /// Used to retrieve every initialized instance of [ManagedBannerAd] declared using
  /// MobileAdsManager
  List<ManagedBannerAd> getAllManagedBannerAds() {
    return _managedBannerAdList;
  }

  /// Disposes all resources, including any App Open Ad if present, and every
  /// banner ad, interstitial ad and rewarded ad, as well as clearing out
  /// all references to them internally.
  ///
  /// This function is commented out because there really doesn't seem to be a reason
  /// it would ever need to be called (each ManagedAd instance has its own dispose method)
  /// and will only serve to confuse developers with an unnecessary option
  // void dispose() {
  //   /// Preventing undefined behavior
  //   assert(
  //     _sdkInitializationComplete,
  //     'MobileAdsManager must be initialized before it can be disposed',
  //   );
  //
  //   /// Disposing the instance of [ManagedAppOpenAd], if not null
  //   _managedAppOpenAd?.dispose();
  //
  //   /// Disposing all instances of [ManagedBannerAd]
  //   if (_managedBannerAdList.isNotEmpty) {
  //     for (final ManagedBannerAd ad in _managedBannerAdList) {
  //       ad.dispose();
  //     }
  //
  //     /// Disposing the list of all instances of [ManagedBannerAd]
  //     _managedBannerAdList.clear();
  //   }
  //
  //   /// Disposing all instances of [ManagedInterstitialAdQueue]
  //   if (_managedInterstitialAdQueueList.isNotEmpty) {
  //     for (final ManagedInterstitialAdQueue queue
  //         in _managedInterstitialAdQueueList) {
  //       queue.dispose();
  //     }
  //
  //     /// Disposing the list of all instances of [ManagedInterstitialAdQueue]
  //     _managedInterstitialAdQueueList.clear();
  //   }
  //
  //   /// Disposing all instances of [ManagedRewardedAdQueue]
  //   if (_managedRewardedAdQueueList.isNotEmpty) {
  //     for (final ManagedRewardedAdQueue queue in _managedRewardedAdQueueList) {
  //       queue.dispose();
  //     }
  //
  //     /// Disposing the list of all instances of [ManagedRewardedAdQueue]
  //     _managedRewardedAdQueueList.clear();
  //   }
  //
  //   /// Resetting flags
  //   _sdkInitializationComplete = false;
  //   initializationComplete = false;
  // }
}
