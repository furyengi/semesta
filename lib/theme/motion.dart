import 'package:flutter/material.dart';

/// Material 3 motion tokens (easing + duration) used across the app.
/// See https://m3.material.io/styles/motion/easing-and-duration/tokens-specs
abstract final class Motion {
  static const Duration short2 = Durations.short2; // 100ms
  static const Duration short4 = Durations.short4; // 200ms
  static const Duration medium2 = Durations.medium2; // 300ms
  static const Duration medium4 = Durations.medium4; // 400ms
  static const Duration long2 = Durations.long2; // 500ms

  static const Curve standard = Easing.standard;

  /// Flutter's equivalent of the M3 "emphasized" path easing.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve emphasizedDecelerate = Easing.emphasizedDecelerate;
  static const Curve emphasizedAccelerate = Easing.emphasizedAccelerate;

  /// Returns [d], or zero when the platform asks for reduced motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}
