import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Shared card geometry for the Library and Collection grids.
class CoverGridLayout {
  const CoverGridLayout._(this.columns, this.tileWidth, this.aspectRatio);

  static const spacing = 6.0;
  static const _linuxMaxTileWidth = 500.0; // Physical pixels on Linux.

  factory CoverGridLayout.library(BuildContext context) => _calculate(
    context,
    horizontalPadding: 8,
    mobileColumns: 2,
    aspectRatio: 0.63,
  );

  factory CoverGridLayout.collection(BuildContext context) => _calculate(
    context,
    horizontalPadding: 4,
    mobileColumns: 3,
    aspectRatio: 0.69,
  );

  static CoverGridLayout _calculate(
    BuildContext context, {
    required double horizontalPadding,
    required int mobileColumns,
    required double aspectRatio,
  }) {
    final available = math.max(
      1.0,
      MediaQuery.sizeOf(context).width - horizontalPadding * 2,
    );
    final maxTileWidth =
        _linuxMaxTileWidth / MediaQuery.devicePixelRatioOf(context);
    final columns = Platform.isLinux
        ? math.max(1, ((available + spacing) / (maxTileWidth + spacing)).ceil())
        : mobileColumns;
    final tileWidth = math.max(
      1.0,
      (available - (columns - 1) * spacing) / columns,
    );
    return CoverGridLayout._(columns, tileWidth, aspectRatio);
  }

  final int columns;
  final double tileWidth;
  final double aspectRatio;

  double get tileHeight => tileWidth / aspectRatio;
  double get rowHeight => tileHeight + spacing;

  SliverGridDelegateWithFixedCrossAxisCount get delegate =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      );
}
