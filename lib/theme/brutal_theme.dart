import 'package:flutter/material.dart';

/// Tokens for the bold accent style (thick outlines, hard offset shadows)
/// used on the home screen and course cards. Everywhere else the app sticks
/// to plain Material 3 surfaces.
@immutable
class BrutalTheme extends ThemeExtension<BrutalTheme> {
  const BrutalTheme({
    required this.border,
    required this.shadow,
    required this.card,
    this.borderWidth = 2,
    this.shadowOffset = const Offset(4, 5),
  });

  final Color border;
  final Color shadow;

  /// Default fill for bold cards.
  final Color card;
  final double borderWidth;
  final Offset shadowOffset;

  static BrutalTheme of(BuildContext context) =>
      Theme.of(context).extension<BrutalTheme>()!;

  @override
  BrutalTheme copyWith({
    Color? border,
    Color? shadow,
    Color? card,
    double? borderWidth,
    Offset? shadowOffset,
  }) => BrutalTheme(
    border: border ?? this.border,
    shadow: shadow ?? this.shadow,
    card: card ?? this.card,
    borderWidth: borderWidth ?? this.borderWidth,
    shadowOffset: shadowOffset ?? this.shadowOffset,
  );

  @override
  BrutalTheme lerp(BrutalTheme? other, double t) {
    if (other == null) return this;
    return BrutalTheme(
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      card: Color.lerp(card, other.card, t)!,
      borderWidth: borderWidth + (other.borderWidth - borderWidth) * t,
      shadowOffset: Offset.lerp(shadowOffset, other.shadowOffset, t)!,
    );
  }
}
