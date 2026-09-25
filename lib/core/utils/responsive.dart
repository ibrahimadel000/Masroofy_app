import 'package:flutter/material.dart';

/// Standard screen size breakpoints for Mizaan
class ResponsiveBreakpoints {
  const ResponsiveBreakpoints._();

  /// Devices with width < 600 dp (smartphones in portrait)
  static const double mobile = 600;

  /// Devices with width between 600 dp and 1024 dp (tablets, foldables, phones in landscape)
  static const double tablet = 1024;
}

/// Enumeration of screen types
enum ResponsiveScreenType { mobile, tablet, desktop }

/// Helper class for responsive queries and layout calculations
class Responsive {
  const Responsive._();

  static ResponsiveScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < ResponsiveBreakpoints.mobile) {
      return ResponsiveScreenType.mobile;
    } else if (width < ResponsiveBreakpoints.tablet) {
      return ResponsiveScreenType.tablet;
    } else {
      return ResponsiveScreenType.desktop;
    }
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < ResponsiveBreakpoints.mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= ResponsiveBreakpoints.mobile &&
        width < ResponsiveBreakpoints.tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ResponsiveBreakpoints.tablet;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Selects a value based on the current screen type
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ResponsiveScreenType.desktop:
        return desktop ?? tablet ?? mobile;
      case ResponsiveScreenType.tablet:
        return tablet ?? mobile;
      case ResponsiveScreenType.mobile:
        return mobile;
    }
  }

  /// Calculates an adaptive horizontal padding for content
  static EdgeInsets contentPadding(
    BuildContext context, {
    double defaultPadding = 16.0,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width > 1200) {
      return EdgeInsets.symmetric(
        horizontal: (width - 1100) / 2,
        vertical: defaultPadding,
      );
    } else if (width > 800) {
      return EdgeInsets.symmetric(horizontal: 32.0, vertical: defaultPadding);
    }
    return EdgeInsets.symmetric(
      horizontal: defaultPadding,
      vertical: defaultPadding,
    );
  }
}

/// Builder widget that renders different layouts based on screen type
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) mobile;
  final Widget Function(BuildContext context)? tablet;
  final Widget Function(BuildContext context)? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = Responsive.getScreenType(context);
    switch (screenType) {
      case ResponsiveScreenType.desktop:
        if (desktop != null) return desktop!(context);
        if (tablet != null) return tablet!(context);
        return mobile(context);
      case ResponsiveScreenType.tablet:
        if (tablet != null) return tablet!(context);
        return mobile(context);
      case ResponsiveScreenType.mobile:
        return mobile(context);
    }
  }
}

/// Wraps child widget with a centered max-width constraint to prevent excessive stretching
/// on tablets, foldables, and wide desktop screens.
class ResponsiveConstraint extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveConstraint({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

/// Handy extension on [BuildContext] for responsive checks
extension ResponsiveExtension on BuildContext {
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);
  bool get isLandscape => Responsive.isLandscape(this);
  ResponsiveScreenType get screenType => Responsive.getScreenType(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  T responsive<T>({required T mobile, T? tablet, T? desktop}) =>
      Responsive.value<T>(
        this,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      );
}
