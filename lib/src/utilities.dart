import 'dart:math' as math;

/// Helper function handling randomly showing or not showing ads
bool determineSuccess({required double successChance}) {
  final int trueShowChance = int.parse(
    '${(successChance * 100).toInt()}',
  );

  /// 1-100, 100 values
  final int ranGen = math.Random().nextInt(100) + 1;

  if (ranGen <= trueShowChance) {
    /// Show ad
    return true;
  } else {
    /// Don't show ad
    return false;
  }
}
