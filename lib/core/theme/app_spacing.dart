

/// App-wide spacing tokens following the strict 8pt grid (4pt for tight internal gaps).
class AppSpacing {
  AppSpacing._();

  static const double sp1 = 4.0;
  static const double sp2 = 8.0;
  static const double sp3 = 12.0;
  static const double sp4 = 16.0;
  static const double sp5 = 20.0;
  static const double sp6 = 24.0;
  static const double sp7 = 32.0;
  static const double sp8 = 40.0;
}

/// App-wide shape tokens defining corner radiuses.
class AppShapes {
  AppShapes._();

  /// Small controls (chips, inputs, radios) - 12px
  static const double radiusSmall = 12.0;

  /// Standard cards (list items, stat tiles) - 22px
  static const double radiusStandard = 22.0;

  /// Hero surfaces (login card, bento primary tile, avatars, detail header) - 28px
  static const double radiusHero = 28.0;

  /// FAB - 20px
  static const double radiusFab = 20.0;

  /// Floating nav bar - 100px
  static const double radiusPill = 100.0;
}
