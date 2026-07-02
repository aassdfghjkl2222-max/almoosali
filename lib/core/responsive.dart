import 'package:flutter/material.dart';

class Responsive {
  final BuildContext context;

  Responsive(this.context);

  Size get size => MediaQuery.of(context).size;

  double get width => size.width;

  double get height => size.height;

  bool get isSmallPhone => height < 700;

  bool get isPhone => height >= 700 && height < 900;

  bool get isLargePhone => height >= 900;

  double wp(double percent) => width * percent / 100;

  double hp(double percent) => height * percent / 100;
}