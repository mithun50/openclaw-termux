import 'package:flutter/material.dart';

class Responsive {
  static const double tabletBreakpoint = 600.0;
  static const double maxContentWidth = 720.0;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  /// 平板上限制内容最大宽度并居中，手机上全宽
  static Widget constrain(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
