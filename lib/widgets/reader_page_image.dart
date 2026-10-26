import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kurage/cache/reader_prefilter_cache.dart';

/// Blends a staged-downsampled page with the full-resolution original.
class ReaderPageImage extends StatefulWidget {
  const ReaderPageImage({
    super.key,
    required this.file,
    required this.index,
    required this.cache,
    required this.zoomScale,
  });

  final File file;
  final int index;
  final ReaderPrefilterCache cache;
  final ValueListenable<double> zoomScale;

  @override
  State<ReaderPageImage> createState() =>
      _ReaderPageImageState();
}

class _ReaderPageImageState extends State<ReaderPageImage> {
  ui.Image? _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.cache.readyFor(widget.index, widget.file);
    widget.cache.addListener(_onPrepared);
  }

  @override
  void didUpdateWidget(ReaderPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cache != widget.cache) {
      oldWidget.cache.removeListener(_onPrepared);
      widget.cache.addListener(_onPrepared);
    }
    if (oldWidget.index != widget.index ||
        oldWidget.file.path != widget.file.path ||
        oldWidget.cache != widget.cache) {
      _filtered?.dispose();
      _filtered = widget.cache.readyFor(widget.index, widget.file);
    }
  }

  void _onPrepared() {
    if (!mounted) return;
    final next = widget.cache.readyFor(widget.index, widget.file);
    // Keep the displayed clone alive if its cache entry was evicted.
    if (next == null) return;
    final previous = _filtered;
    if (previous != null && next.isCloneOf(previous)) {
      next.dispose();
      return;
    }
    setState(() => _filtered = next);
    previous?.dispose();
  }

  @override
  void dispose() {
    widget.cache.removeListener(_onPrepared);
    _filtered?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final original = Image.file(
      widget.file,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
    );
    final filteredProvider = _filtered;
    if (filteredProvider == null) return original;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return original;
        }
        final filtered = RawImage(
          image: filteredProvider,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
        return ValueListenableBuilder<double>(
          valueListenable: widget.zoomScale,
          builder: (context, zoom, _) {
            const blendStart = 1.10;
            const blendEnd = 1.40;
            final t = ((zoom - blendStart) / (blendEnd - blendStart))
                .clamp(0.0, 1.0);
            final eased = t * t * (3.0 - 2.0 * t);
            return Stack(
              fit: StackFit.expand,
              children: [
                original,
                Opacity(opacity: 1.0 - eased, child: filtered),
              ],
            );
          },
        );
      },
    );
  }
}
