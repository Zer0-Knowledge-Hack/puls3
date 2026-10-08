import 'package:flutter/widgets.dart';

/// Layout breakpoints in logical pixels, in one place so screens agree.
abstract final class Puls3Breakpoints {
  /// Below this the content gutter shrinks from 32 to 16 px.
  static const double narrowGutter = 600;

  /// Below this the app uses its phone layout: bottom navigation, compact
  /// type scale, 44 px buttons and denser inputs.
  static const double compact = 640;

  /// Below this, page headlines use their compact size.
  static const double compactHeadline = 700;

  /// From this width the agent detail shows profile and hire side by side.
  static const double detailTwoColumn = 900;

  /// From this width the Studio shows form and preview side by side.
  static const double studioTwoColumn = 960;

  /// From this width the agent grid has three columns (two from [compact]).
  static const double gridThreeColumns = 1000;
}

/// Whether the screen gets the phone layout (below [Puls3Breakpoints.compact]).
bool isCompactLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Puls3Breakpoints.compact;
