import 'package:flutter/material.dart';

/// Extra tokens for the app's bold look: thick outlines and hard offset
/// shadows layered on top of the Material 3 colour scheme.
@immutable
class BrutalTheme extends ThemeExtension<BrutalTheme> {
  const BrutalTheme({
    required this.border,
    required this.shadow,
    this.borderWidth = 2,
    this.shadowOffset = const Offset(4, 5),
  });

  final Color border;
  final Color shadow;
  final double borderWidth;
  final Offset shadowOffset;

  static BrutalTheme of(BuildContext context) =>
      Theme.of(context).extension<BrutalTheme>()!;

  @override
  BrutalTheme copyWith({
    Color? border,
    Color? shadow,
    double? borderWidth,
    Offset? shadowOffset,
  }) => BrutalTheme(
    border: border ?? this.border,
    shadow: shadow ?? this.shadow,
    borderWidth: borderWidth ?? this.borderWidth,
    shadowOffset: shadowOffset ?? this.shadowOffset,
  );

  @override
  BrutalTheme lerp(BrutalTheme? other, double t) {
    if (other == null) return this;
    return BrutalTheme(
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      borderWidth: borderWidth + (other.borderWidth - borderWidth) * t,
      shadowOffset: Offset.lerp(shadowOffset, other.shadowOffset, t)!,
    );
  }
}
