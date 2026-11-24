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

/// Geometry of a laid-out cover grid, excluding overlaid controls.
class CoverGridViewport {
  const CoverGridViewport({
    required this.metrics,
    required this.itemCount,
    required this.columns,
    required this.rowExtent,
    required this.contentStart,
    required this.topOcclusion,
    required this.bottomOcclusion,
  });

  final ScrollMetrics metrics;
  final int itemCount;
  final int columns;
  final double rowExtent;
  final double contentStart;
  final double topOcclusion;
  final double bottomOcclusion;

  double get visibleTop => metrics.pixels + topOcclusion;
  double get visibleBottom =>
      metrics.pixels + metrics.viewportDimension - bottomOcclusion;

  double rowTop(int index) => contentStart + (index ~/ columns) * rowExtent;
  double rowBottom(int index) =>
      rowTop(index) + rowExtent - CoverGridLayout.spacing;

  bool isFullyVisible(int index) =>
      index >= 0 &&
      index < itemCount &&
      rowTop(index) >= visibleTop &&
      rowBottom(index) <= visibleBottom;

  /// Prefer a fully visible row; fall back to a partially visible one.
  /// Call only for a nonempty grid with valid layout metrics.
  int firstVisibleIndex() {
    final lastRow = (itemCount - 1) ~/ columns;
    final firstRow = ((visibleTop - contentStart) / rowExtent).ceil().clamp(
      0,
      lastRow,
    );
    final index = firstRow * columns;
    if (isFullyVisible(index)) return index;

    final partialRow =
        ((visibleTop - contentStart + CoverGridLayout.spacing) / rowExtent)
            .floor()
            .clamp(0, lastRow);
    return partialRow * columns;
  }
}
