import 'package:flutter/material.dart';

/// Static text style definitions. All sizes are relative to the CarPlay
/// in-car display assumption of ~800×480 px at ~160 dpi.
abstract final class AppTextStyles {
  static const clockLarge = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w200,
    letterSpacing: -1.0,
    height: 1.0,
  );

  static const clockSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
  );

  static const dateLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  static const cardTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const speedValue = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w100,
    letterSpacing: -2.0,
    height: 1.0,
  );

  static const speedUnit = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
  );

  static const appLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const mediaTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const mediaArtist = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const statValue = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const statLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );
}
