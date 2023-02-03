import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads_manager/google_mobile_ads_manager.dart';

// The App Open Ad Example
class AppOpenExample extends StatelessWidget {
  const AppOpenExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Getting the ad, and showing it once loaded
          FutureBuilder<ManagedAppOpenAd>(
            future: getAd(),
            builder: (
              BuildContext context,
              AsyncSnapshot<ManagedAppOpenAd> snapshot,
            ) {
              if (snapshot.hasData) {
                snapshot.data?.showAppOpenAd();
              }
              return Container();
            },
          ),
        ],
      ),
    );
  }

  // The function that initializes the SDK and gets the ad
  Future<ManagedAppOpenAd> getAd() async {
    // Initializing the App Open Ad with a simple
    // AppOpenAdInitializer configuration
    await MobileAdsManager.instance.initializeSDK(
      appOpenAd: AppOpenAdInitializer(adUnitId: '<Ad Unit ID>'),
    );

    // Returning the initialized App Open Ad
    return MobileAdsManager.instance.getManagedAppOpenAd()!;
  }
}

// The Interstitial Ad Example
class InterstitialExample extends StatelessWidget {
  const InterstitialExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          TextButton(
            onPressed: () {
              // Shows an interstitial ad, after getting it
              MobileAdsManager.instance
                  .getManagedInterstitialAdQueue(adUnitId: '<Ad Unit ID>')
                  ?.showInterstitialAd();
            },
            child: const Text(
              'Show Interstitial Ad',
              style: TextStyle(
                fontSize: 20.0,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// The Rewarded Ad Example
class RewardedExample extends StatelessWidget {
  const RewardedExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          TextButton(
            onPressed: () {
              // Shows a rewarded ad, after getting it
              MobileAdsManager.instance
                  .getManagedRewardedAdQueue(adUnitId: '<Ad Unit ID>')
                  ?.showRewardedAd(
                onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
                  // Reward user
                },
              );
            },
            child: const Text(
              'Show Rewarded Ad',
              style: TextStyle(
                fontSize: 20.0,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// The Banner Ad Example
class BannerExample extends StatefulWidget {
  const BannerExample({super.key});

  @override
  State<BannerExample> createState() => _BannerExampleState();
}

class _BannerExampleState extends State<BannerExample> {
  late final ManagedBannerAd ad;

  @override
  void initState() {
    super.initState();
    ad = MobileAdsManager.instance.getManagedBannerAd(
      adUnitId: '<Ad Unit ID>',
    )!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Showing the banner ad
          AdWidget(ad: ad.getAd()),
        ],
      ),
    );
  }
}
