import 'package:flutter/material.dart';

enum AppDeviceClass { mobile, tablet, desktop }

class AppBreakpoints {
  static const double mobile = 600;
  static const double desktop = 840;

  static AppDeviceClass ofWidth(double width) {
    if (width < mobile) return AppDeviceClass.mobile;
    if (width < desktop) return AppDeviceClass.tablet;
    return AppDeviceClass.desktop;
  }

  static AppDeviceClass of(BuildContext context) {
    return ofWidth(MediaQuery.sizeOf(context).width);
  }

  static bool isMobile(BuildContext context) {
    return of(context) == AppDeviceClass.mobile;
  }

  static bool isTablet(BuildContext context) {
    return of(context) == AppDeviceClass.tablet;
  }

  static bool isDesktop(BuildContext context) {
    return of(context) == AppDeviceClass.desktop;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final device = of(context);

    switch (device) {
      case AppDeviceClass.mobile:
        return const EdgeInsets.all(16);
      case AppDeviceClass.tablet:
        return const EdgeInsets.all(24);
      case AppDeviceClass.desktop:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 28);
    }
  }

  static int dashboardColumns(BuildContext context) {
    final device = of(context);

    switch (device) {
      case AppDeviceClass.mobile:
        return 1;
      case AppDeviceClass.tablet:
        return 2;
      case AppDeviceClass.desktop:
        return 3;
    }
  }
}
