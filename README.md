This package provides a simple, concise, and fully managed way of interacting with the AdMobSDK for Dart provided by [google_mobile_ads](https://pub.dev/packages/google_mobile_ads).

## Features
- 🚀 Automatic efficient ad preloading and queueing
-  💪 Smart request retrying on fail
- 🛡 Error handling
- ⚙️ Automatic ad disposal after show
- ⚡ Efficient optional probabilistic ad showing, to enhance user experiences
- ❤️ Concise, intuitive API separated by ad type
- 🔋 Batteries included :)

## Initialization Strategies
Ads can be initialized in **2** ways:
- When initializing the AdMob SDK, through a list of Initializer objects provided at startup 
- At any time, by providing an Initializer object of the relevant type to the appropriate method in `MobileAdsManager.instance`

All types of Ads have automatic retry mechanisms in place that will retry for a set number of times on a failed load (except for App Open ads), before throwing an error. 
App Open ads do not retry because in most cases, retrying the load will take too long, and it is better to skip it in favor of a better experience for the user.

## MobileAdsManager
The MobileAdsManager is the class that manages everything, and is accessible everywhere through the static instance getter. **A call to** `initializeSDK` **must be done before using any of the other methods provided by the class.**

```dart  
// Getting the instance
final adManager = MobileAdsManager.instance;  

// Initializing the SDK, with no ads and default configs. 
// Note that this method does not need to be in a try-catch
// block
// Errors can be handled by providing appropriate callbacks to 
// this function, or are otherwise automatically suppressed
MobileAdsManager.instance.initializeSDK();
```  

MobileAdsManager can also be initialized with custom configuration, to make things easier and more convenient:

```dart  
MobileAdsManager.instance.initializeSDK(  
  loadingStrategy: LoadingStrategy.fastLoading,  
  appOpenAd: AppOpenAdInitializer(adUnitId: '<Ad Unit ID>'),  
  interstitialAds: <InterstitialAdInitializer>[  
    /// Iniitalizes 3 Interstitial ads each, of <Ad Unit ID 1>, and 
    /// <Ad Unit ID 2>
    InterstitialAdInitializer(adUnitId: '<Ad Unit ID 1>', count: 3),  
    InterstitialAdInitializer(adUnitId: '<Ad Unit ID 2>', count: 3),  
  ],  
  rewardedAds: <RewardedAdInitializer>[  
    /// Initializes 2 Rewarded ads each, of <Ad Unit ID 3>, and 
    /// <Ad Unit ID 4>
    RewardedAdInitializer(adUnitId: '<Ad Unit ID 3>', count: 2),  
    RewardedAdInitializer(adUnitId: '<Ad Unit ID 4>', count: 2),  
  ],  
  bannerAds: <BannerAdInitializer>[  
    /// Iniitalizes 2 Banner ads, of <Ad Unit ID 5>, and 
    /// <Ad Unit ID 6>
    BannerAdInitializer(  
      adUnitId: '<Ad Unit ID 5>',  
      bannerAdSize: AdSize.banner,  
    ),  
    BannerAdInitializer(  
      adUnitId: '<Ad Unit ID 6>',  
      bannerAdSize: AdSize.banner,  
    ),  
  ],  
  onSDKInitializationError: (Object? error, StackTrace stackTrace) {  
    // Handle errors associated with initializing the AdMob SDK  
  },  
  onAdsInitializationError: (Object? error, StackTrace stackTrace) {  
    // Handle errors associated with initializing any Ads  
  },  
);
```  

**Note:**
- Initializing Ads through `initializeSDK` is purely a convenience feature; every type of ad except for App Open Ads can also be separately initialized — at any time after calling `initializeSDK` first — through the methods on `MobileAdsManager` mentioned below.

## App Open Ads  
App Open ads are interacted with through a fully self-managing instance of `ManagedAppOpenAd`.

The instance manages initializing the ad with the provided callbacks, loading the ad, and disposing it on load failure or after its shown.
`ManagedAppOpenAd`s can be initialized by providing an instance of `AppOpenAdInitializer`  to  `initializeSDK`  during SDK initialization. They **cannot** be initialized any time after.

This single instance of  `ManagedAppOpenAd` can be retrieved at any time from `MobileAdsManager.instance.getManagedAppOpenAd()`, and can be shown by calling `showAppOpenAd()` on the `ManagedAppOpenAd` instance. 

```dart  
// Initializing the App Open Ad with a simple
// AppOpenAdInitializer configuration
MobileAdsManager.instance.initializeSDK(  
  appOpenAd: AppOpenAdInitializer(adUnitId: '<Ad Unit ID>'),  
);

// Getting the initialized App Open Ad
ManagedAppOpenAd ad =  MobileAdsManager.instance.getManagedAppOpenAd()!;

// Showing the ad, and automatically disposing it after
// its done showing
ad.showAppOpenAd();
```  

App Open Ads can be shown based on a probabilistic method (for example, when an App Open Ad should be shown 60% of the time a user opens the app) by passing the probability, ranging from `0.0` to `1.0` to `AppOpenAdInitializer.loadChance`.

**Note:**
- Depending on what `ManagedAppOpenAd.loadChance` is, the `ManagedAppOpenAd` may be null. Passing no value results in a `loadChance` of `1.0`,  which guarantees the `ManagedAppOpenAd` will always be loaded.

```dart  
// Initializing the App Open Ad with an AppOpenAdInitializer configuration
// that leads to the Ad being loaded only 70% of the time.
MobileAdsManager.instance.initializeSDK(  
  appOpenAd: AppOpenAdInitializer(  
    adUnitId: '<Ad Unit ID>',  
    loadChance: 0.7,  
  ),  
);

// Getting the initialized App Open Ad, which can be null 
ManagedAppOpenAd? ad = MobileAdsManager.instance.getManagedAppOpenAd();  
  
// Showing the ad if it is not null, with automatic disposal, if its shown  
ad?.showAppOpenAd();
```  

The `ManagedAppOpenAd` instance also provides a `dispose` method, to allow for the ad to be manually disposed, in the event it is **not** shown.  This method does **not** need to be called in normal usage.

```dart  
// Getting the initialized App Open Ad
ManagedAppOpenAd ad =  MobileAdsManager.instance.getManagedAppOpenAd()!;

// Disposing the ad manually, because it is not
// to be shown
//
// Note that calling `dispose` disposes the ad as well as the ManagedAppOpenAd
// instance, and MobileAdsManager.instance.getManagedAppOpenAd() returns null
// afterwards.
ad.dispose();
```  

## Interstitial Ads  
Interstitial Ads are interacted with through a fully self-managing queue instance of  `ManagedInterstitialAdQueue`,  similar to Rewarded Ads. The queue contains a number of `InterstitialAd`s determined by `InterstitialAdInitializer.count`, and automatically disposes an Ad once it's shown, and loads another in its place.
In this way, a small number of ads are always preloaded and ready to be shown, cutting down on waiting times.

The queue can be initialized by providing an instance of `InterstitialAdInitializer` to `initializeSDK` during SDK initialization, Alternatively, they can also be initialized at any time by calling 
`MobileAdsManager.instance.initializeInterstitialAds`.

Any particular instance of `ManagedInterstitialAdQueue` can be retrieved at any time from `MobileAdsManager.instance.getManagedInterstitialAdQueue()`, and an ad from the queue can be shown by calling `showInterstitialAd()` on the `ManagedInterstitialAdQueue` instance, which also handles disposing the ad and loading another in its place.

**Note:**
- Always initialize only **one** queue per Interstitial Ad Unit ID. If you need many ads preloaded, because you use one Ad Unit Id throughout your app, for example, consider bumping up the value of `InterstitialAdInitializer.count` to increase the number of ads in the queue

```dart  
// Initializing 2 instances of ManagedInterstitialAdQueue, one for  
// each Ad Unit ID, when initializing the SDK  
MobileAdsManager.instance.initializeSDK(  
  interstitialAds: <InterstitialAdInitializer>[  
    // Initializes 3 Interstitial ads each, of <Ad Unit ID 1>, and  
    // <Ad Unit ID 2>    
    InterstitialAdInitializer(adUnitId: '<Ad Unit ID 1>', count: 3),  
    InterstitialAdInitializer(adUnitId: '<Ad Unit ID 2>', count: 3),  
  ],  
);  
  
/// Initializing a 3rd instance of ManagedInterstitialAdQueue, for  
/// <Ad Unit ID 3>, and assigning it to ad3
ManagedInterstitialAdQueue queue3 =  
    await MobileAdsManager.instance.initializeInterstitialAds(  
  interstitialAdInitializer: InterstitialAdInitializer(  
    adUnitId: '<Ad Unit ID 3>',  
    count: 3,  
  ),  
);
  
// Getting the initialized ManagedInterstitialAdQueue for <Ad Unit ID 2>,  
// if it exists  
ManagedInterstitialAdQueue? queue2 =  
    MobileAdsManager.instance.getManagedInterstitialAdQueue(  
  adUnitId: '<Ad Unit ID 2>',  
);  
  
// Showing the ad (if it is not null) with a chance to show of 65%,  
// and automatically disposing it after, if it shows  
queue2?.showInterstitialAd(showChance: 0.65);

// Getting all initialized instances of ManagedInterstitialAdQueue, so,  
// in this example, instances of <Ad Unit ID 1>, <Ad Unit ID 2> and  
// <Ad Unit ID 3>  
// 
// Note, if no initialized instances exist, the list will be empty
List<ManagedInterstitialAdQueue> queues =  
    MobileAdsManager.instance.getAllManagedInterstitialAdQueues();
```  

Each `ManagedInterstitialAdQueue` instance also provides a `dispose` method, to allow for the queue to be disposed when it is no longer needed (which is unlikely, for normal use-cases).

```dart  
// Getting the initialized ManagedInterstitialAdQueue for <Ad Unit ID 1>,  
// if it exists  
ManagedInterstitialAdQueue? queue =  
    MobileAdsManager.instance.getManagedInterstitialAdQueue(  
  adUnitId: '<Ad Unit ID 1>',  
);  
  
// Disposing the queue (if it exists).  
// Note that calling `dispose` disposes the queue as well as the ManagedInterstitialAdQueue  
// instance, and MobileAdsManager.instance.getManagedInterstitialAdQueue(adUnitId: '<Ad Unit ID 2>');  
// returns null afterwards.  
queue?.dispose();
```  

**Note:**
- Calling `dispose` **does not dispose an individual ad**, and rather disposes the entire queue of ads for that Ad Unit ID, as well as the ManagedInterstitialAdQueue instance. Individual ads will be automatically disposed once they're shown, or if they ever fail to load.

## Rewarded Ads  
Rewarded Ads are interacted with through a fully self-managing queue instance of `ManagedRewardedAdQueue`,  similar to Interstitial Ads. The queue contains a number of `RewardedAd`s determined by `RewardedAdInitializer.count`, and automatically disposes an Ad once it's shown, and loads another in its place.  
In this way, a small number of ads are always preloaded and ready to be shown, cutting down on waiting times.  
  
The queue can be initialized by providing an instance of `RewardedAdInitializer` to `initializeSDK` during SDK initialization, Alternatively, they can also be initialized at any time by calling  
`MobileAdsManager.instance.initializeRewardedAds`.  
  
Any particular instance of `ManagedRewardedAdQueue` can be retrieved at any time from `MobileAdsManager.instance.getManagedRewardedAdQueue()`, and an ad from the queue can be shown by calling `showRewardedAd()` on the `ManagedRewardedAdQueue` instance, which also handles disposing the ad and loading another in its place.  
  
**Note:**  
- Always initialize only **one** queue per Rewarded Ad Unit ID. If you need many ads preloaded, because you use one Ad Unit Id throughout your app, for example, consider bumping up the value of `RewardedAdInitializer.count` to increase the number of ads in the queue  
  
```dart  
// Initializing 2 instances of ManagedRewardedAdQueue, one for  
// each Ad Unit ID, when initializing the SDK  
MobileAdsManager.instance.initializeSDK(  
  rewardedAds: <RewardedAdInitializer>[  
    // Initializes 2 Rewarded ads each, of <Ad Unit ID 1>, and  
    // <Ad Unit ID 2>    RewardedAdInitializer(adUnitId: '<Ad Unit ID 1>', count: 2),  
    RewardedAdInitializer(adUnitId: '<Ad Unit ID 2>', count: 2),  
  ],  
);  
  
// Initializing a 3rd instance of ManagedRewardedAdQueue, for  
// <Ad Unit ID 3>, and assigning it to ad3  
ManagedRewardedAdQueue queue3 =  
    await MobileAdsManager.instance.initializeRewardedAds(  
  rewardedAdInitializer: RewardedAdInitializer(  
    adUnitId: '<Ad Unit ID 3>',  
    count: 3,  
  ),  
);  
  
// Getting the initialized ManagedRewardedAdQueue for <Ad Unit ID 2>,  
// if it exists  
ManagedRewardedAdQueue? queue2 =  
    MobileAdsManager.instance.getManagedRewardedAdQueue(  
  adUnitId: '<Ad Unit ID 2>',  
);  
  
// Showing the ad (if it is not null) with a chance to show of 65%,  
// and automatically disposing it after, if it shows  
queue2?.showRewardedAd(  
  showChance: 0.65,  
  onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {  
    // Give the user a reward  
  },  
);  
  
// Getting all initialized instances of ManagedRewardedAdQueue, so,  
// in this example, instances of <Ad Unit ID 1>, <Ad Unit ID 2> and  
// <Ad Unit ID 3>  
//  
// Note, if no initalized instances exist, the list will be empty  
List<ManagedRewardedAdQueue> queues =  
    MobileAdsManager.instance.getAllManagedRewardedAdQueues();
```    

Each `ManagedRewardedAdQueue` instance also provides a `dispose` method, to allow for the queue to be disposed when it is no longer needed (which is unlikely, for normal use-cases).  
  
```dart  
// Getting the initialized ManagedRewardedAdQueue for <Ad Unit ID 1>,  
// if it exists  
ManagedRewardedAdQueue? queue =  
    MobileAdsManager.instance.getManagedRewardedAdQueue(  
  adUnitId: '<Ad Unit ID 1>',  
);  
  
// Disposing the queue (if it exists).  
// Note that calling `dispose` disposes the queue as well as the ManagedRewardedAdQueue  
// instance, and MobileAdsManager.instance.getManagedRewardedAdQueue(adUnitId: '<Ad Unit ID 2>');  
// returns null afterwards.  
queue?.dispose();
```    

**Note:**  
- Calling `dispose` **does not dispose an individual ad**, and rather disposes the entire queue of ads for that Ad Unit ID, as well as the ManagedRewardedAdQueue instance. Individual ads will be automatically disposed once they're shown, or if they ever fail to load.

## Banner Ads
Banner ads are interacted with through a self-managing instance of `ManagedBannerAd`. 

The instance manages initializing the ad with the provided callbacks, loading the ad, and disposing it on load failure. The actual `BannerAd` itself, for display by an `AdWidget` provided by ` google_mobile_ads`, can be retrieved with a call to `ManagedBannerAd.getAd()`.

`ManagedBannerAd`s can be initialized by providing an instance of `BannerAdInitializer` to `initializeSDK` during SDK initialization. Alternatively, they can also be initialized at any time by calling  
`MobileAdsManager.instance.initializeBannerAds`.  

Any particular instance of `ManagedBannerAd` can also be retrieved at any time from `MobileAdsManager.instance.getManagedBannerAd` by passing it the Ad Unit ID. 
A `List` of all `ManagedBannerAd`s can be retrieved from `MobileAdsManager.instance.getAllManagedBannerAds`.

```dart  
// Initializing 2 instances of ManagedBannerAd, one for  
// each Ad Unit ID, when initializing the SDK  
MobileAdsManager.instance.initializeSDK(  
  bannerAds: <BannerAdInitializer>[  
    BannerAdInitializer(  
      adUnitId: '<Ad Unit ID 1>',  
      bannerAdSize: AdSize.banner,  
    ),  
    BannerAdInitializer(  
      adUnitId: '<Ad Unit ID 2>',  
      bannerAdSize: AdSize.banner,  
    ),  
  ],  
);  
  
// Initializing the 3rd instance of ManagedBannerAd, for  
// <Ad Unit ID 3>, when initializing the SDK  
ManagedBannerAd ad3 = await MobileAdsManager.instance.initializeBannerAds(  
  bannerAdInitializer: BannerAdInitializer(  
    adUnitId: '<Ad Unit ID 3>',  
    bannerAdSize: AdSize.banner,  
  ),  
);  
  
// Getting the initialized ManagedBannerAd for <Ad Unit ID 2>,  
// if it exists  
ManagedBannerAd? ad2 = MobileAdsManager.instance.getManagedBannerAd(  
  adUnitId: '<Ad Unit ID 2>',  
);  
  
// Configuring the ad widget, which is how the banner ad is actually shown.  
// This is part of the google_mobile_ads package.  
Widget adWidget = AdWidget(ad: ad2!.getAd());  
  
// Getting all initialized instances of ManagedBannerAd, so,  
// in this example, instances of <Ad Unit ID 1>, <Ad Unit ID 2> and  
// <Ad Unit ID 3>  
//  
// Note, if no initialized instances exist, the list will be empty  
List<ManagedBannerAd> ads = MobileAdsManager.instance.getAllManagedBannerAds();
```

The `ManagedBannerAd` instance also provides a `dispose` method, to be called when the `AdWidget` is removed from the widget tree. This method will almost always need to be called at some point when using `ManagedBannerAd`s. (If, for example your app only has one static screen, then the `AdWidget` is never removed from the widget tree, and `dispose` is never called).

```dart  
/// .... Other Widget code, including ad2's initialization  
@override  
void dispose() {  
  /// Disposing the banner ad via the dispose method  
  /// on the ManagedBannerAd instance  
  ///  
  /// Note that undefined behavior will result if dispose 
  /// is called on the banner ad itself  
  ad2.dispose();  
  
  super.dispose();  
}  
/// .... Other Widget code
```    

**Note:**
- As per the AdMob [docs](https://developers.google.com/admob/flutter/banner/get-started), the `BannerAd` should be disposed when the `AdWidget` is removed from the widget tree. When using `ManagedBannerAd` to manage banner ads, instead of calling `dispose` on the `BannerAd` itself, `dispose` **must** be called on the instance of `ManagedBannerAd`. If this is not done, undefined behavior may result, with `MobileAdManager` referencing already disposed banner ads, and returning them in response to queries.
- If no instances of `ManagedBannerAd`s exist, then an empty `List` of type `ManagedBannerAd` is returned from `MobileAdsManager.instance.getAllManagedBannerAds`
- Always initialize only **one** banner ad per banner Ad Unit ID. If you need many ads preloaded, consider using different banner Ad Unit IDs.

## License
This package is licensed under the Apache License, Version 2.0

```
Copyright 2023 Tanzil Zubair Bin Zaman

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

